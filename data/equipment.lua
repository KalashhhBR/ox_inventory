-- klsh: equipment slots (clothing as items). The order below is the slot number of the
-- player's linked 'equipment' inventory. Do not reorder once players have equipped items.
--   type/id  : GTA ped component ('component') or prop ('prop') id
--   duration : time in ms to put the piece on or take it off
--   price    : what the piece costs in a clothing shop (categories without price are not sold)
--   items    : item names accepted by the slot
return {
    -- weight cap of the equipment inventory (worn clothing never counts on the main inventory)
    maxWeight = 1000000,

    -- divides every duration by 10 while testing; must be false on release
    testMode = false,

    -- time to move items between two different inventories (stash, trunk, ground, backpack, another
    -- player), from the weight moved. Rearranging inside one inventory and shops are never timed.
    --   minWeight : grams; lighter moves are instant
    --   msPerKg   : time per kilogram
    --   max       : cap in ms
    --   giveMin   : shortest time, in ms, to hand an item to another player ("Give"); same weight rule
    -- Set `transfer = false` to disable.
    transfer = { minWeight = 500, msPerKg = 200, max = 3000, giveMin = 1000 },

    -- the inventory key only hides the screen while moves are running; with a stash, trunk, drop or search
    -- open, walking this far (metres) from where it was hidden closes the inventory and cancels the rest
    hideDistance = 2.0,

    -- outfit bag: an item that keeps one whole look (one slot per clothing category; vest and backpack
    -- stay out). "Use" swaps everything worn with what is in the bag; "Open" shows its slots.
    --   item     : item name (also in data/items.lua; sold like any item in data/shops.lua)
    --   duration : ms the swap takes
    -- Set `outfitBag = false` to disable.
    outfitBag = { item = 'outfit_bag', duration = 8000 },

    -- renaming items (context menu): longest name allowed
    rename = { maxLength = 30 },

    -- clothing shop: the look is chosen in the appearance resource; every piece that changes is paid here
    -- (price per category, in `categories`) and becomes an item. Changes made anywhere else are undone,
    -- except for admins using the ped menu.
    --   stores : 'illenium' reads the clothing stores from illenium-appearance's config, or a list of vec3
    --   radius : meters from a store where a purchase is accepted
    shop = { stores = 'illenium', radius = 12.0 },

    -- personal wardrobes: one stash per character, opened with E at these places (none by default)
    --   coords : list of vec3
    wardrobes = { coords = {}, size = { 8, 6 }, maxWeight = 100000 },

    -- searching another player: exports.ox_inventory:SearchPlayer(source, target, { notify?, distance? })
    --   distance : meters between the two, checked when the search opens and while it is open
    --   notify   : tell the target (and close their inventory) when a search starts; a caller can turn
    --              it off for one search with { notify = false }
    search = { distance = 2.0, notify = true },

    -- with a secondary inventory open (stash, trunk, container, another player), the ground is also
    -- shown: the nearest drop within `groundDistance` meters, or an empty area that creates a new drop.
    -- Set to false to disable.
    groundDistance = 2.0,

    -- animation played while changing a piece (the progress is shown on the slot)
    anim = { dict = 'clothingshirt', clip = 'try_shirt_positive_d' },

    -- how clothing is applied to the ped: 'auto' | 'illenium' | 'natives' | 'none'
    appearance = 'auto',

    -- ped models that can wear clothing items, with the drawable shown when a slot is empty.
    -- Components not listed default to drawable 0; props are cleared.
    models = {
        mp_m_freemode_01 = {
            naked = { top = 15, undershirt = 15, gloves = 15, pants = 61, shoes = 34 },
        },
        mp_f_freemode_01 = {
            naked = { top = 15, undershirt = 15, gloves = 15, pants = 15, shoes = 35 },
        },
    },

    -- vest: the item worn in the 'vest' slot keeps its remaining armour (0-100) in metadata.armour.
    --   drawable     : body armour component { drawable, texture } per ped model, used when the item
    --                  has no drawable of its own (e.g. given by a shop or command)
    --   pollInterval : ms between server readings of the ped armour (only for players wearing a vest)
    vest = {
        drawable = { mp_m_freemode_01 = { 12, 0 }, mp_f_freemode_01 = { 13, 0 } },
        pollInterval = 2000,
    },

    -- backpacks: container items worn in the 'bag' slot. While worn, the content shows as an extra
    -- section of the inventory and weighs less on the main inventory.
    --   grid              : { width, height } in cells (used when the grid is on, see data/grid.lua)
    --   slots             : capacity in slots, only used with the grid off
    --   maxWeight         : weight the backpack holds (grams)
    --   reduction         : 0.0 to 1.0, share of the content weight that is NOT carried (0.5 = half)
    --   drawable          : bag component { drawable, texture } per ped model
    --   whitelist / blacklist (optional): arrays of item names
    backpacks = {
        backpack_small = {
            slots = 8, grid = { 4, 4 }, maxWeight = 8000, reduction = 0.0,
            drawable = { mp_m_freemode_01 = { 44, 0 }, mp_f_freemode_01 = { 44, 0 } },
        },
        backpack_medium = {
            slots = 15, grid = { 6, 5 }, maxWeight = 20000, reduction = 0.3,
            drawable = { mp_m_freemode_01 = { 45, 0 }, mp_f_freemode_01 = { 45, 0 } },
        },
        backpack_large = {
            slots = 25, grid = { 8, 6 }, maxWeight = 35000, reduction = 0.5,
            drawable = { mp_m_freemode_01 = { 82, 0 }, mp_f_freemode_01 = { 82, 0 } },
        },
    },

    categories = {
        { name = 'hat',        type = 'prop',      id = 0,  duration = 1500, price = 60, items = { 'clothing_hat' } },
        { name = 'mask',       type = 'component', id = 1,  duration = 2000, price = 80, items = { 'clothing_mask' } },
        { name = 'glasses',    type = 'prop',      id = 1,  duration = 1000, price = 50, items = { 'clothing_glasses' } },
        { name = 'ears',       type = 'prop',      id = 2,  duration = 1500, price = 40, items = { 'clothing_ears' } },
        { name = 'neck',       type = 'component', id = 7,  duration = 1500, price = 60, items = { 'clothing_neck' } },
        { name = 'top',        type = 'component', id = 11, duration = 4000, price = 150, items = { 'clothing_top' } },
        { name = 'undershirt', type = 'component', id = 8,  duration = 3500, price = 80, items = { 'clothing_undershirt' } },
        { name = 'gloves',     type = 'component', id = 3,  duration = 2000, items = { 'clothing_gloves' } },
        { name = 'vest',       type = 'component', id = 9,  duration = 5000, items = { 'armour' } },
        { name = 'bag',        type = 'component', id = 5,  duration = 2500, items = {} }, -- filled from `backpacks`
        { name = 'pants',      type = 'component', id = 4,  duration = 4500, price = 120, items = { 'clothing_pants' } },
        { name = 'shoes',      type = 'component', id = 6,  duration = 3500, price = 100, items = { 'clothing_shoes' } },
        { name = 'watch',      type = 'prop',      id = 6,  duration = 1500, price = 90, items = { 'clothing_watch' } },
        { name = 'bracelet',   type = 'prop',      id = 7,  duration = 1500, price = 50, items = { 'clothing_bracelet' } },
    },
}
