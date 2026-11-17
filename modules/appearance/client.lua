-- klsh: appearance adapter. Reads and applies clothing pieces on the local ped.
-- Providers: 'illenium' (illenium-appearance exports), 'natives' (game natives), 'none'.
if not lib then return end

local data = require 'modules.equipment.shared'

local providers = {}

providers.natives = {
    ---@return { drawable: number, texture: number }
    getComponent = function(ped, id)
        return { drawable = GetPedDrawableVariation(ped, id), texture = GetPedTextureVariation(ped, id) }
    end,
    getProp = function(ped, id)
        return { drawable = GetPedPropIndex(ped, id), texture = GetPedPropTextureIndex(ped, id) }
    end,
    setComponent = function(ped, id, drawable, texture)
        SetPedComponentVariation(ped, id, drawable, texture, 0)
    end,
    setProp = function(ped, id, drawable, texture)
        if drawable < 0 then
            ClearPedProp(ped, id)
        else
            SetPedPropIndex(ped, id, drawable, texture, false)
        end
    end,
}

-- illenium-appearance v5.7.0 (game/util.lua): setPedComponent(ped, { component_id, drawable, texture }),
-- setPedProp(ped, { prop_id, drawable, texture }) with drawable -1 clearing the prop
providers.illenium = {
    getComponent = providers.natives.getComponent,
    getProp = providers.natives.getProp,
    setComponent = function(ped, id, drawable, texture)
        exports['illenium-appearance']:setPedComponent(ped, { component_id = id, drawable = drawable, texture = texture })
    end,
    setProp = function(ped, id, drawable, texture)
        exports['illenium-appearance']:setPedProp(ped, { prop_id = id, drawable = drawable, texture = texture })
    end,
    -- reloads the saved appearance (client event of illenium-appearance; `true` bypasses its cooldown)
    reloadSaved = function()
        TriggerEvent('illenium-appearance:client:reloadSkin', true)
    end,
    -- stores the current look as the saved appearance, so login and character selection show what is
    -- equipped (same event illenium-appearance fires when its own menu is confirmed)
    persist = function(ped)
        -- the second argument tells the fork's own listener that this save only mirrors the equipment
        TriggerServerEvent('illenium-appearance:server:saveAppearance', exports['illenium-appearance']:getPedAppearance(ped), 'klsh')
    end,
}

providers.none = {
    getComponent = function() end,
    getProp = function() end,
    setComponent = function() end,
    setProp = function() end,
}

providers.natives.reloadSaved = function() end
providers.none.reloadSaved = function() end
providers.natives.persist = function() end
providers.none.persist = function() end

local detectionOrder = { { resource = 'illenium-appearance', provider = 'illenium' } }

local function detect()
    if data.appearance ~= 'auto' then return data.appearance end

    for i = 1, #detectionOrder do
        if GetResourceState(detectionOrder[i].resource) == 'started' then
            return detectionOrder[i].provider
        end
    end

    return 'natives'
end

return providers[detect()] or providers.natives
