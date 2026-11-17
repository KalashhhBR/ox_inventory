-- klsh: throwing items (context menu "Throw", or the key below for what is in hand).
-- The thrown item becomes a drop where it lands. See CONFIG.md.
return {
    enabled = true,

    -- default key to throw what is equipped in hand (weapons today); each player can rebind it in the
    -- FiveM key settings. Set to false for no default key.
    key = 'G',

    maxWeight = 5000,   -- grams; a heavier item (or stack) cannot be thrown
    cooldown = 1500,    -- ms between throws
    chargeTime = 1200,  -- ms holding the button to reach full force
    minCharge = 0.25,   -- share of the range of a quick tap
    maxFlight = 3000,   -- ms the thrown object is followed before it is taken as landed
    maxDrop = 15.0,     -- metres; largest height difference between the player and where it landed

    -- metres reached at full force: by an item that weighs nothing, and by one at maxWeight
    -- (in between it is linear)
    range = { light = 18.0, heavy = 6.0 },

    -- Targets: an item that lands next to a dumpster or to an open trunk may go straight into it.
    --   targetRadius : metres from the dumpster, or from the trunk opening, the item must land
    --   trunkRadius  : metres from the centre of the vehicle the server accepts (long vehicles)
    --   chance       : base at point blank with a light item, lost per metre thrown and per kg, never
    --                  below min. Set `targets = false` to turn targets off.
    targets = {
        targetRadius = 2.5,
        trunkRadius = 7.0,
        chance = { base = 0.85, perMeter = 0.04, perKg = 0.06, min = 0.05 },
    },

    -- from inside a vehicle, any seat may throw when there is an opening next to it: window rolled down
    -- or broken, door open, door missing, or a vehicle without doors
    fromVehicle = true,

    -- object shown in hand and in the air for items without a prop of their own
    prop = `prop_paper_bag_small`,

    -- animation played when the item leaves the hand
    anim = { dict = 'anim@heists@narcotics@trash', clip = 'throw_b' },
}
