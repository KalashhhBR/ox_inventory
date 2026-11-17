-- klsh: throwing items. The client aims and runs the flight; the server decides what leaves the
-- inventory and limits where it may land. Two steps: throwStart (validated, origin stored on the
-- server) and throwLand (landing point, within a time limit).
if not lib then return end

local Throw = require 'modules.throw.shared'
local Items = require 'modules.items.server'
local GetLocks = require 'modules.locks'
local config = Throw.config

local TriggerEventHooks = require 'modules.hooks.server'

local Inventory
local dropItem
local getGrid

---Called once by modules/inventory/server.lua.
---@param inventory table
---@param drop function the upstream dropItem (removes from the slot and creates the drop with the slot data)
---@param grid fun(): table returns the grid module (loaded after this one)
function Throw.init(inventory, drop, grid)
    Inventory = inventory
    dropItem = drop
    getGrid = grid
end

-- extra chance per player, set by other resources (skills); cleared when the player leaves
---@type table<number, number>
local bonus = {}

---@param source number
---@param value number? added to the chance of landing inside a target (e.g. 0.10); nil or 0 clears it
exports('SetThrowBonus', function(source, value)
    if type(source) ~= 'number' then return end

    bonus[source] = type(value) == 'number' and value ~= 0 and value or nil
end)

---The inventory an item may fall into, checked against where it landed. May yield (a trunk that is
---not loaded yet asks the client for the vehicle model), so it runs before the slot is locked.
---@param source number
---@param target any what the client says it hit: { type = 'dumpster' | 'trunk', netid = number }
---@param coords vector3 landing point (already limited by the range)
---@return table? inventory, string? reason 'refused' or 'locked' when the client named a target that does not count
local function resolveTarget(source, target, coords)
    local targets = config.targets

    if not targets or type(target) ~= 'table' then return end
    if math.type(target.netid) ~= 'integer' or target.netid < 1 then return nil, 'refused', 1 end

    local entity = NetworkGetEntityFromNetworkId(target.netid)

    if not entity or entity == 0 or not DoesEntityExist(entity) then return nil, 'refused', 2 end
    if GetEntityRoutingBucket(entity) ~= GetPlayerRoutingBucket(source) then return nil, 'refused', 3 end

    local distance = #(GetEntityCoords(entity) - coords)

    if target.type == 'dumpster' then
        if shared.networkdumpsters or GetEntityType(entity) ~= 3 or not Throw.isDumpster(GetEntityModel(entity)) then return nil, 'refused', 4 end
        if distance > targets.targetRadius + 1.5 then return nil, 'refused', 5 end

        local id = ('dumpster%s'):format(target.netid)

        return Inventory(id) or Inventory.Create(id, locale('dumpster'), 'dumpster', 15, 0, 100000, false) or nil, 'refused', 20
    elseif target.type == 'trunk' then
        if GetEntityType(entity) ~= 2 or distance > targets.trunkRadius then return nil, 'refused', 6 end

        local lockStatus = GetVehicleDoorLockStatus(entity)

        -- 0: no lock; 1: unlocked; 8: boot unlocked (same rule as opening the trunk)
        if lockStatus > 1 and lockStatus ~= 8 then return nil, 'locked' end

        local plate = GetVehicleNumberPlateText(entity)

        if not plate then return nil, 'refused', 7 end
        if server.trimplate then plate = string.strtrim(plate) end

        return Inventory({ id = 'trunk' .. plate, netid = target.netid, type = 'trunk' }) or nil, 'refused', 21
    end

    return nil, 'refused', 8
end

---@param source number
---@param distance number metres thrown
---@param weight number grams thrown
---@return number chance 0 to 1
local function getChance(source, distance, weight)
    local chance = config.targets.chance
    local value = chance.base - chance.perMeter * distance - chance.perKg * (weight / 1000)

    value = math.max(chance.min, math.min(chance.base, value)) + (bonus[source] or 0)

    return math.max(0, math.min(1, value))
end

---Moves `count` units from the player's slot straight into the target (slot data kept as it is).
---@return boolean success
local function intoTarget(source, inv, target, slot, count)
    local Grid = getGrid()
    local slotData = inv.items[slot]
    local item = Items(slotData.name)

    if not Grid or not target.grid or not item then return false end

    local plan, remaining = Grid.planAdd(target, item, count, slotData.metadata)
    local weight = Inventory.SlotWeight(item, slotData, true) * count

    if remaining > 0 or #plan == 0 or target.weight + weight > target.maxWeight then return false end

    local hooks <close> = TriggerEventHooks('swapItems', {
        source = source,
        fromInventory = inv.id,
        fromSlot = slotData,
        fromType = inv.type,
        toInventory = target.id,
        toSlot = plan[1].slot,
        toType = target.type,
        count = count,
        action = 'move',
        klshThrow = true,
    })

    if not hooks.success then return false end

    -- a hook may have waited: everything is checked again before anything moves
    if Inventory.GetLoaded(inv.id) ~= inv or Inventory.GetLoaded(target.id) ~= target then hooks.success = false return false end
    if inv.items[slot] ~= slotData or slotData.count < count then hooks.success = false return false end

    plan, remaining = Grid.planAdd(target, item, count, slotData.metadata)

    if remaining > 0 or #plan == 0 then hooks.success = false return false end

    -- remove first, then deliver
    local metadata = slotData.metadata

    slotData.count -= count

    if slotData.count < 1 then
        inv.items[slot] = nil
    else
        slotData.weight = Inventory.SlotWeight(item, slotData)
        metadata = table.clone(metadata)
    end

    inv.weight -= weight
    inv.changed = true

    if slot == inv.weapon then inv.weapon = nil end

    local updates = {}

    for i = 1, #plan do
        Grid.setSlot(target, item, plan[i], i == 1 and metadata or table.clone(metadata))
        updates[i] = { item = target.items[plan[i].slot], inventory = target.id }
    end

    target.changed = true
    target:syncSlotsWithClients(updates, false)

    TriggerClientEvent('ox_inventory:updateSlots', source, { { item = inv.items[slot] or { slot = slot }, inventory = inv.id } }, inv.weight)

    if server.syncInventory then server.syncInventory(inv) end

    if server.loglevel > 0 then
        lib.logger(inv.owner, 'swapSlots', ('%sx %s thrown from "%s" into "%s"'):format(count, item.name, inv.label, target.label))
    end

    return true
end

---@type table<number, { slot: number, count: number, item: table, origin: vector3, range: number, expires: number }>
local pending = {}
---@type table<number, number>
local lastThrow = {}

---@param source number
local function clearPending(source)
    local entry = pending[source]

    if not entry then return end

    pending[source] = nil

    local inv = Inventory(source)

    if inv and inv.klshThrowing == entry then inv.klshThrowing = nil end
end

---@param source number
---@param slot number
---@param count number?
---@return boolean allowed, string? reason
lib.callback.register('ox_inventory:klsh:throwStart', function(source, slot, count)
    if not config.enabled then return false end

    local inv = Inventory(source)

    if not inv or not inv.player or math.type(slot) ~= 'integer' then return false end

    -- nothing else may be going on: inventory closed, no timed move, no outfit swap, no item being used
    if inv.open or inv.klshChanging or inv.klshOutfitBusy or inv.usingItem or pending[source] then
        return false, 'throw_busy'
    end

    if inv.klshSearchedBy and next(inv.klshSearchedBy) then return false, 'throw_busy' end

    local now = GetGameTimer()

    if lastThrow[source] and now - lastThrow[source] < config.cooldown then return false, 'throw_cooldown' end

    local ped = GetPlayerPed(source)

    if ped == 0 or GetEntityHealth(ped) <= 0 then return false end

    local vehicle = GetVehiclePedIsIn(ped, false)

    -- from a vehicle: any seat; the opening next to it (window, door) is checked by the client, the
    -- server cannot see it
    if vehicle ~= 0 and not config.fromVehicle then return false end

    local slotData = inv.items[slot]
    local item = slotData and Items(slotData.name)

    if not slotData or not item then return false end

    count = math.type(count) == 'integer' and count or slotData.count

    if count < 1 or count > slotData.count then return false end

    -- a container that is opened somewhere cannot leave
    local container = slotData.metadata.container and Inventory.GetLoaded(slotData.metadata.container)

    if container and next(container.openedBy) then return false, 'throw_busy' end

    local weight = Inventory.SlotWeight(item, slotData, true) * count

    if weight > config.maxWeight then return false, 'throw_too_heavy' end

    local entry = {
        slot = slot,
        count = count,
        item = slotData,
        origin = GetEntityCoords(ped),
        range = Throw.range(weight),
        expires = now + config.maxFlight + 3000,
    }

    pending[source] = entry
    inv.klshThrowing = entry
    lastThrow[source] = now

    SetTimeout(config.maxFlight + 3500, function()
        if pending[source] == entry then clearPending(source) end
    end)

    return true
end)

---@param source number
---@param coords vector3 where the thrown object landed
---@param target? { type: 'dumpster' | 'trunk', netid: number } what it landed next to, when anything
---@return string? result 'target' (went in), 'missed' or 'full' (became a drop next to the target), 'ground'
lib.callback.register('ox_inventory:klsh:throwLand', function(source, coords, target)
    local entry = pending[source]

    if not entry then return end

    clearPending(source)

    if GetGameTimer() > entry.expires or type(coords) ~= 'vector3' then return end
    if coords.x ~= coords.x or coords.y ~= coords.y or coords.z ~= coords.z then return end -- NaN

    local inv = Inventory(source)

    if not inv or not inv.player or inv.open then return end

    -- the landing point comes from the client: limited by the range for that weight and by height
    local offset = coords - entry.origin

    local thrown = #vec2(offset.x, offset.y)

    if thrown > entry.range * 1.1 or math.abs(offset.z) > config.maxDrop then return end

    -- resolved before the lock: loading a trunk may wait for the client
    local targetInv, targetReason, targetStep = resolveTarget(source, target, coords)

    -- which check turned the target down (to find out why a throw did not count)
    if not targetInv and targetReason == 'refused' then
        lib.print.warn(('throw target refused at check %s (type %s, netid %s, player %s)'):format(targetStep, type(target) == 'table' and target.type, type(target) == 'table' and target.netid, source))
    end

    if Inventory.GetLoaded(inv.id) ~= inv or inv.open then return end

    local lock <close> = GetLocks({ ('inventory-%s:slot-%s'):format(inv.id, entry.slot) })

    if not lock then return end

    local slotData = inv.items[entry.slot]

    -- the item may have changed while it was "in the air"
    if not slotData or slotData ~= entry.item or slotData.count < entry.count then return end

    -- 'refused' / 'locked': the client named a target the server did not accept (the item goes to the ground)
    local result = not targetInv and targetReason or 'ground'

    if targetInv then
        local item = Items(slotData.name)
        local weight = item and Inventory.SlotWeight(item, slotData, true) * entry.count or 0

        if math.random() > getChance(source, thrown, weight) then
            result = 'missed'
        elseif intoTarget(source, inv, targetInv, entry.slot, entry.count) then
            return 'target'
        else
            result = 'full'
        end

        slotData = inv.items[entry.slot]

        if not slotData or slotData ~= entry.item or slotData.count < entry.count then return end
    end

    local success, response = dropItem(source, inv, slotData, {
        fromSlot = entry.slot,
        toSlot = 1,
        count = entry.count,
        coords = coords,
        instance = Player(source).state.instance, -- read here, not taken from the client
        klshThrow = true,
    })

    if not success or not response then return end

    -- the inventory is closed: this is what updates counts, weight and shortcuts on the client
    TriggerClientEvent('ox_inventory:updateSlots', source, response.items, response.weight)

    return result
end)

AddEventHandler('playerDropped', function()
    pending[source] = nil
    lastThrow[source] = nil
    bonus[source] = nil
end)

return Throw
