-- klsh: client side of the equipment inventory
if not lib then return end

local data = require 'modules.equipment.shared'
local Appearance = require 'modules.appearance.client'

local Equipment = {}

---Adds category labels and accepted items for the NUI.
---@param equipment table? payload from the server (id, type, slots, items)
function Equipment.payload(equipment)
    if not equipment then return end

    local categories = {}

    for slot = 1, data.count do
        local category = data.categories[slot]

        categories[slot] = {
            name = category.name,
            label = locale('equipment_' .. category.name),
            items = category.items,
        }
    end

    equipment.label = locale('equipment')
    equipment.categories = categories

    return equipment
end

---Adds the clothing categories to an outfit bag opened on the right (vest and backpack have no slot).
---@param right table? payload of the right inventory
function Equipment.outfitPayload(right)
    if not right or not right.outfit then return end

    local categories = {}

    for slot = 1, data.count do
        local category = data.categories[slot]
        local hidden = category.name == 'vest' or category.name == 'bag'

        categories[slot] = {
            name = category.name,
            label = locale('equipment_' .. category.name),
            items = hidden and {} or category.items,
            hidden = hidden or nil,
        }
    end

    right.categories = categories
end

---@param item table slot data
---@return boolean
function Equipment.isOutfitBag(item)
    return data.outfitBag and item.name == data.outfitBag.item and data.isOutfitId(item.metadata.container) or false
end

---"Use" on an outfit bag: the server validates, waits for the progress below and swaps the outfit.
---@param slot number
function Equipment.useOutfitBag(slot)
    local success, reason = lib.callback.await('ox_inventory:klsh:useOutfitBag', false, slot)

    if success then
        lib.notify({ type = 'success', description = locale('outfit_swapped') })
    elseif reason then
        lib.notify({ type = 'error', description = locale(reason) })
    end
end

local slotByName = {}

for slot = 1, data.count do
    slotByName[data.categories[slot].name] = slot
end

---@type table<number, { model?: string, drawable?: number, texture?: number, arms?: table } | false>?
local wornState

---Dresses the ped from the state sent by the server. Empty slots get the model's "naked" drawable.
---Pieces without drawable data (items created without metadata) leave the ped untouched.
local function applyState()
    if not wornState then return end

    local ped = cache.ped
    local model = data.getModel(GetEntityModel(ped))

    if not model then return end

    local naked = data.models[model].naked

    for slot = 1, data.count do
        local category = data.categories[slot]
        local piece = wornState[slot]
        -- backpacks carry their drawable per ped model
        if piece and piece.byModel then
            local drawable = piece.byModel[model]

            piece = drawable and { drawable = drawable[1], texture = drawable[2] or 0 } or piece
        end

        local hasData = piece and piece.drawable and (not piece.model or piece.model == model)

        if category.name == 'gloves' then
            -- the arms component: gloves, else the arms saved with the top, else bare arms
            local top = wornState[slotByName.top]
            local arms = hasData and piece or (top and top.arms) or { drawable = naked.gloves or 0, texture = 0 }

            Appearance.setComponent(ped, category.id, arms.drawable, arms.texture or 0)
        elseif category.type == 'prop' then
            if hasData then
                Appearance.setProp(ped, category.id, piece.drawable, piece.texture or 0)
            elseif not piece then
                Appearance.setProp(ped, category.id, -1, 0)
            end
        elseif hasData then
            Appearance.setComponent(ped, category.id, piece.drawable, piece.texture or 0)
        elseif not piece then
            Appearance.setComponent(ped, category.id, naked[category.name] or 0, 0)
        end
    end
end

-- the worn backpack changed while the inventory is open (put on, taken off or replaced)
RegisterNetEvent('ox_inventory:klsh:setBackpack', function(backpack)
    if source == '' then return end

    SendNUIMessage({ action = 'setBackpack', data = backpack or false })
end)

-- the ground section changed (a drop was created or linked) while the inventory is open
RegisterNetEvent('ox_inventory:klsh:setGround', function(ground)
    if source == '' then return end

    client.klshGround = ground and true or nil

    SendNUIMessage({ action = 'setGround', data = ground or false })
end)

-- vest put on (stored armour), taken off (0) or restored after login
RegisterNetEvent('ox_inventory:klsh:setArmour', function(armour)
    if source == '' or type(armour) ~= 'number' then return end

    SetPlayerMaxArmour(cache.playerId, 100)
    SetPedArmour(cache.ped, math.floor(armour))
end)

local persistToken = 0

---Saves the look in the appearance resource a moment after the last change (debounced).
local function persistAppearance()
    persistToken += 1

    local token = persistToken

    SetTimeout(1500, function()
        if token ~= persistToken then return end

        local ped = cache.ped

        if wornState and data.getModel(GetEntityModel(ped)) then
            Appearance.persist(ped)
        end
    end)
end

---@param state table | false worn pieces by slot, or false when the character was not migrated yet
---@param persist? boolean true when the equipment just changed (not on login)
RegisterNetEvent('ox_inventory:klsh:applyEquipment', function(state, persist)
    if source == '' then return end

    wornState = state or nil
    applyState()

    if persist and wornState then
        persistAppearance()
    else
        -- the appearance resource may still be loading the saved skin right after login
        SetTimeout(4000, applyState)
    end
end)

-- the appearance resource swaps the ped (model change) and reloads the saved clothing
lib.onCache('ped', function()
    SetTimeout(1500, applyState)
end)

RegisterNetEvent('illenium-appearance:client:reloadSkin', function()
    SetTimeout(3000, applyState)
end)

local isCancelled = false

RegisterNUICallback('cancelEquip', function(_, cb)
    isCancelled = true
    cb(1)
end)

---@param ped number
---@return boolean blocked true when the ped cannot change clothing right now
local function isBlocked(ped)
    return cache.vehicle ~= false and cache.vehicle ~= nil
        or IsPedInMeleeCombat(ped)
        or IsPedShooting(ped)
        or IsPlayerFreeAiming(cache.playerId)
        or IsPedSwimming(ped)
        or IsPedFalling(ped)
        or IsPedRagdoll(ped)
        or IsPedCuffed(ped)
        or IsEntityDead(ped)
end

---Runs a timed move: progress on the slot, and for clothing the animation and the blocks.
---The server measures the time itself.
---@param payload { inventory: string | number, slot: number, duration: number, clothing: boolean }
---@return boolean finished, string? reason
-- "Rename" in the context menu: asks the name and sends it to the server
RegisterNUICallback('renameItem', function(payload, cb)
    cb(1)

    local slot = type(payload) == 'table' and payload.slot
    local item = slot and PlayerData.inventory[slot]

    if not item then return end

    -- while typing, the keys must not reach the game (movement, keybinds)
    SetNuiFocusKeepInput(false)

    local input = lib.inputDialog(locale('ui_rename'), {
        { type = 'input', label = locale('rename_label'), default = item.metadata and item.metadata.label or item.label, max = data.rename.maxLength },
    })

    -- the dialog takes the NUI focus; give it back to the inventory
    if LocalPlayer.state.invOpen then
        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(true)
    end

    if not input then return end

    local count = type(payload.count) == 'number' and payload.count > 0 and math.floor(payload.count) or nil
    local success, reason = lib.callback.await('ox_inventory:klsh:renameItem', false, slot, input[1] or '', count)

    if not success and reason then
        lib.notify({ type = 'error', description = locale(reason) })
    end
end)

-- personal wardrobes: a stash per character at the configured places
CreateThread(function()
    local wardrobes = data.wardrobes

    if not wardrobes or #wardrobes.coords == 0 then return end

    for i = 1, #wardrobes.coords do
        local point = lib.points.new({ coords = wardrobes.coords[i], distance = 2.0 })

        function point:onEnter()
            lib.showTextUI(('[E] %s'):format(locale('wardrobe')))
        end

        function point:onExit()
            lib.hideTextUI()
        end

        function point:nearby()
            if IsControlJustReleased(0, 38) then
                exports.ox_inventory:openInventory('stash', 'klsh_wardrobe')
            end
        end
    end
end)

-- exports.ox_inventory:SearchPlayer on the server: open the target's inventory on this player's screen
RegisterNetEvent('ox_inventory:klsh:search', function(target, distance)
    if source == '' or type(target) ~= 'number' then return end

    client.klshSearch = { target = target, distance = type(distance) == 'number' and distance or 2.0 }
    client.openInventory('player', target)
end)

-- the searched player's equipment or backpack changed while the search is open
RegisterNetEvent('ox_inventory:klsh:setSearch', function(search)
    if source == '' then return end

    SendNUIMessage({
        action = 'setSearch',
        data = {
            equipment = search and Equipment.payload(search.equipment) or false,
            backpack = search and search.backpack or false,
        },
    })
end)

-- receiving an item from another player
RegisterNetEvent('ox_inventory:klsh:giveAnim', function(duration)
    if source == '' or type(duration) ~= 'number' then return end

    local ped = cache.ped

    if IsEntityDead(ped) or cache.vehicle then return end

    lib.requestAnimDict('mp_common')
    TaskPlayAnim(ped, 'mp_common', 'givetake1_a', 3.0, 3.0, math.min(duration, 3000), 49, 0.0, false, false, false)
    RemoveAnimDict('mp_common')
end)

---@type { inventory: string | number, slot: number, finishAt: number }?
local running

lib.callback.register('ox_inventory:klsh:equipProgress', function(payload)
    local ped = cache.ped
    local isClothing = payload.clothing

    if (isClothing or payload.outfit) and isBlocked(ped) then return false, 'equipment_blocked' end

    -- outfit bag: runs with the inventory closed, with ox_lib's own progress and cancel key
    if payload.outfit then
        return lib.progressCircle({
            duration = payload.duration,
            label = locale('outfit_progress'),
            position = 'bottom',
            useWhileDead = false,
            canCancel = true,
            disable = { car = true, combat = true },
            anim = { dict = data.anim.dict, clip = data.anim.clip, flag = 49 },
        })
    end

    isCancelled = false

    SendNUIMessage({
        action = 'transferProgress',
        data = { inventory = payload.inventory, slot = payload.slot, duration = payload.duration },
    })

    running = { inventory = payload.inventory, slot = payload.slot, finishAt = GetGameTimer() + payload.duration }

    -- handing an item over: its own animation, and it does not depend on the inventory being open
    local isGive = payload.give
    local anim = isClothing and data.anim or isGive and { dict = 'mp_common', clip = 'givetake1_a' }

    if anim then
        lib.requestAnimDict(anim.dict)
        TaskPlayAnim(ped, anim.dict, anim.clip, 3.0, 3.0, -1, 49, 0.0, false, false, false)
    end

    local finishAt = GetGameTimer() + payload.duration
    local finished = true

    while GetGameTimer() < finishAt do
        Wait(50)

        ped = cache.ped

        if isCancelled or (not isGive and not LocalPlayer.state.invOpen) or (isClothing and isBlocked(ped)) or (isGive and IsEntityDead(ped)) then
            finished = false
            break
        end
    end

    if anim then
        StopAnimTask(ped, anim.dict, anim.clip, 3.0)
        RemoveAnimDict(anim.dict)
    end

    running = nil

    SendNUIMessage({ action = 'transferProgress', data = {} })

    return finished
end)

-- the screen was hidden by the inventory key and is back: show again what is still running
AddEventHandler('ox_inventory:klsh:inventoryShown', function()
    SetTimeout(150, function()
        local remaining = running and running.finishAt - GetGameTimer()

        if remaining and remaining > 0 then
            SendNUIMessage({
                action = 'transferProgress',
                data = { inventory = running.inventory, slot = running.slot, duration = remaining },
            })
        end
    end)
end)

---Admin remigration: forget the worn state and show the saved appearance again before reporting.
RegisterNetEvent('ox_inventory:klsh:reloadAppearance', function()
    if source == '' then return end

    wornState = nil
    Appearance.reloadSaved()
end)

---One-time report of what the ped wears, used by the server to create the first clothing items.
lib.callback.register('ox_inventory:klsh:reportWorn', function()
    local ped = cache.ped
    local components, props = {}, {}

    for slot = 1, data.count do
        local category = data.categories[slot]

        if category.type == 'prop' then
            props[category.id] = Appearance.getProp(ped, category.id)
        else
            components[category.id] = Appearance.getComponent(ped, category.id)
        end
    end

    return { components = components, props = props }
end)

return Equipment
