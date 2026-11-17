-- klsh: grid inventory, server side (plan section 11).
-- Every item in an inventory with a grid has a position (x, y, rotated) on its slot data; `slot` is only
-- the item's identifier. Geometry lives in modules/grid/shared.lua. The player's wallet items (accounts)
-- have fixed identifiers right after the cell count and no position. Content that did not fit when an
-- inventory was converted sits in extra rows below the configured height: it can leave, nothing can enter.
local Items = require 'modules.items.server'
local Geo = require 'modules.grid.shared'
local config = lib.load('data.grid') or {}

local Grid = {
    enabled = config.enabled == true,
    config = config,
}

---@type table
local Inventory
---@type fun(prefix: string, items: table, coords: vector3, slots?: number, maxWeight?: number, instance?: string | number, model?: number): string?
local CustomDrop

function Grid.init(inventory, customDrop)
    Inventory = inventory
    CustomDrop = customDrop
end

local wallet = {}
local walletCount = 0
local neverDrop = {}

for i = 1, #(config.wallet or {}) do
    wallet[config.wallet[i]] = i
    walletCount = i
end

for i = 1, #(config.neverDrop or {}) do
    neverDrop[config.neverDrop[i]] = true
end

---A size written in a data file or passed by another resource: { width, height } or { w =, h = }.
---@param value any
---@return number? w, number? h
local function readSize(value)
    if type(value) ~= 'table' then return end

    local w, h = value.w or value[1], value.h or value[2]

    if math.type(w) == 'integer' and math.type(h) == 'integer' and w > 0 and h > 0 then return w, h end
end

---Value for the `slots` argument of Inventory.Create: the size itself with the grid on, the slot count
---it stands for with the grid off. Numbers pass through.
---@param value number | table
---@return number | { w: number, h: number } | nil
function Grid.size(value)
    if type(value) == 'number' then return value end

    local w, h = readSize(value)

    if not w then return end

    return Grid.enabled and { w = w, h = h } or w * h
end

local backpackSizes = require('modules.equipment.shared').backpacks or {}

---Slots given to Inventory.Create for a container item: the grid size of known backpacks.
---@param itemName string
---@param slots number
---@return number | { w: number, h: number }
function Grid.containerSize(itemName, slots)
    local backpack = backpackSizes[itemName]

    return Grid.enabled and backpack and backpack.grid and Grid.size(backpack.grid) or slots
end

---@param inv table
---@return number? w, number? h
local function dimensions(inv)
    local invType = inv.type
    local slots = inv.slots

    if type(slots) == 'table' then return readSize(slots) end

    if invType == 'player' then return config.player.w, config.player.h end
    if invType == 'drop' then return config.drop.w, config.drop.h end
    if invType == 'equipment' or invType == 'shop' or invType == 'crafting' then return end

    -- outfit bags keep one slot per clothing category, like the equipment
    if invType == 'container' and type(inv.id) == 'string' and inv.id:sub(1, 7) == 'outfit-' then return end
    if type(slots) ~= 'number' or slots < 1 then return end

    local override = config.overrides and (config.overrides[inv.dbId or inv.id] or config.overrides[invType])

    if override then return override.w, override.h end

    local w = math.min(config.width or 10, slots)
    local minHeight = config.minHeight and (config.minHeight[invType] or config.minHeight.default) or 1

    return w, math.max(math.ceil(slots / w), minHeight)
end

---Slot of the wallet that keeps this item in a player inventory.
---@param inv table
---@param itemName string
---@return number?
function Grid.walletSlot(inv, itemName)
    local grid = inv.grid

    if not grid or not grid.wallet then return end

    local index = wallet[itemName]

    return index and grid.cells + index
end

---@param inv table
---@param slot number
---@return string? itemName the only item a wallet slot accepts
local function walletItemOf(inv, slot)
    local grid = inv.grid

    if not grid.wallet or slot <= grid.cells or slot > grid.base then return end

    return config.wallet[slot - grid.cells]
end

---Most units one stack of this item holds in this inventory; nil means no limit.
---@param inv table
---@param item table
---@return number?
function Grid.stackLimit(inv, item)
    if not item.stack then return 1 end
    if item.maxStack == false or wallet[item.name] then return end

    return item.maxStack or config.defaultStack or 20
end

local function matches(slotData, item, metadata)
    return slotData.name == item.name and table.matches(slotData.metadata or {}, metadata or {})
end

---@param name string
---@return number w, number h
local function getSize(name)
    if config.forceUnit then return 1, 1 end

    local item = Items(name)
    local size = item and item.size or config.defaultSize

    return size and size[1] or 1, size and size[2] or 1
end

Grid.getSize = getSize

---@return boolean wallet true when this slot data is a wallet item sitting in its wallet slot
local function inWallet(inv, slotData)
    local index = inv.grid.wallet and wallet[slotData.name]

    return index and slotData.slot == inv.grid.cells + index or false
end

---A free identifier: inside the cell count first, then above the wallet identifiers.
---@param inv table
---@param taken? table<number, boolean>
---@return number
local function freeId(inv, taken)
    local items, grid = inv.items, inv.grid

    for slot = 1, grid.cells do
        if not items[slot] and not (taken and taken[slot]) then return slot end
    end

    local slot = grid.base + 1

    while items[slot] or (taken and taken[slot]) do slot += 1 end

    return slot
end

---Highest identifier in use, never below the configured size.
local function usedSlots(inv)
    local highest = inv.grid.base

    for slot in pairs(inv.items) do
        if slot > highest then highest = slot end
    end

    return highest
end

---Tells the owner and whoever has the inventory open about its size.
local function notifySize(inv)
    local grid = inv.grid
    local payload = { inventoryId = inv.id, slots = inv.slots, grid = { w = grid.w, h = grid.height } }

    if inv.player then TriggerClientEvent('ox_inventory:refreshSlotCount', inv.id, payload) end

    for playerId in pairs(inv.openedBy or {}) do
        if playerId ~= inv.id then TriggerClientEvent('ox_inventory:refreshSlotCount', playerId, payload) end
    end
end

---Gives every item a valid position. Returns true when something moved.
local function normalize(inv)
    local grid = inv.grid
    local height, moved = Geo.normalize(inv.items, grid.w, grid.h, getSize, function(slotData) return inWallet(inv, slotData) end)

    grid.height = height
    inv.slots = usedSlots(inv)

    return moved
end

---Where `count` units of an item would go. Nothing is written.
---@param inv table
---@param item table
---@param count number
---@param metadata? table
---@param position? { x: number, y: number, rotated?: boolean } wanted place for the first new stack
---@return { slot: number, count: number, x?: number, y?: number, rotated?: boolean, wallet?: boolean }[] plan, number remaining units without a place
function Grid.planAdd(inv, item, count, metadata, position)
    local items, grid = inv.items, inv.grid
    local walletSlot = Grid.walletSlot(inv, item.name)

    if walletSlot then
        local current = items[walletSlot]

        if current and not matches(current, item, metadata) then return {}, count end

        return { { slot = walletSlot, count = count, wallet = true } }, 0
    end

    local plan = Geo.plan(items, grid.w, grid.h, item.name, count, {
        getSize = getSize,
        stackable = item.stack,
        maxStack = Grid.stackLimit(inv, item),
        matches = function(slotData) return not inWallet(inv, slotData) and table.matches(slotData.metadata or {}, metadata or {}) end,
        position = type(position) == 'table' and position or nil,
    })

    local entries, taken = {}, {}

    for i = 1, #plan.stacks do
        entries[#entries + 1] = { slot = plan.stacks[i].slot, count = plan.stacks[i].add }
    end

    for i = 1, #plan.new do
        local new = plan.new[i]
        local slot = freeId(inv, taken)

        taken[slot] = true
        entries[#entries + 1] = { slot = slot, count = new.count, x = new.x, y = new.y, rotated = new.rotated or nil }
    end

    return entries, plan.remaining
end

---@param inv table
---@return number
function Grid.emptyCells(inv)
    local grid = inv.grid
    local used = 0

    for _ in pairs(Geo.occupancy(inv.items, grid.w, getSize)) do used += 1 end

    return math.max(grid.cells - used, 0)
end

---@param inv table
---@return number? slot a free identifier, when at least one cell is free
function Grid.emptySlot(inv)
    local grid = inv.grid

    if Geo.findSpace(Geo.occupancy(inv.items, grid.w, getSize), grid.w, grid.h, 1, 1, false) then
        return freeId(inv)
    end
end

---Identifier a new unit of the item would use: its wallet, a stack with room, or a new one.
---@param inv table
---@param item table
---@param metadata? table
---@return number?
function Grid.slotForItem(inv, item, metadata)
    local plan = Grid.planAdd(inv, item, 1, metadata)

    return plan[1] and plan[1].slot
end

---@param inv table
---@param item table
---@param count? number
---@param metadata? table
---@return boolean
function Grid.canCarry(inv, item, count, metadata)
    local _, remaining = Grid.planAdd(inv, item, count or 1, metadata)

    return remaining == 0
end

-- position handed to the next Inventory.SetSlot that creates a slot (set by Grid.setSlot)
local pendingPosition

---Called by Inventory.SetSlot for a slot that has no position yet.
---@param inv table
---@param slotData table
---@param preferred? { x: number, y: number, rotated?: boolean }
function Grid.ensurePosition(inv, slotData, preferred)
    local grid = inv.grid

    if not grid or inWallet(inv, slotData) then
        slotData.x, slotData.y, slotData.rotated = nil, nil, nil
        return
    end

    local position = pendingPosition or preferred
    pendingPosition = nil

    if position and position.x then
        slotData.x, slotData.y, slotData.rotated = nil, nil, nil

        if Geo.canPlace(inv.items, grid.w, grid.h, getSize, slotData.name, position.x, position.y, position.rotated, slotData.slot) then
            slotData.x, slotData.y, slotData.rotated = position.x, position.y, position.rotated or nil
            return
        end
    end

    if slotData.x and slotData.y then return end

    local w, h = getSize(slotData.name)
    local x, y, rotated = Geo.findSpace(Geo.occupancy(inv.items, grid.w, getSize), grid.w, grid.h, w, h, true)

    if x then
        slotData.x, slotData.y, slotData.rotated = x, y, rotated or nil
        return
    end

    -- no room: extra rows, the same way a converted inventory keeps what did not fit
    local height = grid.height

    normalize(inv)

    if grid.height ~= height then notifySize(inv) end
end

---Inventory.SetSlot for one entry of a plan.
---@return boolean success, table | string | nil response
function Grid.setSlot(inv, item, entry, metadata)
    pendingPosition = entry.x and entry or nil

    local success, response = Inventory.SetSlot(inv, item, entry.count, metadata, entry.slot)

    pendingPosition = nil

    return success, response
end

---Moves content into the grid: account items to the wallet, a position for everything else.
---What does not fit goes to extra rows below the configured height. Nothing is ever removed.
local function convert(inv)
    local items, grid = inv.items, inv.grid
    local moved = false

    if grid.wallet then
        for index = 1, walletCount do
            local name = config.wallet[index]
            local walletSlot = grid.cells + index
            local occupant = items[walletSlot]

            if occupant and occupant.name ~= name then
                items[walletSlot] = nil
                occupant.slot = freeId(inv)
                items[occupant.slot] = occupant
                moved = true
            end

            local stacks = {}

            for slot, slotData in pairs(items) do
                if slotData.name == name and slot ~= walletSlot then stacks[#stacks + 1] = slotData end
            end

            table.sort(stacks, function(a, b) return a.slot < b.slot end)

            for i = 1, #stacks do
                local slotData = stacks[i]
                local current = items[walletSlot]

                if not current then
                    items[slotData.slot] = nil
                    slotData.slot = walletSlot
                    items[walletSlot] = slotData
                    moved = true
                elseif table.matches(current.metadata or {}, slotData.metadata or {}) then
                    items[slotData.slot] = nil
                    current.count += slotData.count
                    current.weight = Inventory.SlotWeight(Items(name), current)
                    moved = true
                end
            end
        end
    end

    -- an item saved before positions existed starts at the cell its slot used to be
    for slot, slotData in pairs(items) do
        if not slotData.x and slot <= grid.cells and not inWallet(inv, slotData) then
            slotData.x = (slot - 1) % grid.w + 1
            slotData.y = (slot - 1) // grid.w + 1
        end
    end

    return normalize(inv) or moved
end

---Called by Inventory.Create once the items are loaded (and again after items are assigned in bulk).
---@param inv table
function Grid.setup(inv)
    if not Grid.enabled then
        if type(inv.slots) == 'table' then
            local w, h = readSize(inv.slots)
            inv.slots = (w or 1) * (h or 1)
        end
        return
    end

    local grid = inv.grid

    if not grid then
        local w, h = dimensions(inv)

        if not w or not h then return end

        local cells = w * h
        local hasWallet = inv.type == 'player' and walletCount > 0

        grid = { w = w, h = h, height = h, cells = cells, wallet = hasWallet, base = cells + (hasWallet and walletCount or 0) }
        inv.grid = grid
        inv.slots = grid.base
    end

    if type(inv.items) ~= 'table' then return end

    if convert(inv) and inv.changed ~= nil then inv.changed = true end
end

---Size sent to the screen. Also repairs items that reached the inventory without a position.
---@param inv? table
---@return { w: number, h: number }?
function Grid.payload(inv)
    local grid = inv and inv.grid

    if not grid then return end

    for _, slotData in pairs(inv.items) do
        if not slotData.x and not inWallet(inv, slotData) then
            if convert(inv) and inv.changed ~= nil then inv.changed = true end
            break
        end
    end

    return { w = grid.w, h = grid.height, wallet = grid.wallet and grid.cells or nil }
end

---Drops extra rows that are empty again and tells whoever is looking.
---@param inv table
function Grid.trim(inv)
    local grid = inv.grid

    if not grid then return end

    local height = grid.h

    if grid.height > grid.h then
        for _, slotData in pairs(inv.items) do
            if slotData.y then
                local w, h = getSize(slotData.name)
                local bottom = slotData.y + (slotData.rotated and w or h) - 1

                if bottom > height then height = bottom end
            end
        end
    end

    local slots = usedSlots(inv)

    if height ~= grid.height or slots ~= inv.slots then
        grid.height = height
        inv.slots = slots
        notifySize(inv)
    end
end

local overflowDrops = {}

---Leaves what did not fit on the ground next to the player, for anyone, for a limited time.
---Uses the player's last overflow drop while it is close and has room, then as many new drops as needed.
---@return string? dropId last drop used, number left units that could not be left anywhere
local function overflow(inv, item, count, metadata)
    local ped = GetPlayerPed(inv.id)

    if not ped or ped == 0 then return nil, count end

    local coords = GetEntityCoords(ped)
    local instance = Player(inv.id).state.instance
    local dropId = overflowDrops[inv.id]
    local drop = dropId and Inventory.GetLoaded(dropId)
    local total, lastDrop = count, nil

    if drop and (not drop.coords or #(drop.coords - coords) > 3.0) then drop = nil end

    for _ = 1, 10 do
        if count < 1 then break end

        local isNew = false

        if not drop then
            dropId = CustomDrop('Drop', {}, vec3(coords.x, coords.y, coords.z - 0.2), nil, nil, instance)
            drop = dropId and Inventory.GetLoaded(dropId)
            isNew = true

            if not drop then break end
        end

        local _, remaining = Grid.planAdd(drop, item, count, metadata)
        local amount = count - remaining

        if amount > 0 and Inventory.AddItem(drop, item, amount, metadata) then
            drop.klshKeepUntil = os.time() + (config.overflowTime or 900)
            overflowDrops[inv.id] = drop.id
            lastDrop = drop.id
            count -= amount
        elseif isNew then
            -- not even an empty drop takes one unit: give up
            Inventory.Remove(drop)
            break
        end

        drop = nil
    end

    if count > 0 then
        lib.print.warn(('could not leave %sx %s on the ground for player %s'):format(count, item.name, inv.id))
    end

    if lastDrop then
        TriggerClientEvent('ox_lib:notify', inv.id, {
            type = 'warning',
            description = locale('grid_overflow', total - count, metadata?.label or item.label),
        })
        TriggerEvent('ox_inventory:klsh:itemOverflow', inv.id, lastDrop, item.name, total - count)
    end

    return lastDrop, count
end

AddEventHandler('playerDropped', function()
    overflowDrops[source] = nil
end)

---AddItem for inventories with a grid: several stacks when needed, and all or nothing.
---With `allowOverflow` (delivery by another resource or by an admin) what does not fit goes to the ground.
---@return boolean success, table | string | nil response, table? overflow { dropId, count }
function Grid.addItem(inv, item, count, metadata, slot, allowOverflow, logResource)
    local baseMetadata, total

    if item.stack then
        baseMetadata, total = Items.Metadata(inv.id, item, metadata and table.clone(metadata) or {}, count)
    else
        total = count
    end

    local plan, remaining = Grid.planAdd(inv, item, total, baseMetadata)

    if remaining > 0 then
        local canOverflow = allowOverflow and inv.player and not neverDrop[item.name] and not wallet[item.name]

        if not canOverflow then
            if inv.player and allowOverflow then
                TriggerClientEvent('ox_lib:notify', inv.id, { type = 'error', description = locale('grid_full', metadata?.label or item.label) })
            end

            return false, 'inventory_full'
        end

        local ped = GetPlayerPed(inv.id)

        if not ped or ped == 0 then return false, 'inventory_full' end
    end

    local updates, added = {}, 0

    for i = 1, #plan do
        local entry = plan[i]
        local slotMetadata

        if item.stack then
            slotMetadata = i == 1 and baseMetadata or table.clone(baseMetadata)
        else
            slotMetadata = Items.Metadata(inv.id, item, metadata and table.clone(metadata) or {}, 1)
        end

        Grid.setSlot(inv, item, entry, slotMetadata)

        added += entry.count
        updates[i] = { item = inv.items[entry.slot], inventory = inv.id }
    end

    inv.changed = true

    if added > 0 then
        if inv.player and server.syncInventory then server.syncInventory(inv) end

        inv:syncSlotsWithClients(updates, true)

        if logResource then
            lib.logger(inv.owner, 'addItem', ('"%s" added %sx %s to "%s"'):format(logResource, added, item.name, inv.label))
        end
    end

    local dropped

    if remaining > 0 then
        local dropId, left = overflow(inv, item, remaining, metadata)

        if not dropId then
            if added == 0 then return false, 'inventory_full' end
        else
            dropped = { dropId = dropId, count = remaining - left }
        end
    end

    local response

    if #updates == 1 then
        response = updates[1].item
    else
        response = {}

        for i = 1, #updates do response[i] = updates[i].item end
    end

    return true, response, dropped
end

---@param inv table
---@return { w: number, h: number }?
local function area(inv)
    return inv.grid and { w = inv.grid.w, h = inv.grid.h } or nil
end

---Finds how two items trade places: where A (the dragged item) lands so that it covers B, and where B
---goes (A's old place when it fits there, otherwise any free place of that inventory).
---@param px? number place asked by the client for A (the item centred on the pointer)
---@return { x: number, y: number, rotated: boolean, backX?: number, backY?: number, backRotated?: boolean }?
local function findSwap(fromInv, toInv, a, b, px, py, protated)
    local grid, fromGrid = toInv.grid, fromInv.grid
    local same = fromInv == toInv
    local aw, ah = getSize(a.name)
    local bw, bh = getSize(b.name)
    local bRotated = b.rotated and true or false

    if bRotated then bw, bh = bh, bw end

    local toCells = Geo.occupancy(toInv.items, grid.w, getSize, b.slot, same and a.slot or nil)
    local fromCells = fromGrid and (same and toCells or Geo.occupancy(fromInv.items, fromGrid.w, getSize, a.slot))
    local first = a.rotated and true or false
    local tried = {}

    local function try(x, y, rotated)
        if math.type(x) ~= 'integer' or math.type(y) ~= 'integer' then return end

        local key = ('%s:%s:%s'):format(x, y, rotated)

        if tried[key] then return end

        tried[key] = true

        local w, h = Geo.footprint(aw, ah, rotated)

        -- A must take B's place, not just any place
        if not Geo.rectsOverlap(x, y, w, h, b.x, b.y, bw, bh) then return end
        if not Geo.fits(toCells, grid.w, grid.h, x, y, w, h) then return end

        local result = { x = x, y = y, rotated = rotated }

        if not fromGrid then return result end -- B goes to a slot without grid (equipment)

        local cells = fromCells

        if same then
            cells = table.clone(toCells)
            Geo.mark(cells, grid.w, x, y, w, h, a.slot)
        end

        if a.x and Geo.fits(cells, fromGrid.w, fromGrid.h, a.x, a.y, bw, bh) then
            result.backX, result.backY, result.backRotated = a.x, a.y, bRotated
            return result
        end

        local bx, by, turned = Geo.findSpace(cells, fromGrid.w, fromGrid.h, bw, bh, true)

        if not bx then return end

        result.backX, result.backY = bx, by
        result.backRotated = turned ~= bRotated -- findSpace turned the footprint B already had

        return result
    end

    local found = px ~= nil and try(px, py, protated == true) or try(b.x, b.y, first) or try(b.x, b.y, not first)

    if found then return found end

    for pass = 1, 2 do
        local rotated = pass == 1 and first or not first
        local w, h = Geo.footprint(aw, ah, rotated)

        for y = b.y - h + 1, b.y + bh - 1 do
            for x = b.x - w + 1, b.x + bw - 1 do
                found = try(x, y, rotated)

                if found then return found end
            end
        end
    end
end

---Checks what the client asked before swapItems does anything with it, and decides where the item goes.
---The client sends `fromSlot`, and either `toSlot` (the item it dropped onto: stack or swap) or
---`toX`, `toY`, `rotated` (an empty place), or none of them (quick move: the server picks).
---Sets `data.toSlot` and the placement applied by Grid.postSwap. Safe to call again with the same data.
---@return boolean allowed, string? reason
function Grid.preSwap(playerInventory, fromInventory, toInventory, data)
    if not Grid.enabled then return true end

    local original = data.klshOriginal

    if original then
        data.toSlot, data.count = original.toSlot, original.count
    else
        data.klshOriginal = { toSlot = data.toSlot, count = data.count }
    end

    data.klshPlace, data.klshSwap, data.klshMove, data.klshResync, data.klshFrom = nil, nil, nil, nil, nil

    local fromSlot, toSlot = data.fromSlot, data.toSlot

    if fromInventory.grid and (math.type(fromSlot) ~= 'integer' or fromSlot < 1) then return false end

    if data.toType == 'newdrop' then
        data.toSlot = 1
        return true
    end

    local fromData = fromInventory.items[fromSlot]

    if fromData and fromInventory.grid then
        data.klshFrom = { x = fromData.x, y = fromData.y, rotated = fromData.rotated }
    end

    local grid = toInventory.grid

    if not grid then return true end
    if toSlot ~= nil and (math.type(toSlot) ~= 'integer' or toSlot < 1) then return false end

    if not fromData then
        data.toSlot = toSlot or 1
        return true -- the upstream body answers with a resync
    end

    local item = Items(fromData.name)

    if not item then return false end

    local sameInventory = fromInventory == toInventory
    local walletSlot = Grid.walletSlot(toInventory, fromData.name)

    if walletSlot then
        if sameInventory then return false, 'grid_wallet_only' end

        if toSlot ~= walletSlot then data.klshResync = toSlot end

        data.toSlot = walletSlot

        return true
    end

    local target = toSlot and toInventory.items[toSlot]

    if target == fromData then target = nil end

    if target then
        if inWallet(toInventory, target) then return false, 'grid_wallet_only' end

        if target.name == fromData.name and target.stack and table.matches(target.metadata, fromData.metadata) then
            local limit = Grid.stackLimit(toInventory, item)

            if limit then
                local room = limit - target.count

                if room <= 0 then return false, 'grid_stack_full' end
                if data.count > room then data.count = room end
            end

            return true
        end

        -- swap: each item must fit where the other one is
        if fromInventory.grid and inWallet(fromInventory, fromData) then return false, 'grid_wallet_only' end
        if Grid.walletSlot(fromInventory, target.name) then return false, 'grid_wallet_only' end
        if not target.x then return false, 'grid_no_fit' end
        if fromInventory.grid and not fromData.x then return false, 'grid_no_fit' end

        local swap = findSwap(fromInventory, toInventory, fromData, target, data.toX, data.toY, data.rotated)

        if not swap then return false, 'grid_no_fit' end

        if sameInventory then
            -- both keep their identifiers (weapon in hand, hotbar): only the positions change
            data.toSlot = fromSlot
            data.klshMove = { x = swap.x, y = swap.y, rotated = swap.rotated, other = target.slot, otherX = swap.backX, otherY = swap.backY, otherRotated = swap.backRotated }

            return true
        end

        data.klshSwap = swap

        return true
    end

    local x, y, rotated = data.toX, data.toY, data.rotated == true

    if x ~= nil or y ~= nil then
        if math.type(x) ~= 'integer' or math.type(y) ~= 'integer' then return false end

        local whole = data.count >= fromData.count

        if sameInventory and whole then
            if inWallet(fromInventory, fromData) then return false, 'grid_wallet_only' end

            if not Geo.canPlace(toInventory.items, grid.w, grid.h, getSize, fromData.name, x, y, rotated, fromSlot) then
                return false, 'grid_no_fit'
            end

            data.toSlot = fromSlot
            data.klshMove = { x = x, y = y, rotated = rotated }

            return true
        end

        if not Geo.canPlace(toInventory.items, grid.w, grid.h, getSize, fromData.name, x, y, rotated) then
            return false, 'grid_no_fit'
        end

        data.toSlot = freeId(toInventory)
        data.klshPlace = { x = x, y = y, rotated = rotated }

        return true
    end

    -- quick move: a stack with room first, then the first free place
    if sameInventory then return false end

    local plan = Grid.planAdd(toInventory, item, data.count, fromData.metadata)
    local entry = plan[1]

    if not entry then return false, 'grid_no_fit' end
    if data.count > entry.count then data.count = entry.count end

    data.toSlot = entry.slot

    if entry.x then data.klshPlace = { x = entry.x, y = entry.y, rotated = entry.rotated } end

    return true
end

---A move inside the same inventory only changes the position: the item keeps its identifier.
---@return boolean
function Grid.reposition(inv, data)
    local slotData = inv.items[data.fromSlot]
    local move = data.klshMove

    if not slotData or not move then return false end

    local updates = { { item = slotData, inventory = inv.id } }
    local other = move.other and inv.items[move.other]

    if move.other and not other then return false end

    slotData.x, slotData.y, slotData.rotated = move.x, move.y, move.rotated or nil

    if other then
        other.x, other.y = move.otherX, move.otherY

        if move.otherRotated ~= nil then other.rotated = move.otherRotated or nil end
        updates[2] = { item = other, inventory = inv.id }
    end

    if inv.changed ~= nil then inv.changed = true end

    inv:syncSlotsWithClients(updates, true)
    Grid.trim(inv)

    return true
end

---Applies the positions decided by Grid.preSwap once the upstream body moved the items.
function Grid.postSwap(playerInventory, fromInventory, toInventory, data)
    if not Grid.enabled then return end

    local moved = toInventory.items[data.toSlot]
    local back = fromInventory.items[data.fromSlot]
    local swap, place, from = data.klshSwap, data.klshPlace, data.klshFrom

    if moved then
        if swap then
            moved.x, moved.y, moved.rotated = swap.x, swap.y, swap.rotated or nil
        elseif place then
            moved.x, moved.y, moved.rotated = place.x, place.y, place.rotated or nil
        elseif not toInventory.grid or inWallet(toInventory, moved) then
            moved.x, moved.y, moved.rotated = nil, nil, nil
        elseif not moved.x then
            Grid.ensurePosition(toInventory, moved)
        end
    end

    -- what came back in a swap takes the place the moved item left
    if back and back ~= moved and (swap or not back.x or not fromInventory.grid) then
        if fromInventory.grid then
            if swap then
                back.x, back.y = swap.backX, swap.backY

                if swap.backRotated ~= nil then back.rotated = swap.backRotated or nil end
                if not back.x then Grid.ensurePosition(fromInventory, back) end
            elseif not inWallet(fromInventory, back) then
                back.x, back.y, back.rotated = nil, nil, nil
                Grid.ensurePosition(fromInventory, back, from)
            end
        else
            back.x, back.y, back.rotated = nil, nil, nil
        end
    end

    if data.klshResync then
        local slot = data.klshResync

        toInventory:syncSlotsWithClients({
            { item = toInventory.items[slot] or { slot = slot }, inventory = toInventory.id },
        }, true)
    end

    Grid.trim(fromInventory)
end

return Grid
