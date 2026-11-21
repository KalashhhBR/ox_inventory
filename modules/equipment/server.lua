-- klsh: linked 'equipment' inventory (clothing slots) for each player.
-- Stored in the ox_inventory table as (owner, 'equip'); loaded id is 'equip:<owner>'.
if not lib then return end

local data = require 'modules.equipment.shared'
local Items = require 'modules.items.server'

local Equipment = {}
local Inventory

---Called once by modules/inventory/server.lua (avoids a circular require).
function Equipment.init(inventory)
    Inventory = inventory
end

local bagSlot = data.getBagSlot()
local vestSlot = data.getSlotByName('vest')

-- the outfit bag is a native container too: one slot per equipment category (vest and bag never used)
if data.outfitBag then
    Items.containers[data.outfitBag.item] = { size = { data.count, 100000 }, outfit = true }
end

-- backpacks are native container items; capacity, whitelist and blacklist come from data/equipment.lua
for name, backpack in pairs(data.backpacks) do
    local function toSet(list)
        if not list then return end

        local set = {}

        for i = 1, #list do set[list[i]] = true end

        return set
    end

    Items.containers[name] = {
        size = { backpack.slots, backpack.maxWeight },
        whitelist = toSet(backpack.whitelist),
        blacklist = toSet(backpack.blacklist),
    }
end

---@return number? grams moves between inventories at or above this weight take time (nil when disabled)
function Equipment.getTransferMinWeight()
    return data.transfer and data.transfer.minWeight or nil
end

---@param invType string
function Equipment.isLinkedType(invType)
    return invType == data.type or invType == data.backpackType or invType == data.groundType
        or invType == 'otherequipment' or invType == 'otherbackpack'
end

---@param playerInv OxInventory
---@return OxInventory? target the player being searched by this one right now
local function getSearchTarget(playerInv)
    local targetId = playerInv.klshSearching

    if not targetId or playerInv.open ~= targetId then return end

    local target = Inventory.GetLoaded(targetId)

    return target and target.player and target or nil
end

---@param inv OxInventory linked inventory (equipment or worn backpack)
---@return OxInventory? owner the player wearing it
local function getOwner(inv)
    local owner = inv.klshLinkedTo and Inventory.GetLoaded(inv.klshLinkedTo)

    return owner and owner.player and owner or nil
end

---@param inv OxInventory?
---@return boolean linked true for an equipment inventory or a worn backpack
function Equipment.isLinked(inv)
    return inv ~= nil and inv ~= false and inv.klshLinkedTo ~= nil
end

---Returns the player's equipment inventory, loading it when needed. Never keep the returned
---reference: the object can be unloaded and recreated.
---@param playerInv OxInventory
---@return OxInventory?
function Equipment.get(playerInv)
    if not playerInv or not playerInv.player or not playerInv.owner then return end

    local inv = Inventory.GetLoaded(('equip:%s'):format(playerInv.owner))

    if not inv then
        inv = Inventory.Create('equip', locale('equipment'), data.type, data.count, 0, data.maxWeight, playerInv.owner)

        if not inv then return end

        -- the (owner, 'equip') row is the migration mark; read it whenever the inventory is (re)loaded
        inv.klshMigrated = MySQL.scalar.await('SELECT 1 FROM ox_inventory WHERE owner = ? AND name = ?', { tostring(playerInv.owner), 'equip' }) ~= nil
    end

    -- keeps the inventory out of the unload cron and routes slot updates to the owner
    inv.klshLinkedTo = playerInv.id
    inv.openedBy[playerInv.id] = true

    return inv
end

-- players wearing a vest: source -> game timer before which the ped armour is not read (the client
-- needs a moment to apply the value after putting the vest on, logging in or respawning)
local vestWearers = {}

---@param playerInv OxInventory
---@return SlotWithItem? item the vest worn in the vest slot
local function getVest(playerInv)
    local inv = data.vest and vestSlot and Equipment.get(playerInv)

    return inv and inv.items[vestSlot] or nil
end

---Lowers the vest's stored armour to what the ped has now. The value never goes up: armour from other
---sources does not repair the vest.
---@param playerInv OxInventory
---@param force? boolean read even inside the grace period (the vest is about to be taken off)
local function readVestArmour(playerInv, force)
    local item = getVest(playerInv)
    local grace = vestWearers[playerInv.id]

    if not item or not grace or (not force and GetGameTimer() < grace) then return end

    local ped = GetPlayerPed(playerInv.id)

    if ped == 0 then return end

    local armour = GetPedArmour(ped)
    local stored = item.metadata.armour or 100

    if armour >= stored then return end

    item.metadata.armour = armour
    item.metadata.durability = armour -- shown as the condition bar and in the tooltip

    local inv = Equipment.get(playerInv)

    inv.changed = true
    inv:syncSlotsWithClients({ { item = item, inventory = inv.id } }, false)
end

---Follows the vest slot: applies the stored armour when a vest is put on (or the player logs in) and
---removes the armour when it is taken off.
---@param playerInv OxInventory
---@param delay? number ms to wait before applying (login: the appearance resource restores armour first)
function Equipment.refreshVest(playerInv, delay)
    if not data.vest then return end

    local item = getVest(playerInv)
    local wearing = vestWearers[playerInv.id] ~= nil

    if item then
        if playerInv.klshVest == item then return end

        if item.metadata.armour == nil then item.metadata.armour = 100 end

        item.metadata.durability = item.metadata.armour

        playerInv.klshVest = item
        vestWearers[playerInv.id] = GetGameTimer() + (delay or 0) + 5000

        SetTimeout(delay or 0, function()
            if Inventory.GetLoaded(playerInv.id) == playerInv and getVest(playerInv) == item then
                TriggerClientEvent('ox_inventory:klsh:setArmour', playerInv.id, item.metadata.armour)
            end
        end)
    elseif wearing then
        playerInv.klshVest = nil
        vestWearers[playerInv.id] = nil
        TriggerClientEvent('ox_inventory:klsh:setArmour', playerInv.id, 0)
    end
end

if data.vest then
    CreateThread(function()
        while true do
            Wait(data.vest.pollInterval or 2000)

            for playerId in pairs(vestWearers) do
                local playerInv = Inventory.GetLoaded(playerId)

                if playerInv then
                    readVestArmour(playerInv)
                else
                    vestWearers[playerId] = nil
                end
            end
        end
    end)
end

---@param playerInv OxInventory
---@return SlotWithItem? item the backpack item worn in the bag slot
local function getBagItem(playerInv)
    local inv = Equipment.get(playerInv)
    local item = inv and bagSlot and inv.items[bagSlot]

    return item and item.metadata and item.metadata.container and data.backpacks[item.name] and item or nil
end

---Returns the container inventory of the worn backpack, loading it when needed. Never keep the reference.
---@param playerInv OxInventory
---@return OxInventory? bag, SlotWithItem? item
function Equipment.getBag(playerInv)
    local item = getBagItem(playerInv)

    if not item then return end

    local id = item.metadata.container
    local bag = Inventory.GetLoaded(id)

    if not bag then
        local size = item.metadata.size or Items.containers[item.name].size

        bag = Inventory.Create(id, item.label, 'container', Inventory.Grid.containerSize(item.name, size[1]), 0, size[2], false)

        if not bag then return end
    end

    bag.klshLinkedTo = playerInv.id
    bag.openedBy[playerInv.id] = true

    return bag, item
end

---Unlinks a backpack container from its wearer (the inventory stays loaded like any other container).
---@param playerInv OxInventory
---@param containerId string?
local function unlinkBag(playerInv, containerId)
    local bag = containerId and Inventory.GetLoaded(containerId)

    if not bag or bag.klshLinkedTo ~= playerInv.id then return end

    bag.openedBy[playerInv.id] = nil
    bag.klshLinkedTo = nil
    bag.time = os.time()

    return bag
end

---Keeps the carried weight right: the worn backpack adds its own weight plus the reduced content weight
---to the main inventory. The backpack item always stores the full content weight (used when it is taken off).
---@param playerInv OxInventory
function Equipment.recalcBag(playerInv)
    local bag, item = Equipment.getBag(playerInv)
    local carried = 0

    if bag and item then
        local base = Items(item.name).weight
        local content = Inventory.CalculateWeight(bag.items)

        bag.weight = content
        item.metadata.weight = content
        item.weight = base + content
        carried = base + math.floor(content * (1 - (data.backpacks[item.name].reduction or 0)) + 0.5)
    end

    -- absolute on purpose: upstream overwrites inv.weight in several places (Clear, Confiscate, Return, load)
    playerInv.weight = Inventory.CalculateWeight(playerInv.items) + carried
    playerInv.klshBagWeight = carried
end

---Data of the worn backpack for the owner's NUI.
---@param playerInv OxInventory
function Equipment.backpackPayload(playerInv)
    local bag, item = Equipment.getBag(playerInv)

    if not bag or not item then return end

    return {
        id = bag.id,
        type = data.backpackType,
        label = item.metadata.label or item.label,
        slots = bag.slots,
        grid = Inventory.Grid.payload(bag),
        maxWeight = bag.maxWeight,
        items = bag.items,
        reduction = data.backpacks[item.name].reduction or 0,
        baseWeight = Items(item.name).weight,
    }
end

---Follows the backpack worn in the bag slot: links the new container, unlinks the old one, fixes the
---carried weight and tells the owner's NUI.
---@param playerInv OxInventory
---@param notify? boolean send the backpack section to the client when the worn backpack changed
function Equipment.refreshBag(playerInv, notify)
    local item = getBagItem(playerInv)
    local current = item and item.metadata.container or nil
    local previous = playerInv.klshBagId

    if previous ~= current then
        unlinkBag(playerInv, previous)
        playerInv.klshBagId = current
    end

    Equipment.recalcBag(playerInv)

    if notify and previous ~= current then
        TriggerClientEvent('ox_inventory:klsh:setBackpack', playerInv.id, Equipment.backpackPayload(playerInv) or false)
    end
end

---@param playerInv OxInventory
---@return OxInventory? drop the drop shown as "ground" to this player, if it still exists
local function getGround(playerInv)
    local drop = playerInv.klshGroundId and Inventory.GetLoaded(playerInv.klshGroundId)

    return drop and drop.type == 'drop' and drop or nil
end

---Shows a drop as the player's ground section (or none). The player is registered as an observer of the
---drop so slot updates reach the NUI; an emptied drop is removed when nobody else is looking at it.
---@param playerInv OxInventory
---@param dropId string?
local function linkGround(playerInv, dropId)
    local previous = getGround(playerInv)

    if previous and previous.id ~= dropId then
        previous.openedBy[playerInv.id] = nil

        if not next(previous.items) and not next(previous.openedBy) then
            Inventory.Remove(previous)
        end
    end

    playerInv.klshGroundId = dropId

    local drop = getGround(playerInv)

    if drop then
        drop.openedBy[playerInv.id] = true
    else
        playerInv.klshGroundId = nil
    end

    return drop
end

---klsh: an inventory another resource attached to this player (SetAttachedInventory). While it exists it
---takes the place of the ground section; the drop logic above is left untouched.
---@param playerInv OxInventory
---@return OxInventory?
local function getAttached(playerInv)
    local inv = playerInv.klshAttachedId and Inventory.GetLoaded(playerInv.klshAttachedId)

    return inv and inv.klshAttachedTo == playerInv.id and inv or nil
end

---@param playerInv OxInventory
---@return OxInventory? attached the attached inventory, only while it is the section on screen
local function shownAttached(playerInv)
    return playerInv.klshAttachedShown and getAttached(playerInv) or nil
end

---The attached inventory leaves the screen. The player stops observing it, unless it is also the
---inventory opened on the right (then the regular open owns that entry).
---@param playerInv OxInventory
local function hideAttached(playerInv)
    if not playerInv.klshAttachedShown then return end

    playerInv.klshAttachedShown = nil

    local inv = playerInv.klshAttachedId and Inventory.GetLoaded(playerInv.klshAttachedId)

    if inv and playerInv.open ~= inv.id then
        inv.openedBy[playerInv.id] = nil
    end
end

---@param playerInv OxInventory
---@return string[] dropIds drops inside the configured distance and in the player's instance, nearest first
local function nearbyDrops(playerInv)
    local ped = GetPlayerPed(playerInv.id)
    local found = {}

    if ped == 0 then return found end

    local coords = GetEntityCoords(ped)
    local instance = Player(playerInv.id).state.instance

    for dropId, drop in pairs(Inventory.Drops) do
        if drop.coords and (not drop.instance or drop.instance == instance) then
            local distance = #(coords - drop.coords)

            if distance <= data.groundDistance then
                found[#found + 1] = { id = dropId, distance = distance }
            end
        end
    end

    table.sort(found, function(a, b)
        if a.distance == b.distance then return tostring(a.id) < tostring(b.id) end

        return a.distance < b.distance
    end)

    for i = 1, #found do found[i] = found[i].id end

    return found
end

---@param playerInv OxInventory
---@return string? dropId nearest drop to the player, inside the configured distance and same instance
local function findNearestDrop(playerInv)
    return nearbyDrops(playerInv)[1]
end

---klsh: the attached inventory, when it may be a page of the ground section (it is not the one on the right).
---@param playerInv OxInventory
---@return OxInventory?
local function pageAttached(playerInv)
    local attached = getAttached(playerInv)

    return attached and playerInv.open ~= attached.id and attached or nil
end

---klsh: puts the attached inventory on screen as the first page of the ground section.
---@param playerInv OxInventory
---@param attached OxInventory
---@return table payload
local function showAttached(playerInv, attached)
    linkGround(playerInv, nil)
    attached.openedBy[playerInv.id] = true
    playerInv.klshAttachedShown = true

    local pages = #nearbyDrops(playerInv) + 1

    return {
        nav = pages > 1 and { index = 1, count = pages } or nil,
        id = attached.id,
        type = data.groundType,
        label = attached.label,
        slots = attached.slots,
        grid = Inventory.Grid.payload(attached),
        maxWeight = attached.maxWeight,
        items = attached.items,
    }
end

---@param playerInv OxInventory
---@return table payload ground section for the NUI: the linked drop, or an empty area for a new drop
local function getGroundPayload(playerInv)
    local drop = getGround(playerInv)
    local reach = nearbyDrops(playerInv)
    local index = 0
    -- klsh: an attached inventory is one more page, before the drops
    local extra = pageAttached(playerInv) and 1 or 0

    for i = 1, #reach do
        if drop and reach[i] == drop.id then index = i end
    end

    return {
        -- more than one page within reach: the NUI lets the player go through them
        nav = #reach + extra > 1 and { index = index + extra, count = #reach + extra } or nil,
        id = drop and drop.id or 'newground',
        type = data.groundType,
        label = drop and drop.klshNamed and drop.label or locale('equipment_ground'), -- klsh: a named drop keeps its name
        slots = drop and drop.slots or shared.dropslots,
        grid = drop and Inventory.Grid.payload(drop) or shared.grid and { w = shared.grid.drop.w, h = shared.grid.drop.h } or nil,
        maxWeight = drop and drop.maxWeight or shared.dropweight,
        items = drop and drop.items or {},
    }
end

---Ground section sent when an inventory opens. Only with a secondary inventory that is not itself the ground.
---@param playerInv OxInventory
---@param right OxInventory?
function Equipment.groundPayload(playerInv, right)
    local ped = GetPlayerPed(playerInv.id)
    local inVehicle = ped ~= 0 and GetVehiclePedIsIn(ped, false) ~= 0

    -- no ground from inside a vehicle (glovebox, trunk opened from the seat)
    if not data.groundDistance or inVehicle or not right or right == playerInv or right.type == 'drop' or right.type == 'shop' or right.player then
        linkGround(playerInv, nil)
        hideAttached(playerInv)
        return
    end

    -- klsh: an attached inventory is the first page of the section (unless it is the one opened on the right)
    local attached = pageAttached(playerInv)

    if attached then return showAttached(playerInv, attached) end

    hideAttached(playerInv)
    linkGround(playerInv, findNearestDrop(playerInv))

    return getGroundPayload(playerInv)
end

---klsh: attaches an inventory to a player (or detaches with nil). While attached it is shown in place of
---the ground section whenever the player has another inventory open, and the cleanup cron keeps it loaded.
---Nothing here decides who may move what: the resource that owns the inventory does that with hooks.
---@param source number
---@param invId? string
---@return boolean
local function setAttachedInventory(source, invId)
    local playerInv = Inventory.GetLoaded(source)

    if not playerInv or not playerInv.player then return false end

    local inv

    if invId ~= nil then
        inv = Inventory.GetLoaded(invId)

        if not inv or inv.player or inv.type == 'drop' or inv == playerInv then return false end
    end

    local previous = playerInv.klshAttachedId and Inventory.GetLoaded(playerInv.klshAttachedId)

    hideAttached(playerInv)

    if previous and previous.klshAttachedTo == playerInv.id then previous.klshAttachedTo = nil end

    playerInv.klshAttachedId = inv and inv.id or nil

    if inv then inv.klshAttachedTo = playerInv.id end

    -- with the screen open the section changes right away
    local right = playerInv.open and playerInv.open ~= playerInv.id and Inventory.GetLoaded(playerInv.open)

    if right then
        TriggerClientEvent('ox_inventory:klsh:setGround', source, Equipment.groundPayload(playerInv, right) or false)
    end

    return true
end

exports('SetAttachedInventory', setAttachedInventory)

---The player asked for the next (or previous) drop within reach as the ground section.
lib.callback.register('ox_inventory:klsh:cycleGround', function(source, step)
    local playerInv = Inventory.GetLoaded(source)

    if not playerInv or not data.groundDistance or not playerInv.open or playerInv.open == playerInv.id then return end

    -- the same conditions under which the ground section exists (Equipment.groundPayload)
    local right = Inventory.GetLoaded(playerInv.open)
    local ped = GetPlayerPed(source)

    if not right or right == playerInv or right.type == 'drop' or right.type == 'shop' or right.player then return end
    if ped == 0 or GetVehiclePedIsIn(ped, false) ~= 0 then return end

    local reach = nearbyDrops(playerInv)
    -- klsh: the attached inventory is page 1, the drops come after it
    local attached = pageAttached(playerInv)
    local extra = attached and 1 or 0
    local pages = #reach + extra

    if pages == 0 then return end

    local current = 0

    if shownAttached(playerInv) then
        current = 1
    else
        for i = 1, #reach do
            if reach[i] == playerInv.klshGroundId then current = i + extra end
        end
    end

    local target = (current - 1 + (step == -1 and -1 or 1)) % pages + 1

    if attached and target == 1 then return showAttached(playerInv, attached) end

    hideAttached(playerInv)
    linkGround(playerInv, reach[target - extra])

    return getGroundPayload(playerInv)
end)

---The player closed the inventory.
---@param playerInv OxInventory
function Equipment.onClose(playerInv)
    if playerInv.klshGroundId then linkGround(playerInv, nil) end

    hideAttached(playerInv) -- klsh

    local targetId = playerInv.klshSearching

    if targetId then
        playerInv.klshSearching = nil

        local target = Inventory.GetLoaded(targetId)

        if target then
            if target.klshSearchedBy then target.klshSearchedBy[playerInv.id] = nil end

            -- stop sending the target's equipment and backpack updates to this player
            local equipment = Inventory.GetLoaded(('equip:%s'):format(target.owner))
            local bag = target.klshBagId and Inventory.GetLoaded(target.klshBagId)

            if equipment then equipment.openedBy[playerInv.id] = nil end
            if bag then bag.openedBy[playerInv.id] = nil end
        end
    end
end

---Equipment and worn backpack of the player being searched, for the searcher's screen.
---@param playerInv OxInventory searcher
---@param right OxInventory? inventory opened on the right
function Equipment.searchPayload(playerInv, right)
    if not right or not right.player or right == playerInv then
        playerInv.klshSearching = nil
        return
    end

    playerInv.klshSearching = right.id
    right.klshSearchedBy = right.klshSearchedBy or {}
    right.klshSearchedBy[playerInv.id] = true

    Equipment.ensureMigrated(right)

    local equipment = Equipment.get(right)
    local backpack = Equipment.backpackPayload(right)
    local bag = Equipment.getBag(right)

    if equipment then equipment.openedBy[playerInv.id] = true end
    if bag then bag.openedBy[playerInv.id] = true end
    if backpack then backpack.type = 'otherbackpack' end

    return {
        equipment = equipment and { id = equipment.id, type = 'otherequipment', slots = equipment.slots, items = equipment.items } or nil,
        backpack = backpack,
    }
end

---Sends the searched player's equipment and backpack again to whoever is searching them.
---@param target OxInventory
local function refreshSearchers(target)
    if not target.klshSearchedBy then return end

    for searcherId in pairs(target.klshSearchedBy) do
        local searcher = Inventory.GetLoaded(searcherId)

        if searcher and searcher.klshSearching == target.id and searcher.open == target.id then
            TriggerClientEvent('ox_inventory:klsh:setSearch', searcherId, Equipment.searchPayload(searcher, target) or false)
        else
            target.klshSearchedBy[searcherId] = nil
        end
    end
end

---A swap to the ground with no drop linked creates a new drop (upstream 'newdrop' path).
---@param playerInv OxInventory
---@param swap table swapItems payload
function Equipment.prepareGround(playerInv, swap)
    if swap.toType == data.groundType and not shownAttached(playerInv) and not getGround(playerInv) then
        swap.toType = 'newdrop'
    end
end

---A drop was just created by this player. With a secondary inventory open it becomes the ground section
---instead of replacing the secondary inventory on the client.
---@param source number
---@param dropId string
---@param owner number | false value upstream would send as the drop "owner"
---@return number | false owner
function Equipment.onDropCreated(source, dropId, owner)
    local playerInv = Inventory.GetLoaded(source)

    if not playerInv or not data.groundDistance or not playerInv.open or playerInv.open == playerInv.id then
        return owner
    end

    local right = Inventory.GetLoaded(playerInv.open)

    if not right or right.type == 'drop' then return owner end

    -- klsh: the section is showing an attached inventory: it stays, and gains the new drop as a page
    local attached = shownAttached(playerInv)

    if attached then
        TriggerClientEvent('ox_inventory:klsh:setGround', source, showAttached(playerInv, attached))
        return false
    end

    linkGround(playerInv, dropId)
    TriggerClientEvent('ox_inventory:klsh:setGround', source, getGroundPayload(playerInv))

    return false
end

-- Death, clearing and confiscation: clothing stays on the body; the worn backpack and the vest follow
-- the rest of the inventory.

---Takes the vest and the worn backpack off at once (no time, no checks). The backpack keeps its content.
---@param playerInv OxInventory
---@param filter? fun(item: SlotWithItem): boolean return false to leave the piece on the body
---@return SlotWithItem[] taken
function Equipment.takeWorn(playerInv, filter)
    local taken = {}
    local inv = Equipment.get(playerInv)

    if not inv then return taken end

    readVestArmour(playerInv, true) -- the vest leaves with the armour it has right now

    local slots = {}

    for _, slot in ipairs({ vestSlot, bagSlot }) do
        local item = slot and inv.items[slot]

        if item and (not filter or filter(item) ~= false) then
            inv.items[slot] = nil
            taken[#taken + 1] = item
            slots[#slots + 1] = { item = { slot = slot }, inventory = inv.id }
        end
    end

    if #taken == 0 then return taken end

    inv.weight = Inventory.CalculateWeight(inv.items)
    inv.changed = true
    inv:syncSlotsWithClients(slots, false)

    Equipment.refreshBag(playerInv, true)
    Equipment.refreshVest(playerInv)
    Equipment.pushAppearance(playerInv, true)
    refreshSearchers(playerInv)

    return taken
end

---Empties the content of a container item that is being destroyed.
---@param item SlotWithItem
local function wipeContainer(item)
    local id = item.metadata and item.metadata.container

    if not id then return end

    local container = Inventory.GetLoaded(id)

    if container then
        table.wipe(container.items)
        container.weight = 0
        container.changed = true
        Inventory.Remove(container) -- saves it empty and unloads it
    else
        MySQL.update('DELETE FROM ox_inventory WHERE name = ?', { id })
    end
end

---@param list? string | string[] | table<string, boolean>
---@return table<string, boolean>? set
local function toNameSet(list)
    if type(list) == 'string' then return { [list] = true } end
    if type(list) ~= 'table' then return end

    local set = {}

    for key, value in pairs(list) do
        if type(key) == 'number' and type(value) == 'string' then
            set[value] = true
        elseif type(key) == 'string' and value then
            set[key] = true
        end
    end

    return next(set) and set or nil
end

---ClearInventory on a player: the worn backpack (and what is inside) and the vest are destroyed too,
---unless their item name is in `keep`.
---@param playerInv OxInventory
---@param keep? string | string[]
function Equipment.onClear(playerInv, keep)
    local kept = toNameSet(keep)
    local taken = Equipment.takeWorn(playerInv, function(item)
        return not (kept and kept[item.name])
    end)

    for i = 1, #taken do wipeContainer(taken[i]) end
end

---@param playerInv OxInventory
---@return boolean waiting true when something confiscated from this character was not returned yet
function Equipment.hasConfiscated(playerInv)
    local owner = tostring(playerInv.owner)

    return MySQL.scalar.await('SELECT 1 FROM ox_inventory WHERE (owner = ? AND name = ?) OR (owner = ? AND name = ?) LIMIT 1',
        { owner, owner, owner, 'equip-confiscated' }) ~= nil
end

---Removes the discarded items from a container item that is about to be confiscated.
---@param container OxInventory?
---@param item SlotWithItem the container item
---@param discard table<string, boolean>
local function discardFromContainer(container, item, discard)
    if not container then return end

    local changed = false

    for slot, content in pairs(container.items) do
        if discard[content.name] then
            container.items[slot] = nil
            changed = true
        end
    end

    if not changed then return end

    local weight = Inventory.CalculateWeight(container.items)

    container.weight = weight
    container.changed = true
    item.metadata.weight = weight
    item.weight = Items(item.name).weight + weight
end

---ConfiscateInventory: applies `options.discard` (main inventory, containers in it, vest, worn backpack
---and its content) and takes the vest and the worn backpack off.
---@param playerInv OxInventory
---@param options? { discard?: string[] | table<string, boolean> }
---@return table[]? worn what goes into the 'equip-confiscated' record
function Equipment.onConfiscate(playerInv, options)
    local discard = toNameSet(type(options) == 'table' and options.discard or nil)

    if discard then
        for slot, item in pairs(playerInv.items) do
            if discard[item.name] then
                wipeContainer(item)
                playerInv.items[slot] = nil
            elseif item.metadata and item.metadata.container then
                discardFromContainer(Inventory.GetContainerFromSlot(playerInv, slot), item, discard)
            end
        end

        local bag, bagItem = Equipment.getBag(playerInv)

        if bag and bagItem and not discard[bagItem.name] then
            discardFromContainer(bag, bagItem, discard)
        end
    end

    local taken = Equipment.takeWorn(playerInv)
    local worn, n = {}, 0

    for i = 1, #taken do
        local item = taken[i]

        if discard and discard[item.name] then
            wipeContainer(item)
        else
            n += 1
            worn[n] = { name = item.name, count = 1, slot = item.slot, metadata = item.metadata }
        end
    end

    return n > 0 and worn or nil
end

---ReturnInventory: the confiscated vest and backpack go back to their slots; when the slot is taken
---they go to the inventory (or to the ground next to the player).
---@param playerInv OxInventory
function Equipment.onReturn(playerInv)
    local owner = tostring(playerInv.owner)
    local stored = MySQL.scalar.await('SELECT data FROM ox_inventory WHERE owner = ? AND name = ?', { owner, 'equip-confiscated' })

    if not stored then return end

    MySQL.update.await('DELETE FROM ox_inventory WHERE owner = ? AND name = ?', { owner, 'equip-confiscated' })

    local worn = json.decode(stored)
    local inv = Equipment.get(playerInv)

    if type(worn) ~= 'table' or not inv then return end

    for i = 1, #worn do
        local piece = worn[i]
        local item = type(piece) == 'table' and Items(piece.name)

        if item then
            local slot = data.getSlot(piece.name)
            local placed = slot and not inv.items[slot] and Inventory.AddItem(inv, item, 1, piece.metadata, slot)

            if not placed then
                Inventory.AddItem(playerInv, item, 1, piece.metadata, nil, nil, true)
            end
        end
    end

    Equipment.refreshBag(playerInv, true)
    Equipment.refreshVest(playerInv)
    Equipment.pushAppearance(playerInv, true)
    refreshSearchers(playerInv)
end

---@param playerInv OxInventory
---@param invType string
---@return OxInventory?
function Equipment.resolve(playerInv, invType)
    if invType == data.type then
        return Equipment.get(playerInv)
    elseif invType == data.backpackType then
        return (Equipment.getBag(playerInv))
    elseif invType == data.groundType then
        return shownAttached(playerInv) or getGround(playerInv)
    elseif invType == 'otherequipment' or invType == 'otherbackpack' then
        local target = getSearchTarget(playerInv)

        if not target then return end

        local inv = invType == 'otherequipment' and Equipment.get(target) or (Equipment.getBag(target))

        if inv then inv.openedBy[playerInv.id] = true end

        return inv
    end
end

---@param fromInv OxInventory
---@param toInv OxInventory
---@return OxInventory? container the container item opened on the right, when it takes part in the move
function Equipment.getOpenedContainer(fromInv, toInv)
    if fromInv.type == 'container' and not Equipment.isLinked(fromInv) then return fromInv end
    if toInv.type == 'container' and not Equipment.isLinked(toInv) then return toInv end
end

---@param playerId number
---@return string? model configured ped model name of the player
local function getPlayerModel(playerId)
    local ped = GetPlayerPed(playerId)

    return ped and ped ~= 0 and data.getModel(GetEntityModel(ped)) or nil
end

---Sends the worn pieces to the owner so the client can dress the ped. `false` clears the client state
---(character not migrated yet: the ped keeps whatever the appearance resource loaded).
---@param playerInv OxInventory
---@param persist? boolean the equipment just changed: the client also saves the look in the appearance resource
function Equipment.pushAppearance(playerInv, persist)
    local inv = Equipment.get(playerInv)

    if not inv then return end

    if not inv.klshMigrated then
        return TriggerClientEvent('ox_inventory:klsh:applyEquipment', playerInv.id, false)
    end

    local state = {}

    for slot = 1, data.count do
        local item = inv.items[slot]
        local metadata = item and item.metadata

        state[slot] = item and {
            model = metadata.model,
            drawable = metadata.drawable,
            texture = metadata.texture,
            arms = metadata.arms,
            -- backpacks look the same for everyone: drawable per ped model from the config
            byModel = data.backpacks[item.name] and data.backpacks[item.name].drawable
                or (slot == vestSlot and not metadata.drawable and data.vest and data.vest.drawable)
                or nil,
        } or false
    end

    TriggerClientEvent('ox_inventory:klsh:applyEquipment', playerInv.id, state, persist)
end

---@param value any
---@param min number
---@param max number
local function isIntegerBetween(value, min, max)
    return math.type(value) == 'integer' and value >= min and value <= max
end

---@param piece any { drawable, texture } reported by the client
---@param isProp boolean
---@return { drawable: number, texture: number }?
local function sanitizePiece(piece, isProp)
    if type(piece) ~= 'table' then return end

    local drawable, texture = piece.drawable, piece.texture

    if type(drawable) == 'number' then drawable = math.tointeger(drawable) end
    if type(texture) == 'number' then texture = math.tointeger(texture) end

    if not isIntegerBetween(drawable, isProp and -1 or 0, 5000) then return end
    if not isIntegerBetween(texture, isProp and -1 or 0, 255) then texture = 0 end

    return { drawable = drawable, texture = math.max(texture, 0) }
end

---@param model string
---@param category table
---@param piece { drawable: number, texture: number }
local function isNaked(model, category, piece)
    if category.type == 'prop' then return piece.drawable < 0 end

    return piece.drawable == (data.models[model].naked[category.name] or 0)
end

---Turns the clothing the character is wearing into equipped items, once per character.
---The existence of the (owner, 'equip') row is the migration mark.
---@param playerInv OxInventory
---@param force? boolean admin: fill the empty slots again from what the ped wears
---@return boolean migrated
function Equipment.ensureMigrated(playerInv, force)
    local inv = Equipment.get(playerInv)

    if not inv then return false end
    if inv.klshMigrated and not force then return true end
    if inv.klshMigrating then return false end

    local model = getPlayerModel(playerInv.id)

    if not model then return false end -- not a clothing model right now; try again on the next contact

    inv.klshMigrating = true

    local ok, worn = pcall(lib.callback.await, 'ox_inventory:klsh:reportWorn', playerInv.id)

    -- the player may have left or changed character while the server waited
    if not ok or type(worn) ~= 'table' or Inventory.GetLoaded(inv.id) ~= inv or getPlayerModel(playerInv.id) ~= model then
        inv.klshMigrating = nil
        return false
    end

    inv.klshMigrated = true

    local components = type(worn.components) == 'table' and worn.components or {}
    local props = type(worn.props) == 'table' and worn.props or {}
    local arms = sanitizePiece(components[3] or components['3'], false)

    for slot = 1, data.count do
        local category = data.categories[slot]
        local itemName = category.items[1]

        -- gloves share the arms component with the top: never created from the worn appearance
        if itemName and not inv.items[slot] and category.name ~= 'gloves' then
            local source = category.type == 'prop' and props or components
            local piece = sanitizePiece(source[category.id] or source[tostring(category.id)], category.type == 'prop')

            if piece and not isNaked(model, category, piece) then
                local item = Items(itemName)

                Inventory.AddItem(inv, itemName, 1, {
                    model = model,
                    drawable = piece.drawable,
                    texture = piece.texture,
                    arms = category.name == 'top' and arms or nil,
                }, slot)
            end
        end
    end

    Inventory.Save(inv) -- writes the row (the migration mark) even when nothing was worn
    inv.klshMigrating = nil

    Equipment.pushAppearance(playerInv, true)

    return true
end

---@param playerInv OxInventory
function Equipment.onPlayerLoaded(playerInv)
    local inv = Equipment.get(playerInv)

    if not inv then return end

    -- inventory:clearstashes deletes rows by lastupdated, which only changes on writes
    if inv.klshMigrated then
        MySQL.update('UPDATE ox_inventory SET lastupdated = NOW() WHERE owner = ? AND name = ?', { playerInv.owner, 'equip' })
    end

    Equipment.refreshBag(playerInv)
    Equipment.refreshVest(playerInv, 6000)

    if playerInv.klshBagId then
        MySQL.update('UPDATE ox_inventory SET lastupdated = NOW() WHERE owner = ? AND name = ?', { '', playerInv.klshBagId })
    end

    Equipment.pushAppearance(playerInv)
end

---@param playerInv OxInventory
function Equipment.onPlayerDropped(playerInv)
    if not playerInv or not playerInv.owner then return end

    local inv = Inventory.GetLoaded(('equip:%s'):format(playerInv.owner))

    if not inv then return end

    local bag = unlinkBag(playerInv, playerInv.klshBagId)

    if bag then Inventory.Remove(bag) end -- saves the content right away

    -- outfit bags carried by the player: save their content now instead of waiting for the cron
    for _, item in pairs(playerInv.items) do
        local id = item.metadata and item.metadata.container

        if data.isOutfitId(id) then
            local outfit = Inventory.GetLoaded(id)

            if outfit and not next(outfit.openedBy) then Inventory.Remove(outfit) end
        end
    end

    readVestArmour(playerInv, true)
    vestWearers[playerInv.id] = nil

    inv.openedBy[playerInv.id] = nil
    inv.klshLinkedTo = nil
    Inventory.Remove(inv)
end

---Data sent to the owner's NUI when the inventory opens.
---@param playerInv OxInventory
function Equipment.payload(playerInv)
    local inv = Equipment.get(playerInv)

    if not inv then return end

    Equipment.ensureMigrated(playerInv)

    return {
        id = inv.id,
        type = inv.type,
        slots = inv.slots,
        items = inv.items,
    }
end

local function isValidSlot(inv, slot)
    return math.type(slot) == 'integer' and slot >= 1 and slot <= inv.slots
end

---@param value any
---@return any value integer when the number has no fractional part (NUI payloads may arrive as floats)
local function toInteger(value)
    return type(value) == 'number' and math.tointeger(value) or value
end

---Validates a swapItems request that involves an equipment inventory, before the upstream body runs.
---@param playerId number
---@param item SlotWithItem
---@return boolean fits false when the piece was made for another ped model
local function fitsPlayer(playerId, item)
    local model = item.metadata and item.metadata.model

    return not model or model == getPlayerModel(playerId)
end

---Checks an equipment move against the current state. Called before and after the progress wait.
---@param playerInv OxInventory
---@param fromInv OxInventory
---@param toInv OxInventory
---@param swap table swapItems payload
---@return boolean allowed, string? reason, number? duration ms the change takes
local function validateSwap(playerInv, fromInv, toInv, swap)
    local fromEquipment, toEquipment = fromInv.type == data.type, toInv.type == data.type

    if fromEquipment and not isValidSlot(fromInv, swap.fromSlot) then return false end
    if toEquipment and not isValidSlot(toInv, swap.toSlot) then return false end

    local fromData = fromInv.items[swap.fromSlot]

    if not fromData then return true, nil, 0 end -- upstream answers with a slot refresh

    local toData = swap.toType ~= 'newdrop' and toInv.items[swap.toSlot] or nil
    local duration = 0

    if toEquipment then
        if data.getSlot(fromData.name) ~= swap.toSlot then
            return false, 'equipment_wrong_slot'
        end

        if not fitsPlayer((getOwner(toInv) or playerInv).id, fromData) then
            return false, 'equipment_wrong_model'
        end

        swap.count = 1
        -- putting on, plus taking off the piece that is already there
        duration += data.getDuration(swap.toSlot) * (toData and 2 or 1)
    end

    if fromEquipment then
        -- a swap would push the target item into the equipment slot
        if toData and data.getSlot(toData.name) ~= swap.fromSlot then
            return false, 'equipment_wrong_slot'
        end

        if toData and not fitsPlayer((getOwner(fromInv) or playerInv).id, toData) then
            return false, 'equipment_wrong_model'
        end

        duration += data.getDuration(swap.fromSlot) * (toData and 2 or 1)
    end

    -- the worn backpack taking part in the move, and who wears it (the player or the one being searched)
    local wearer = fromInv.type == 'container' and getOwner(fromInv) or toInv.type == 'container' and getOwner(toInv) or playerInv
    local bag, bagItem = Equipment.getBag(wearer)

    if bag and (fromInv == bag or toInv == bag) and fromInv ~= toInv then
        local backpack = data.backpacks[bagItem.name]
        local count = math.min(swap.count or 1, fromData.count)
        local moving = Inventory.SlotWeight(Items(fromData.name), fromData, true) * count
        local isSwap = toData and (toData.name ~= fromData.name or not toData.stack or not table.matches(toData.metadata, fromData.metadata))
        local back = isSwap and toData.weight or 0
        local entering = toInv == bag and fromData or (isSwap and toData or nil)

        if entering then
            if entering.metadata.container then return false end

            local container = Items.containers[bagItem.name]

            if (container.whitelist and not container.whitelist[entering.name]) or (container.blacklist and container.blacklist[entering.name]) then
                return false, 'cannot_perform'
            end
        end

        -- weight that each side gains; the worn backpack only passes part of it on to the main inventory
        local carriedShare = 1 - (backpack.reduction or 0)
        local mainDelta = 0

        for i = 1, 2 do
            local inv = i == 1 and fromInv or toInv
            local delta = i == 1 and (back - moving) or (moving - back)

            if inv == bag then
                if delta > 0 and bag.weight + delta > bag.maxWeight then return false, 'cannot_carry' end

                mainDelta += delta * carriedShare
            elseif inv == wearer then
                mainDelta += delta
            elseif delta > 0 and inv.weight + delta > inv.maxWeight then
                return false, 'cannot_carry_other'
            end
        end

        if mainDelta > 0 and wearer.weight + mainDelta > wearer.maxWeight then
            return false, wearer == playerInv and 'cannot_carry' or 'cannot_carry_other'
        end
    end

    if duration > 0 then
        local ped = GetPlayerPed(playerInv.id)

        if ped == 0 or GetVehiclePedIsIn(ped, false) ~= 0 then
            return false, 'equipment_blocked'
        end
    end

    return true, nil, duration
end

---Asks the client to run the progress (animation, cancel, client-side blocks) with our own timeout.
---@param playerId number
---@param payload { inventory: string | number, slot: number, duration: number, clothing: boolean }
---@return boolean finished, string? reason
local function awaitProgress(playerId, payload)
    local result = promise.new()
    local settled = false

    CreateThread(function()
        local ok, finished, reason = pcall(lib.callback.await, 'ox_inventory:klsh:equipProgress', playerId, payload)

        if settled then return end

        settled = true
        result:resolve({ ok and finished == true, ok and reason or nil })
    end)

    SetTimeout(payload.duration + 3000, function()
        if settled then return end

        settled = true
        result:resolve({ false })
    end)

    local values = Citizen.Await(result)

    return values[1], values[2]
end

---Time to carry items between two different inventories, from the weight being moved.
---@param fromInv OxInventory
---@param toInv OxInventory
---@param swap table swapItems payload
---@return number ms
local function getTransferDuration(fromInv, toInv, swap)
    local transfer = data.transfer

    if not transfer or (fromInv == toInv and swap.toType ~= 'newdrop') then return 0 end

    local fromData = fromInv.items[swap.fromSlot]
    local item = fromData and Items(fromData.name)

    if not item then return 0 end

    local count = math.min(swap.count or 1, fromData.count)
    local weight = Inventory.SlotWeight(item, fromData, true) * count
    local toData = swap.toType ~= 'newdrop' and toInv.items[swap.toSlot] or nil

    -- swapping two different items carries both
    if toData and (toData.name ~= fromData.name or not toData.stack or not table.matches(toData.metadata, fromData.metadata)) then
        weight += toData.weight
    end

    if weight < transfer.minWeight then return 0 end

    return math.min(transfer.max, math.floor(weight / 1000 * transfer.msPerKg))
end

---Handing an item to another player takes time (weight based, never below `transfer.giveMin`) and plays
---the hand over animation on both. The server measures the time itself.
---@param playerId number giver
---@param targetId number receiver
---@param slotData table item being given
---@param count number
---@return boolean finished
function Equipment.giveWait(playerId, targetId, slotData, count)
    local transfer = data.transfer

    if not transfer then return true end

    local item = Items(slotData.name)
    local weight = item and Inventory.SlotWeight(item, slotData, true) * count or 0
    local duration = math.max(transfer.giveMin or 0, math.min(transfer.max, math.floor(weight / 1000 * transfer.msPerKg)))

    if duration < 1 then return true end

    TriggerClientEvent('ox_inventory:klsh:giveAnim', targetId, duration)

    local started = GetGameTimer()
    local finished = awaitProgress(playerId, { inventory = playerId, slot = slotData.slot, duration = duration, clothing = false, give = true })

    return finished and GetGameTimer() - started >= duration * 0.9
end

---The upstream body checks the main inventory against the worn backpack's full weight when it is taken
---off or replaced; the reduced share already carried must not count twice. The scheduled refresh
---restores the right value whether the move succeeds or not.
local function discountWornBag(playerInv, fromInv, toInv, swap)
    if not playerInv.klshBagWeight or playerInv.klshBagWeight <= 0 then return end

    -- only the player's own equipment: taking someone else's backpack carries its full weight
    local equipment = fromInv.type == data.type and fromInv or toInv.type == data.type and toInv or nil

    if not equipment or equipment.klshLinkedTo ~= playerInv.id then return end

    local takingOff = fromInv.type == data.type and swap.fromSlot == bagSlot and toInv == playerInv
    local replacing = toInv.type == data.type and swap.toSlot == bagSlot and fromInv == playerInv and toInv.items[bagSlot]

    if not takingOff and not replacing then return end

    playerInv.weight -= playerInv.klshBagWeight
    playerInv.klshBagWeight = 0

    SetTimeout(0, function()
        if Inventory.GetLoaded(playerInv.id) == playerInv then
            Equipment.refreshBag(playerInv, true)
        end
    end)
end

---Prelude of swapItems: validates moves that involve linked inventories, waits on the client for
---moves that take time (clothing changes, heavy transfers between inventories) and validates again.
---The upstream body only runs (and only reads state) afterwards.
---@param playerInv OxInventory
---@param fromInv OxInventory
---@param toInv OxInventory
---@param swap table swapItems payload
---@return boolean allowed, string? reason locale key
function Equipment.preSwap(playerInv, fromInv, toInv, swap)
    local fromEquipment, toEquipment = fromInv.type == data.type, toInv.type == data.type

    -- an outfit bag swap is running for this player or for the one being searched
    if playerInv.klshOutfitBusy then return false end

    local searched = getSearchTarget(playerInv)

    if searched and searched.klshOutfitBusy then return false end

    -- a linked type must resolve to this player's own linked inventory (e.g. 'backpack' without a backpack)
    for i = 1, 2 do
        local invType, inv = i == 1 and swap.fromType or swap.toType, i == 1 and fromInv or toInv

        if invType == data.groundType then
            local attached = shownAttached(playerInv)

            if attached then
                if inv.id ~= attached.id then return false end
            elseif inv.id ~= playerInv.klshGroundId or inv.type ~= 'drop' then
                return false
            end
        elseif invType == 'otherequipment' or invType == 'otherbackpack' then
            local target = getSearchTarget(playerInv)

            if not target or inv.klshLinkedTo ~= target.id then return false end
        elseif Equipment.isLinkedType(invType) and inv.klshLinkedTo ~= playerInv.id then
            return false
        end
    end

    local isLinked = Equipment.isLinked(fromInv) or Equipment.isLinked(toInv)
    local clothingDuration = 0

    if isLinked then
        swap.fromSlot, swap.toSlot = toInteger(swap.fromSlot), toInteger(swap.toSlot)

        if Equipment.isLinked(fromInv) and not isValidSlot(fromInv, swap.fromSlot) then return false end
        if Equipment.isLinked(toInv) and swap.toType ~= 'newdrop' and not isValidSlot(toInv, swap.toSlot) then return false end

        local allowed, reason, duration = validateSwap(playerInv, fromInv, toInv, swap)

        if not allowed then return false, reason end

        clothingDuration = duration or 0
    end

    -- clothing changes have their own time; everything else between inventories is timed by weight
    local duration = clothingDuration > 0 and clothingDuration or getTransferDuration(fromInv, toInv, swap)

    if duration == 0 then
        if isLinked then discountWornBag(playerInv, fromInv, toInv, swap) end

        return true
    end

    -- the vest is about to move: store the armour it has right now
    if fromEquipment and swap.fromSlot == vestSlot or toEquipment and swap.toSlot == vestSlot then
        readVestArmour(getOwner(fromEquipment and fromInv or toInv) or playerInv, true)
    end

    if playerInv.klshChanging then return false end

    playerInv.klshChanging = true

    local fromItem = fromInv.items[swap.fromSlot]
    local openBefore = playerInv.open
    local started = GetGameTimer()
    local finished, clientReason = awaitProgress(playerInv.id, {
        inventory = toEquipment and toInv.id or fromInv.id,
        slot = toEquipment and swap.toSlot or swap.fromSlot,
        duration = duration,
        clothing = clothingDuration > 0,
    })

    playerInv.klshChanging = nil

    if not finished then
        return false, clientReason == 'equipment_blocked' and clientReason or nil
    end

    -- the client cannot shorten the wait
    if GetGameTimer() - started < duration * 0.9 then return false end

    -- everything may have changed while waiting: the player left, closed the inventory, died, was searched...
    if Inventory.GetLoaded(playerInv.id) ~= playerInv or not playerInv.open or playerInv.open ~= openBefore then return false end
    if Inventory.GetLoaded(fromInv.id) ~= fromInv or Inventory.GetLoaded(toInv.id) ~= toInv then return false end
    if fromInv.items[swap.fromSlot] ~= fromItem then return false end

    if isLinked then
        local allowed, reason = validateSwap(playerInv, fromInv, toInv, swap)

        if not allowed then return false, reason end

        discountWornBag(playerInv, fromInv, toInv, swap)
    end

    return true
end

---Runs after a successful swapItems: dresses the ped when the equipment changed.
---@param playerInv OxInventory
---@param fromInv OxInventory
---@param toInv OxInventory
function Equipment.postSwap(playerInv, fromInv, toInv)
    if not Equipment.isLinked(fromInv) and not Equipment.isLinked(toInv) and not playerInv.klshBagId then return end

    -- everyone whose equipment or worn backpack took part: the player and, in a search, the target
    local owners = { [playerInv] = true }

    for i = 1, 2 do
        local inv = i == 1 and fromInv or toInv
        local owner = Equipment.isLinked(inv) and getOwner(inv)

        if owner then owners[owner] = inv.type == data.type and 'equipment' or owners[owner] or true end
    end

    for owner, kind in pairs(owners) do
        -- the bag slot may have changed, or items moved in or out of the worn backpack
        Equipment.refreshBag(owner, true)

        if kind == 'equipment' then
            Equipment.refreshVest(owner)
            Equipment.pushAppearance(owner, true)
        end

        refreshSearchers(owner)
    end
end

-- searches allowed by SearchPlayer: searcher source -> { target, expires }
local searchAllowed = {}

---@param source number
---@param targetId number
---@return boolean allowed true when SearchPlayer opened (or is opening) this search
function Equipment.isSearchAllowed(source, targetId)
    local entry = searchAllowed[source]

    return entry ~= nil and entry.target == targetId and entry.expires >= os.time()
end

---Opens `target`'s inventory, equipment and worn backpack on `source`'s screen. Meant to be called by
---other resources, which decide when a search is allowed; the inventory only checks the distance.
---@param source number player who searches
---@param target number player being searched
---@param options? { notify?: boolean, distance?: number }
---@return boolean success, string? reason
local function searchPlayer(source, target, options)
    if math.type(source) ~= 'integer' or math.type(target) ~= 'integer' or source == target then return false, 'invalid_target' end

    local searcher, searched = Inventory(source), Inventory(target)

    if not searcher or not searcher.player or not searched or not searched.player then return false, 'invalid_target' end
    if searcher.open then return false, 'inventory_open' end

    local ped, targetPed = GetPlayerPed(source), GetPlayerPed(target)

    if ped == 0 or targetPed == 0 then return false, 'invalid_target' end

    local distance = type(options) == 'table' and type(options.distance) == 'number' and options.distance or data.search.distance

    if #(GetEntityCoords(ped) - GetEntityCoords(targetPed)) > distance then return false, 'too_far' end
    if GetPlayerRoutingBucket(source) ~= GetPlayerRoutingBucket(target) then return false, 'too_far' end

    searchAllowed[source] = { target = target, expires = os.time() + 600 }

    local notify = data.search.notify

    if type(options) == 'table' and options.notify ~= nil then notify = options.notify end

    if notify then
        if searched.open then searched:closeInventory() end

        TriggerClientEvent('ox_lib:notify', target, { type = 'inform', description = locale('search_notify') })
    end

    TriggerEvent('ox_inventory:klsh:playerSearched', source, target)
    TriggerClientEvent('ox_inventory:klsh:search', source, target, distance)

    return true
end

exports('SearchPlayer', searchPlayer)

-- for testing and for admins; resources should call the export
lib.addCommand('searchplayer', {
    help = 'Opens the inventory, clothing and backpack of a nearby player',
    params = { { name = 'target', type = 'playerId', help = 'Player id' } },
    restricted = 'group.admin',
}, function(source, args)
    if not source or source == 0 then return end

    local success, reason = searchPlayer(source, args.target)

    if not success then
        TriggerClientEvent('ox_lib:notify', source, { type = 'error', description = ('searchplayer: %s'):format(reason) })
    end
end)

AddEventHandler('playerDropped', function()
    searchAllowed[source] = nil
end)

lib.addCommand('klsh_inventory_remigrate', {
    help = 'Fills the empty equipment slots of a player from the clothing the ped is wearing',
    params = { { name = 'target', type = 'playerId', help = 'Player id' } },
    restricted = 'group.admin',
}, function(source, args)
    local playerInv = Inventory(args.target)

    if not playerInv or not playerInv.player then return end

    -- show the saved appearance again, so the report reflects real clothing and not the "naked" defaults
    TriggerClientEvent('ox_inventory:klsh:reloadAppearance', playerInv.id)
    Wait(4000)

    local migrated = Equipment.ensureMigrated(playerInv, true)

    lib.logger(source, 'klsh_inventory_remigrate', ('remigrated equipment of %s (%s)'):format(playerInv.label, migrated and 'ok' or 'failed'))
end)

-- Deliveries by other resources (shops, rewards): pockets first, then the worn backpack. Nothing is
-- dropped on the ground and nothing goes over the weight limits; what does not fit is left to the caller.

---@param room number free weight
---@param weight number weight of one unit
---@param count number
---@return number units that the free weight allows
local function unitsByWeight(room, weight, count)
    if weight <= 0 then return count end

    return math.max(math.min(count, math.floor(room / weight)), 0)
end

---@param bagItem SlotWithItem the worn backpack
---@param item table
---@return boolean accepted same rules as moving an item into the backpack by hand
local function bagAccepts(bagItem, item)
    if Items.containers[item.name] then return false end

    local container = Items.containers[bagItem.name]

    if not container then return false end

    return not ((container.whitelist and not container.whitelist[item.name]) or (container.blacklist and container.blacklist[item.name]))
end

---Whether a list fits in the pockets plus the worn backpack, placed in order like Equipment.addItem.
---@param playerInv OxInventory grid inventory of a player
---@param entries { item: table, count: number, metadata: table }[]
---@return boolean
function Equipment.canCarryAll(playerInv, entries)
    local Grid = Inventory.Grid
    local bag, bagItem = Equipment.getBag(playerInv)

    if bag and not bag.grid then bag = nil end

    local pockets = Grid.view(playerInv)
    local pack = bag and Grid.view(bag)
    local share = bag and (1 - (data.backpacks[bagItem.name].reduction or 0)) or 1
    local carried, packed = playerInv.weight, bag and bag.weight or 0

    for i = 1, #entries do
        local entry = entries[i]
        local weight = entry.metadata.weight or entry.item.weight or 0
        local placed = Grid.place(pockets, entry.item, unitsByWeight(playerInv.maxWeight - carried, weight, entry.count), entry.metadata)
        local rest = entry.count - placed

        carried += placed * weight

        if rest > 0 then
            if not pack or not bagAccepts(bagItem, entry.item) then return false end
            if unitsByWeight(bag.maxWeight - packed, weight, rest) < rest then return false end
            if unitsByWeight(playerInv.maxWeight - carried, weight * share, rest) < rest then return false end
            if Grid.place(pack, entry.item, rest, entry.metadata) < rest then return false end

            packed += rest * weight
            carried += rest * weight * share
        end
    end

    return true
end

---Adds what fits: pockets first and, with `useBag`, the worn backpack after.
---@param playerInv OxInventory grid inventory of a player
---@param item table
---@param count number
---@param metadata? table
---@param useBag? boolean
---@return number inPockets, number inBackpack
function Equipment.addItem(playerInv, item, count, metadata, useBag)
    local Grid = Inventory.Grid
    local weight = metadata and metadata.weight or item.weight or 0
    local inPockets, inBackpack = 0, 0
    local fit = unitsByWeight(playerInv.maxWeight - playerInv.weight, weight, count)

    if fit > 0 then
        local _, remaining = Grid.planAdd(playerInv, item, fit, metadata)

        fit -= remaining
    end

    if fit > 0 and Grid.addItem(playerInv, item, fit, metadata, nil, false) then
        inPockets = fit
    end

    local rest = count - inPockets

    if rest < 1 or not useBag then return inPockets, inBackpack end

    local bag, bagItem = Equipment.getBag(playerInv)

    if not bag or not bag.grid or not bagAccepts(bagItem, item) then return inPockets, inBackpack end

    local share = 1 - (data.backpacks[bagItem.name].reduction or 0)

    fit = math.min(
        unitsByWeight(bag.maxWeight - bag.weight, weight, rest),
        unitsByWeight(playerInv.maxWeight - playerInv.weight, weight * share, rest)
    )

    if fit > 0 then
        local _, remaining = Grid.planAdd(bag, item, fit, metadata)

        fit -= remaining
    end

    if fit < 1 then return inPockets, inBackpack end

    local success, response = Grid.addItem(bag, item, fit, metadata, nil, false)

    if not success then return inPockets, inBackpack end

    inBackpack = fit

    -- the carried weight only changes here, so the slots go out again with the right weight
    Equipment.recalcBag(playerInv)

    local updates = {}

    if response.slot then
        updates[1] = { item = response, inventory = bag.id }
    else
        for i = 1, #response do updates[i] = { item = response[i], inventory = bag.id } end
    end

    bag:syncSlotsWithClients(updates)
    refreshSearchers(playerInv)

    return inPockets, inBackpack
end

---Gives an item to a player without ever dropping it on the ground: fills the pockets and, with
---`options.backpack`, the worn backpack. Returns how many units went to each; the rest was not added.
---@param source number
---@param item string
---@param count number
---@param metadata? table | string
---@param options? { backpack?: boolean }
---@return number | false inPockets, number | string inBackpack
exports('AddItemToPlayer', function(source, item, count, metadata, options)
    local playerInv = Inventory(source)

    if not playerInv or not playerInv.player then return false, 'invalid_inventory' end

    item = type(item) == 'string' and Items(item) or nil

    if not item then return false, 'invalid_item' end

    count = math.floor(tonumber(count) or 0)

    if count < 1 then return false, 'invalid_count' end
    if type(metadata) ~= 'table' then metadata = metadata and { type = metadata } or nil end

    if not playerInv.grid then
        if not Inventory.CanCarryItem(playerInv, item, count, metadata) then return 0, 0 end

        return Inventory.AddItem(playerInv, item, count, metadata) and count or 0, 0
    end

    local inPockets, inBackpack = Equipment.addItem(playerInv, item, count, metadata, type(options) == 'table' and options.backpack == true)
    local resource = GetInvokingResource()

    if resource and inPockets + inBackpack > 0 then
        lib.logger(playerInv.owner, 'addItem', ('"%s" added %sx %s to "%s" (%s in the backpack)'):format(resource, inPockets + inBackpack, item.name, playerInv.label, inBackpack))
    end

    return inPockets, inBackpack
end)

---@param inv number | string player source or inventory
---@return table<string, SlotWithItem>? equipment items keyed by category name
exports('GetEquipment', function(inv)
    local equipment = Equipment.get(Inventory(inv))

    if not equipment then return end

    local items = {}

    for slot, item in pairs(equipment.items) do
        items[data.categories[slot].name] = item
    end

    return items
end)

-- Outfit bag: a container item that keeps one look. Its inventory has no grid: slot = equipment category.

---@param inv OxInventory?
---@return boolean isOutfit true for the container of an outfit bag
function Equipment.isOutfit(inv)
    return inv ~= nil and inv.type == 'container' and data.isOutfitId(inv.id)
end

---@param itemName string
---@return number? slot category slot of a clothing item; nil for vest, backpacks and anything else
local function outfitSlot(itemName)
    local slot = data.getSlot(itemName)

    return slot ~= vestSlot and slot ~= bagSlot and slot or nil
end

---@param bag OxInventory outfit bag container
---@param piece SlotWithItem piece going in
---@param ignoreSlot number? slot whose piece is leaving in the same move
---@return boolean fits false when the bag already keeps pieces of another ped model
local function outfitModelFits(bag, piece, ignoreSlot)
    local model = piece.metadata and piece.metadata.model

    if not model then return true end

    for slot, other in pairs(bag.items) do
        local otherModel = slot ~= ignoreSlot and other.metadata and other.metadata.model

        if otherModel and otherModel ~= model then return false end
    end

    return true
end

---Rules for swapItems when an outfit bag opened on the right takes part. Also picks the slot of a
---quick move. Called before the timed wait and again right before the upstream body.
---@param playerInv OxInventory
---@param fromInv OxInventory
---@param toInv OxInventory
---@param swap table swapItems payload
---@return boolean allowed, string? reason
function Equipment.outfitSwap(playerInv, fromInv, toInv, swap)
    local fromOutfit, toOutfit = Equipment.isOutfit(fromInv), Equipment.isOutfit(toInv)

    if not fromOutfit and not toOutfit then return true end
    if not data.outfitBag or fromInv == toInv then return false end

    swap.fromSlot, swap.toSlot = toInteger(swap.fromSlot), toInteger(swap.toSlot)

    if fromOutfit and not isValidSlot(fromInv, swap.fromSlot) then return false end
    if toOutfit and swap.toSlot ~= nil and not isValidSlot(toInv, swap.toSlot) then return false end

    local fromData = fromInv.items[swap.fromSlot]

    if not fromData then
        if toOutfit and swap.toSlot == nil then swap.toSlot = 1 end

        return true -- upstream answers with a slot refresh
    end

    if toOutfit then
        local slot = outfitSlot(fromData.name)

        if not slot then return false, 'outfit_only_clothing' end

        if swap.toSlot == nil then
            swap.toSlot = slot
        elseif swap.toSlot ~= slot then
            return false, 'equipment_wrong_slot'
        end

        if not outfitModelFits(toInv, fromData, slot) then return false, 'outfit_wrong_model' end

        swap.count = 1

        -- what goes into the bag is carried by whoever holds it
        local leaving = toInv.items[slot]
        local delta = Inventory.SlotWeight(Items(fromData.name), fromData, true) - (leaving and leaving.weight or 0)

        if fromInv ~= playerInv and delta > 0 and playerInv.weight + delta > playerInv.maxWeight then
            return false, 'cannot_carry'
        end
    else
        -- dropped over another item: that item would take the place in the bag
        local toData = swap.toType ~= 'newdrop' and swap.toSlot and toInv.items[swap.toSlot] or nil

        if toData then
            if outfitSlot(toData.name) ~= swap.fromSlot then return false, 'equipment_wrong_slot' end
            if not outfitModelFits(fromInv, toData, swap.fromSlot) then return false, 'outfit_wrong_model' end
        end
    end

    return true
end

local lastOutfitUse = {}

---Everything that must hold for the swap, checked before and after the wait.
---@param playerInv OxInventory
---@param slot number slot of the bag in the player's inventory
---@return boolean allowed, string? reason, OxInventory? bag, OxInventory? equipment
local function validateOutfitUse(playerInv, slot)
    local bagItem = playerInv.items[slot]

    if not bagItem or bagItem.name ~= data.outfitBag.item or not data.isOutfitId(bagItem.metadata.container) then
        return false
    end

    local ped = GetPlayerPed(playerInv.id)

    if ped == 0 or GetVehiclePedIsIn(ped, false) ~= 0 then return false, 'equipment_blocked' end

    local model = getPlayerModel(playerInv.id)

    if not model then return false, 'equipment_wrong_model' end

    local equipment = Equipment.get(playerInv)

    if not equipment or equipment.klshReconciling or not Equipment.ensureMigrated(playerInv) then return false end

    local bag = Inventory.GetContainerFromSlot(playerInv, slot)

    if not bag or not Equipment.isOutfit(bag) then return false end
    if next(bag.openedBy) or playerInv.containerSlot == slot then return false, 'outfit_bag_open' end

    local pieces, worn, entering = 0, 0, 0

    for bagSlotId, piece in pairs(bag.items) do
        if outfitSlot(piece.name) ~= bagSlotId then return false end
        if piece.metadata.model and piece.metadata.model ~= model then return false, 'outfit_wrong_model' end

        pieces += 1
    end

    for equipSlot, piece in pairs(equipment.items) do
        if equipSlot ~= vestSlot and equipSlot ~= bagSlot then
            worn += 1
            entering += Inventory.SlotWeight(Items(piece.name), piece, true)
        end
    end

    if pieces == 0 and worn == 0 then return false, 'outfit_empty' end

    -- worn clothing weighs nothing; in the bag it does
    local delta = entering - Inventory.CalculateWeight(bag.items)

    if delta > 0 and playerInv.weight + delta > playerInv.maxWeight then return false, 'cannot_carry' end

    return true, nil, bag, equipment
end

---"Use" on an outfit bag: after the wait, everything worn changes places with what is in the bag.
---@param source number
---@param slot number
lib.callback.register('ox_inventory:klsh:useOutfitBag', function(source, slot)
    local playerInv = Inventory(source)

    if not data.outfitBag or not playerInv or not playerInv.player or math.type(slot) ~= 'integer' then return false end

    local now = GetGameTimer()

    if lastOutfitUse[source] and now - lastOutfitUse[source] < 1000 then return false end

    lastOutfitUse[source] = now

    if playerInv.klshChanging or playerInv.klshOutfitBusy then return false, 'cannot_perform' end

    local allowed, reason, bag, equipment = validateOutfitUse(playerInv, slot)

    if not allowed or not bag or not equipment then return false, reason end

    local bagItem = playerInv.items[slot]
    local duration = data.testMode and math.floor(data.outfitBag.duration / 10) or data.outfitBag.duration

    playerInv.klshOutfitBusy = true

    local finished, clientReason = awaitProgress(source, { outfit = true, duration = duration })

    playerInv.klshOutfitBusy = nil

    if not finished then return false, clientReason == 'equipment_blocked' and clientReason or nil end

    -- the client cannot shorten the wait
    if GetGameTimer() - now < duration * 0.9 then return false end

    -- the player may have left, or the bag may have been moved, given or dropped while waiting
    if Inventory.GetLoaded(playerInv.id) ~= playerInv or playerInv.items[slot] ~= bagItem then return false end

    local stillAllowed, lateReason, bagNow, equipmentNow = validateOutfitUse(playerInv, slot)

    if not stillAllowed then return false, lateReason end
    if bagNow ~= bag or equipmentNow ~= equipment then return false end

    -- one step, nothing yields in between: each category changes places
    local equipmentSlots, n = {}, 0

    for categorySlot = 1, data.count do
        if categorySlot ~= vestSlot and categorySlot ~= bagSlot then
            local worn, kept = equipment.items[categorySlot], bag.items[categorySlot]

            if worn or kept then
                equipment.items[categorySlot], bag.items[categorySlot] = kept, worn

                n += 1
                equipmentSlots[n] = { item = kept or { slot = categorySlot }, inventory = equipment.id }
            end
        end
    end

    local content = Inventory.CalculateWeight(bag.items)

    bag.weight = content
    bag.changed = true
    equipment.weight = Inventory.CalculateWeight(equipment.items)
    equipment.changed = true
    bagItem.metadata.weight = content
    bagItem.weight = Items(bagItem.name).weight + content
    playerInv.changed = true

    Equipment.recalcBag(playerInv) -- total weight of the main inventory from scratch

    equipment:syncSlotsWithClients(equipmentSlots, false)
    playerInv:syncSlotsWithPlayer({ { item = bagItem, inventory = playerInv.id } }, playerInv.weight)
    playerInv:syncSlotsWithClients({ { item = bagItem, inventory = playerInv.id } }, false)

    Equipment.pushAppearance(playerInv, true)
    refreshSearchers(playerInv)

    -- a crash must not leave one side new and the other old
    Inventory.Save(bag)
    Inventory.Save(equipment)

    TriggerEvent('ox_inventory:klsh:outfitSwapped', source, slot)

    lib.logger(source, 'outfitBag', ('"%s" swapped outfit with bag %s (%d categories)'):format(playerInv.label, bag.id, n))

    return true
end)

AddEventHandler('playerDropped', function()
    lastOutfitUse[source] = nil
end)

-- Renaming: the new name is stored on the item (metadata.label) and goes wherever the item goes.
local lastRename = {}

---@param source number
---@param slot number
---@param name string? empty restores the item's own name
---@param count number? units of a stack to rename (the rest keeps the old name)
lib.callback.register('ox_inventory:klsh:renameItem', function(source, slot, name, count)
    local playerInv = Inventory(source)

    if not playerInv or not playerInv.player or math.type(slot) ~= 'integer' then return false end

    local now = GetGameTimer()

    if lastRename[source] and now - lastRename[source] < 1000 then return false end

    lastRename[source] = now

    local slotData = playerInv.items[slot]
    local item = slotData and Items(slotData.name)

    if not slotData or not item or item.name == 'money' or item.name == 'black_money' then return false, 'cannot_perform' end
    if type(name) ~= 'string' then name = '' end

    -- plain text: no control characters, no markup, trimmed and limited
    name = name:gsub('%c', ''):gsub('[<>]', ''):gsub('^%s+', ''):gsub('%s+$', '')

    if utf8.len(name) == nil then return false, 'cannot_perform' end

    if utf8.len(name) > data.rename.maxLength then
        name = name:sub(1, utf8.offset(name, data.rename.maxLength + 1) - 1)
    end

    local label = name ~= '' and name ~= item.label and name or nil

    if (slotData.metadata.label or nil) == label then return true end

    local metadata = table.clone(slotData.metadata)
    metadata.label = label

    count = math.type(count) == 'integer' and count > 0 and count < slotData.count and count or nil

    if count then
        -- part of a stack: those units leave it and come back as their own stack
        local original = table.clone(slotData.metadata)

        if not Inventory.RemoveItem(playerInv, item.name, count, nil, slot) then return false, 'cannot_perform' end

        if not Inventory.AddItem(playerInv, item.name, count, metadata) then
            Inventory.AddItem(playerInv, item.name, count, original, nil, nil, true)
            return false, 'grid_no_room'
        end
    else
        Inventory.SetMetadata(playerInv, slot, metadata)
    end

    lib.logger(source, 'klsh_rename', ('%s renamed %s (%s) to "%s"'):format(playerInv.label, item.name, slot, label or item.label))

    return true
end)

-- ---------------------------------------------------------------------------------------------------
-- Clothing coming from the appearance resource (shop, character creation, admin ped menu).
-- The appearance resource saves whatever look the client sends. Here the same event is compared with
-- what the character has equipped: a difference is either paid for in a clothing shop, granted to an
-- admin, or undone.
-- ---------------------------------------------------------------------------------------------------

local shopCoords

---Clothing shop positions: the list in data/equipment.lua, or read from illenium-appearance's config.
local function getShops()
    if shopCoords then return shopCoords end

    shopCoords = {}

    local stores = data.shop.stores

    if type(stores) == 'table' then
        for i = 1, #stores do shopCoords[i] = vec3(stores[i].x, stores[i].y, stores[i].z) end

        return shopCoords
    end

    local file = LoadResourceFile('illenium-appearance', 'shared/config.lua')
    local env = setmetatable({}, { __index = _G })
    local chunk = file and load(file, '@illenium-appearance/shared/config.lua', 't', env)

    if chunk and pcall(chunk) and type(env.Config) == 'table' and type(env.Config.Stores) == 'table' then
        for _, store in pairs(env.Config.Stores) do
            if type(store) == 'table' and store.type == 'clothing' and store.coords then
                shopCoords[#shopCoords + 1] = vec3(store.coords.x, store.coords.y, store.coords.z)
            end
        end
    end

    if #shopCoords == 0 then
        lib.print.warn('no clothing shop positions found: set shop.stores in data/equipment.lua')
    end

    return shopCoords
end

---@param playerId number
---@return boolean inShop
local function isInClothingShop(playerId)
    local ped = GetPlayerPed(playerId)

    if not ped or ped == 0 then return false end

    local coords = GetEntityCoords(ped)
    local shops = getShops()

    for i = 1, #shops do
        if #(coords - shops[i]) <= data.shop.radius then return true end
    end

    return false
end

---@param list any components or props sent by the client
---@param key string 'component_id' | 'prop_id'
---@return table<number, { drawable: number, texture: number }>
local function readPieces(list, key)
    local pieces = {}

    if type(list) ~= 'table' then return pieces end

    for _, entry in pairs(list) do
        local id = type(entry) == 'table' and entry[key]

        if type(id) == 'number' then id = math.tointeger(id) end

        if isIntegerBetween(id, 0, 11) then
            pieces[id] = sanitizePiece(entry, key == 'prop_id')
        end
    end

    return pieces
end

local lastReconcile = {}

---Compares a saved look with the equipped items and settles the difference.
---@param playerId number
---@param appearance any payload of illenium-appearance:server:saveAppearance
local function reconcileAppearance(playerId, appearance)
    local playerInv = Inventory(playerId)

    if not playerInv or not playerInv.player or type(appearance) ~= 'table' then return end

    local inv = Equipment.get(playerInv)

    if not inv then return end

    -- first contact (new character, or one that never opened the inventory): the worn clothing becomes items
    if not inv.klshMigrated then
        Equipment.ensureMigrated(playerInv)
        return
    end

    if inv.klshReconciling then return end

    local model = getPlayerModel(playerId)

    if not model then return end

    local components = readPieces(appearance.components, 'component_id')
    local props = readPieces(appearance.props, 'prop_id')
    local changes, total = {}, 0

    for slot = 1, data.count do
        local category = data.categories[slot]
        local itemName = category.items[1]

        -- the vest and the backpack are items with their own look, and gloves share the arms with the top
        if itemName and slot ~= vestSlot and slot ~= bagSlot and category.name ~= 'gloves' then
            local piece = (category.type == 'prop' and props or components)[category.id]

            if piece then
                local worn = inv.items[slot]
                local naked = isNaked(model, category, piece)
                local same = worn and worn.metadata.drawable == piece.drawable and (worn.metadata.texture or 0) == piece.texture

                -- an equipped item without look data (given by command) shows as naked: nothing to settle
                if worn and worn.metadata.drawable == nil then same = naked end
                if not worn then same = naked end

                if not same then
                    changes[#changes + 1] = { slot = slot, category = category, itemName = itemName, piece = not naked and piece or nil }

                    if not naked then total += category.price or 0 end
                end
            end
        end
    end

    if #changes == 0 then return end

    -- settle one look at a time, and not more often than the shop can be used
    local now = os.time()

    if lastReconcile[playerId] and now - lastReconcile[playerId] < 1 then
        return Equipment.pushAppearance(playerInv, true)
    end

    lastReconcile[playerId] = now

    -- whoever may use the ped menu never pays, in a shop or anywhere else
    local isAdmin = IsPlayerAceAllowed(playerId, 'command.pedmenu')
    local inShop = not isAdmin and isInClothingShop(playerId)

    if not inShop and not isAdmin then
        -- outfits, uniforms or anything else that changes clothing without a purchase
        TriggerClientEvent('ox_lib:notify', playerId, { type = 'error', description = locale('clothing_reverted') })
        return Equipment.pushAppearance(playerInv, true)
    end

    if inShop and total > 0 then
        if Inventory.GetItemCount(playerInv, 'money') < total or not Inventory.RemoveItem(playerInv, 'money', total) then
            TriggerClientEvent('ox_lib:notify', playerId, { type = 'error', description = locale('clothing_no_money', total) })
            return Equipment.pushAppearance(playerInv, true)
        end
    end

    inv.klshReconciling = true

    local arms = components[3]
    local bought = 0

    for i = 1, #changes do
        local change = changes[i]
        local worn = inv.items[change.slot]

        if worn then
            -- the piece that was worn goes to the inventory (to the ground when there is no room)
            local metadata = table.clone(worn.metadata)

            if Inventory.RemoveItem(inv, worn.name, 1, nil, change.slot) then
                Inventory.AddItem(playerInv, worn.name, 1, metadata, nil, nil, true)
            end
        end

        if change.piece and not inv.items[change.slot] then
            local item = Items(change.itemName)

            Inventory.AddItem(inv, change.itemName, 1, {
                model = model,
                drawable = change.piece.drawable,
                texture = change.piece.texture,
                arms = change.category.name == 'top' and arms or nil,
            }, change.slot)

            bought += 1
        end
    end

    inv.klshReconciling = nil
    inv.changed = true

    if inShop then
        TriggerClientEvent('ox_lib:notify', playerId, { type = 'success', description = locale('clothing_bought', bought, total) })
    else
        lib.logger(playerId, 'klsh_clothing_admin', ('%s changed %s clothing pieces through the ped menu'):format(playerInv.label, #changes))
    end

    Equipment.refreshBag(playerInv, true)
    Equipment.pushAppearance(playerInv, true)
    refreshSearchers(playerInv)
end

RegisterNetEvent('illenium-appearance:server:saveAppearance', function(appearance, origin)
    local playerId = source

    if type(playerId) ~= 'number' or playerId < 1 then return end

    -- the fork's own save after an equipment change (modules/appearance/client.lua): nothing to settle.
    -- Skipping it never creates an item, so the flag gives a client nothing.
    if origin == 'klsh' then return end

    reconcileAppearance(playerId, appearance)
end)

AddEventHandler('playerDropped', function()
    lastReconcile[source] = nil
end)

-- personal wardrobes: a stash per character, opened at the configured places
if data.wardrobes and #data.wardrobes.coords > 0 then
    CreateThread(function()
        exports.ox_inventory:RegisterStash('klsh_wardrobe', locale('wardrobe'), data.wardrobes.size, data.wardrobes.maxWeight, true, nil, data.wardrobes.coords)
    end)
end

return Equipment
