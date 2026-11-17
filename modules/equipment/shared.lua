-- klsh: shared equipment data (categories and item -> slot lookup)
local data = lib.load('data.equipment')
local categories = data.categories
local slotByItem = {}

local backpackNames = {}

for name in pairs(data.backpacks or {}) do
    backpackNames[#backpackNames + 1] = name
end

table.sort(backpackNames)

for slot = 1, #categories do
    local category = categories[slot]
    category.slot = slot

    if category.name == 'bag' then
        category.items = backpackNames
    end

    for i = 1, #category.items do
        slotByItem[category.items[i]] = slot
    end
end

local modelByHash = {}

for name in pairs(data.models) do
    modelByHash[joaat(name) & 0xFFFFFFFF] = name
end

return {
    models = data.models,
    appearance = data.appearance,
    backpacks = data.backpacks or {},
    search = data.search or { distance = 2.0, notify = true },
    rename = data.rename or { maxLength = 30 },
    outfitBag = data.outfitBag or false,

    ---@param id any inventory id
    ---@return boolean isOutfit true for the container of an outfit bag (ids start with 'outfit-')
    isOutfitId = function(id)
        return type(id) == 'string' and id:sub(1, 7) == 'outfit-'
    end,

    shop = data.shop or { stores = 'illenium', radius = 12.0 },
    wardrobes = data.wardrobes or { coords = {}, size = { 8, 6 }, maxWeight = 100000 },
    backpackType = 'backpack',

    anim = data.anim,
    transfer = data.transfer,
    groundDistance = data.groundDistance,
    vest = data.vest,
    groundType = 'ground',

    ---@param slot number equipment slot
    ---@return number ms time to put on or take off the piece of that slot
    getDuration = function(slot)
        local duration = categories[slot] and categories[slot].duration or 0

        return data.testMode and math.floor(duration / 10) or duration
    end,

    ---@param hash number ped model hash (signed or unsigned)
    ---@return string? name configured model name
    getModel = function(hash)
        return hash and modelByHash[hash & 0xFFFFFFFF]
    end,

    ---@param name string category name
    ---@return number? slot equipment slot of that category
    getSlotByName = function(name)
        for slot = 1, #categories do
            if categories[slot].name == name then return slot end
        end
    end,

    ---@return number? slot equipment slot of the backpack
    getBagSlot = function()
        for slot = 1, #categories do
            if categories[slot].name == 'bag' then return slot end
        end
    end,

    type = 'equipment',
    categories = categories,
    count = #categories,
    maxWeight = data.maxWeight,

    ---@param itemName string
    ---@return number? slot equipment slot that accepts the item
    getSlot = function(itemName)
        return slotByItem[itemName]
    end,
}
