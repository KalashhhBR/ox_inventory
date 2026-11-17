-- klsh: grid inventory settings (plan section 11).
-- Per item settings live with the item itself, in data/items.lua and data/weapons.lua:
--   size = { width, height }   cells the item takes (items rotate freely); default 1 x 1
--   maxStack = 60              most units in one stack; false = no limit; default below
return {
    -- master switch. Off: the fork behaves exactly as before the grid (slots), positions are kept
    enabled = true,

    -- true: every item counts as 1 x 1 (sizes ignored)
    forceUnit = false,

    -- player inventory, replaces the `inventory:slots` convar
    player = { w = 8, h = 5 },

    -- drops no longer inherit `inventory:slots`
    --   merge : an item dropped (or thrown) within this many metres of a drop that has room for it goes
    --           into that drop instead of creating another one (false = always a new drop)
    drop = { w = 8, h = 5, merge = 1.5 },

    -- Sizes that live next to what they belong to (see CONFIG.md):
    --   backpacks       data/equipment.lua  -> backpacks.<item>.grid
    --   trunk, glovebox data/vehicles.lua   -> { { width, height }, maxWeight } per class or model
    --   stashes         data/stashes.lua or RegisterStash -> slots = { width, height }
    --   items           data/items.lua, data/weapons.lua -> size, maxStack

    -- inventories that only give a number of slots: the grid is `width` wide and ceil(slots / width)
    -- tall, never below the minimum height of its type
    width = 10,
    minHeight = { stash = 4, trunk = 4, glovebox = 2, dumpster = 3, container = 1, policeevidence = 5, temp = 4, default = 3 },

    -- exceptions by inventory type or name: ['type'] or ['name'] = { w = 10, h = 6 }
    overrides = {},

    -- account items kept in the player's wallet slots, outside the grid (always fit, never dropped)
    wallet = { 'money', 'black_money' },

    -- delivered without room: goes to a public ground drop that lasts this long (seconds)
    overflowTime = 900,

    -- never go to the ground for lack of room: the delivery fails and the player is warned
    neverDrop = { 'id_card', 'driver_license', 'weaponlicense', 'lawyerpass', 'security_card_01', 'security_card_02' },

    -- items without `size` / `maxStack` in data/items.lua or data/weapons.lua
    defaultSize = { 1, 1 },
    defaultStack = 20,
}
