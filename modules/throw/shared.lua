-- klsh: shared throw rules (the same numbers on both sides)
local config = lib.load('data.throw')

local Throw = { config = config }

-- models that are dumpsters: the same list as Inventory.Dumpsters in modules/inventory/client.lua
-- (the server needs it to check a target)
local dumpsters = {}

for _, model in ipairs({ 218085040, 666561306, -58485588, -206690185, 1511880420, 682791951 }) do
    dumpsters[model & 0xFFFFFFFF] = true
end

---@param model number model hash, signed or unsigned
---@return boolean
function Throw.isDumpster(model)
    return dumpsters[model & 0xFFFFFFFF] == true
end

---@param weight number grams being thrown
---@return number metres reached at full force
function Throw.range(weight)
    local range = config.range
    local share = math.min(math.max(weight / config.maxWeight, 0), 1)

    return range.light + (range.heavy - range.light) * share
end

return Throw
