-- klsh: throwing items (client): aim with the item in hand, hold to charge, release to throw.
-- Nothing leaves the inventory until the server accepts the landing point.
if not lib then return end

local Throw = require 'modules.throw.shared'
local Items = require 'modules.items.client'
local Inventory = require 'modules.inventory.client'
local config = Throw.config

---@type { getWeapon: fun(): table?, disarm: fun(), useSlot: fun(slot: number), isBusy: fun(): boolean, setBusy: fun(busy: boolean), closeInventory: fun() }
local ctx
local active = false
local lastThrow = 0

---@param context table functions of client.lua the throw needs (weapon in hand, busy state)
function Throw.init(context)
    ctx = context
end

local function notify(key, kind)
    lib.notify({ id = key, type = kind or 'error', description = locale(key) })
end

---Side of the vehicle the player may throw to, from any seat: there must be an opening next to the
---seat (window rolled down or broken, door open, door missing, or a vehicle without that door).
---@return number? side -1 for the left, 1 for the right, 0 for any direction (no doors: bike, buggy);
---nil when there is no opening
local function getWindowSide()
    local vehicle = cache.vehicle

    if not vehicle or not config.fromVehicle then return end

    local seat = cache.seat

    if type(seat) ~= 'number' then return end

    -- bikes, bicycles and quads have no doors or windows at all: any direction
    local model = GetEntityModel(vehicle)

    if IsThisModelABike(model) or IsThisModelABicycle(model) or IsThisModelAQuadbike(model) then return 0 end

    -- seats: -1 driver, 0 front right, 1 rear left, 2 rear right, ... (odd on the left)
    local onLeft = seat == -1 or seat % 2 == 1
    local side = onLeft and -1 or 1
    local index = seat + 1 -- door and window next to the seat: 0 and 1 in front, 2 and 3 behind

    -- seats further back have no door or window of their own: only open vehicles (no doors at all)
    if index > 3 then
        return not GetIsDoorValid(vehicle, onLeft and 2 or 3) and 0 or nil
    end

    if not GetIsDoorValid(vehicle, index) then return 0 end              -- no door there (bike, buggy): free
    if IsVehicleDoorDamaged(vehicle, index) then return side end         -- door torn off
    if GetVehicleDoorAngleRatio(vehicle, index) > 0.1 then return side end -- door open
    if not IsVehicleWindowIntact(vehicle, index) then return side end    -- window rolled down or broken
end

---@param ped number
---@return boolean blocked states in which nothing can be thrown
local function isBlocked(ped)
    return (cache.vehicle ~= false and cache.vehicle ~= nil and not getWindowSide())
        or IsPedSwimming(ped)
        or IsPedFalling(ped)
        or IsPedRagdoll(ped)
        or IsPedCuffed(ped)
        or IsEntityDead(ped)
end

---What the item landed next to: a dumpster, or the open trunk of a vehicle.
---@param coords vector3
---@return { type: string, netid: number }? target, string? hint locale key when a trunk was there but closed
local function findTarget(coords)
    local targets = config.targets

    if not targets then return end

    local vehicle = lib.getClosestVehicle(coords, targets.trunkRadius, true)


    local door, opening

    if vehicle then door, opening = Inventory.GetTrunk(vehicle) end

    local hint

    -- the trunk comes first: a dumpster a few metres away must not take a throw aimed at the trunk.
    -- Measured on the ground plane: the trunk floor is higher or lower than the reference point
    if door and opening and #vec2(opening.x - coords.x, opening.y - coords.y) <= targets.targetRadius and math.abs(opening.z - coords.z) <= 3.0 then
        local doors = type(door) == 'table' and door or { door }

        for i = 1, #doors do
            -- open, or torn off
            if GetVehicleDoorAngleRatio(vehicle, doors[i]) > 0.1 or IsVehicleDoorDamaged(vehicle, doors[i]) then
                return { type = 'trunk', netid = NetworkGetNetworkIdFromEntity(vehicle) }
            end
        end

        hint = 'throw_trunk_closed'
    end


    if not shared.networkdumpsters then
        for i = 1, #Inventory.Dumpsters do
            local object = GetClosestObjectOfType(coords.x, coords.y, coords.z, targets.targetRadius, Inventory.Dumpsters[i], false, false, false)

            if object ~= 0 then
                local netId = Inventory.GetDumpsterNetId(object)

                -- only a dumpster the server can find (a networked object) counts
                if netId and netId ~= 0 and NetworkDoesEntityExistWithNetworkId(netId) then
                    return { type = 'dumpster', netid = netId }
                end
            end
        end
    end

    return nil, hint
end

---@param item table slot data
---@param data table item definition
---@return number model object shown in hand and in the air
local function getModel(item, data)
    if data.weapon and data.hash then
        local model = GetWeapontypeModel(data.hash)

        if model ~= 0 and IsModelValid(model) then return model end
    end

    local prop = data.prop or data.client and data.client.prop

    if type(prop) == 'table' then prop = prop.model or prop[1] and prop[1].model end
    if type(prop) == 'string' then prop = joaat(prop) end

    if type(prop) == 'number' and IsModelValid(prop) then return prop end

    return config.prop
end

---@return vector3 direction the gameplay camera looks at, raised a little
local function getDirection()
    local rot = GetGameplayCamRot(2)
    local pitch = math.rad(math.min(rot.x + 15.0, 80.0))
    local yaw = math.rad(rot.z)

    return vec3(-math.sin(yaw) * math.cos(pitch), math.cos(yaw) * math.cos(pitch), math.sin(pitch))
end

---Follows the thrown object until it hits something, stops or runs out of time.
---@param object number
---@return vector3 coords
local function followFlight(object)
    local finishAt = GetGameTimer() + config.maxFlight
    local startedAt = GetGameTimer()

    while GetGameTimer() < finishAt and DoesEntityExist(object) do
        Wait(0)

        local elapsed = GetGameTimer() - startedAt

        -- the first moments are ignored: the object is still leaving the hand
        if elapsed > 150 and (HasEntityCollidedWithAnything(object) or #GetEntityVelocity(object) < 0.3) then break end
    end

    return GetEntityCoords(object)
end

---@param slot number slot of the item in the player's inventory
---@param count? number units to throw (the whole stack when nil or 0)
function Throw.start(slot, count)
    if not config.enabled or active or not ctx then return end

    local item = PlayerData.inventory[slot]
    local data = item and Items[item.name]

    if not item or not data then return end

    local ped = cache.ped

    if cache.vehicle and not getWindowSide() then return notify('throw_window') end
    if isBlocked(ped) or lib.progressActive() then return notify('throw_busy') end

    count = math.floor(tonumber(count) or 0)

    if count < 1 or count > item.count then count = item.count end

    if (item.weight / item.count) * count > config.maxWeight then return notify('throw_too_heavy') end
    if GetGameTimer() - lastThrow < config.cooldown then return notify('throw_cooldown') end

    ctx.closeInventory()

    if ctx.isBusy() then return notify('throw_busy') end

    local weapon = ctx.getWeapon()
    local equipped = weapon ~= nil and weapon.slot == slot

    -- a shot that was not reported yet would leave with the old ammo count
    if equipped and (weapon.timer or 0) ~= 0 then return notify('throw_busy') end

    active = true

    if equipped then
        ctx.disarm() -- reports the ammo and takes the weapon out of the hand, without animation
        Wait(100)
    end

    ctx.setBusy(true)

    local model = getModel(item, data)

    lib.requestModel(model)

    local coords = GetEntityCoords(ped)
    local object = CreateObject(model, coords.x, coords.y, coords.z + 0.2, false, false, false)

    SetModelAsNoLongerNeeded(model)
    SetEntityCollision(object, false, false)
    AttachEntityToEntity(object, ped, GetPedBoneIndex(ped, 57005), 0.12, 0.03, -0.03, -80.0, 0.0, 0.0, true, true, false, true, 1, true)

    lib.showTextUI(locale('throw_help'))

    local playerId = cache.playerId
    local chargeStart
    local released = false

    while true do
        Wait(0)

        ped = cache.ped

        DisablePlayerFiring(playerId, true)
        DisableControlAction(0, 24, true)  -- attack
        DisableControlAction(0, 25, true)  -- aim
        DisableControlAction(0, 140, true) -- melee
        DisableControlAction(0, 141, true)
        DisableControlAction(0, 142, true)
        DisableControlAction(0, 257, true) -- attack 2
        DisableControlAction(0, 37, true)  -- weapon wheel
        DisableControlAction(0, 69, true)  -- vehicle attack
        DisableControlAction(0, 70, true)
        DisableControlAction(0, 92, true)

        if isBlocked(ped) or IsDisabledControlJustPressed(0, 25) or IsControlJustPressed(0, 177) then break end

        if not chargeStart and IsDisabledControlJustPressed(0, 24) then
            chargeStart = GetGameTimer()
            SendNUIMessage({ action = 'throwCharge', data = { duration = config.chargeTime } })
        elseif chargeStart and not IsDisabledControlPressed(0, 24) then
            released = true
            break
        end
    end

    lib.hideTextUI()
    SendNUIMessage({ action = 'throwCharge', data = false })

    local function finish(reequip)
        if DoesEntityExist(object) then DeleteEntity(object) end

        ctx.setBusy(false)
        active = false

        -- the busy state reaches the rest of the client a moment later
        if reequip and equipped then SetTimeout(250, function() ctx.useSlot(slot) end) end
    end

    if not released then return finish(true) end

    local charge = math.min((GetGameTimer() - chargeStart) / config.chargeTime, 1.0)
    local allowed, reason = lib.callback.await('ox_inventory:klsh:throwStart', false, slot, count)

    if not allowed then
        if reason then notify(reason) end

        return finish(true)
    end

    lastThrow = GetGameTimer()

    local anim = config.anim
    local side = cache.vehicle and getWindowSide()
    local origin = GetEntityCoords(ped) -- the server measures the range from where the player is now

    if cache.vehicle and not side then
        -- the window was closed in the meantime: the server entry just expires
        notify('throw_window')

        return finish(true)
    end

    if anim and not cache.vehicle then
        lib.requestAnimDict(anim.dict)
        TaskPlayAnim(ped, anim.dict, anim.clip, 8.0, -8.0, 900, 48, 0.0, false, false, false)
        RemoveAnimDict(anim.dict)
        Wait(250)
    end

    -- reach at full force for this weight, scaled by the charge; speed for that reach at 45 degrees
    local weight = (item.weight / item.count) * count
    local reach = Throw.range(weight) * (config.minCharge + (1.0 - config.minCharge) * charge)
    local speed = math.sqrt(reach * 9.81)
    local direction = getDirection()

    DetachEntity(object, true, true)

    if side == 0 then
        -- no doors (bike, buggy): any direction, starting a little ahead of the player
        local start = GetEntityCoords(ped) + vec3(direction.x * 0.8, direction.y * 0.8, 0.5)

        SetEntityCoordsNoOffset(object, start.x, start.y, start.z, false, false, false)
    elseif side then
        -- out of the window: the object starts just outside, and only goes towards that side
        local vehicle = cache.vehicle
        local _, rightVector = GetEntityMatrix(vehicle)
        local outward = rightVector * side

        if direction.x * outward.x + direction.y * outward.y < 0.2 then
            direction = norm(vec3(outward.x, outward.y, 0.35))
        end

        local start = GetEntityCoords(ped) + outward * 1.1 + vec3(0.0, 0.0, 0.35)

        SetEntityCoordsNoOffset(object, start.x, start.y, start.z, false, false, false)
    end

    SetEntityCollision(object, true, true)
    SetEntityRecordsCollisions(object, true)
    SetEntityVelocity(object, direction.x * speed, direction.y * speed, direction.z * speed)

    local landed = followFlight(object)
    local offset = landed - origin
    local flat = #vec2(offset.x, offset.y)
    local limit = Throw.range(weight)

    -- an object that rolled past the reach is taken as landed at the edge of it
    if flat > limit then
        landed = vec3(origin.x + offset.x / flat * limit, origin.y + offset.y / flat * limit, landed.z)
    end

    local target, hint = findTarget(landed)
    local result = lib.callback.await('ox_inventory:klsh:throwLand', false, landed, target)

    if result == 'ground' and hint then
        notify(hint, 'inform')
    elseif result == 'locked' then
        notify('throw_trunk_locked', 'inform')
    elseif result == 'refused' then
        notify('throw_target_refused', 'inform')
    elseif result == 'target' then
        notify('throw_in', 'success')
    elseif result == 'missed' then
        notify('throw_missed', 'inform')
    elseif result == 'full' then
        notify('throw_full', 'inform')
    elseif not result then
        notify('throw_failed')
    end

    finish(false)
end

---Throws what is equipped in hand (weapons today). Thrown weapons of the game (grenades) keep their own use.
function Throw.inHand()
    if not ctx then return end

    local weapon = ctx.getWeapon()

    if not weapon or weapon.throwable then return end

    Throw.start(weapon.slot)
end

return Throw
