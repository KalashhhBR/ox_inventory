-- klsh: tests for modules/grid/shared.lua. Plain Lua 5.4, no game needed:
--   lua tests/grid.lua            (from the resource folder)
local Grid = dofile('modules/grid/shared.lua')

local sizes = {
    pistol = { 2, 1 }, rifle = { 4, 2 }, water = { 1, 2 }, ammo = { 1, 1 }, pack = { 3, 3 }, money = { 1, 1 },
    wide = { 5, 1 },
}

local function getSize(name)
    local size = sizes[name]

    return size and size[1] or 1, size and size[2] or 1
end

local passed, failed = 0, 0

local function test(name, fn)
    local ok, err = pcall(fn)

    if ok then
        passed = passed + 1
    else
        failed = failed + 1
        print('FAIL ' .. name .. ': ' .. tostring(err))
    end
end

local function eq(a, b, what)
    if a ~= b then error(('%s: expected %s, got %s'):format(what or 'value', tostring(b), tostring(a)), 2) end
end

local function matchName(name)
    return function(item) return item.name == name end
end

-- no two items may share a cell and none may leave the grid width
local function assertNoOverlap(items, w)
    local cells = {}

    for slot, item in pairs(items) do
        if item.x then
            local iw, ih = getSize(item.name)

            if item.rotated then iw, ih = ih, iw end

            assert(item.x >= 1 and item.x + iw - 1 <= w, 'item outside the width: slot ' .. slot)

            for dy = 0, ih - 1 do
                for dx = 0, iw - 1 do
                    local cell = (item.y - 1 + dy) * w + item.x + dx

                    assert(not cells[cell], 'overlap at cell ' .. cell)
                    cells[cell] = slot
                end
            end
        end
    end
end

test('footprint rotates', function()
    local w, h = Grid.footprint(4, 2, true)
    eq(w, 2, 'w') eq(h, 4, 'h')
end)

test('fits respects borders', function()
    local cells = {}
    eq(Grid.fits(cells, 8, 5, 5, 4, 4, 2), true, 'bottom right corner')
    eq(Grid.fits(cells, 8, 5, 6, 4, 4, 2), false, 'past the right border')
    eq(Grid.fits(cells, 8, 5, 5, 5, 4, 2), false, 'past the bottom border')
    eq(Grid.fits(cells, 8, 5, 0, 1, 1, 1), false, 'x below 1')
    eq(Grid.fits(cells, 8, 5, 1.5, 1, 1, 1), false, 'fractional position')
end)

test('fits respects occupied cells', function()
    local items = { [1] = { name = 'rifle', x = 1, y = 1 } }
    local cells = Grid.occupancy(items, 8, getSize)
    eq(Grid.fits(cells, 8, 5, 4, 2, 1, 1), false, 'inside the rifle')
    eq(Grid.fits(cells, 8, 5, 5, 1, 1, 1), true, 'right of the rifle')
    eq(Grid.fits(cells, 8, 5, 1, 3, 4, 2), true, 'below the rifle')
end)

test('occupancy honours rotation and ignored slot', function()
    local items = { [1] = { name = 'rifle', x = 1, y = 1, rotated = true } }
    local cells = Grid.occupancy(items, 8, getSize)
    eq(cells[1], 1) eq(cells[2], 1) eq(cells[3], nil) eq(cells[3 * 8 + 1], 1) eq(cells[4 * 8 + 1], nil)
    eq(next(Grid.occupancy(items, 8, getSize, 1)), nil, 'ignored slot')
end)

test('findSpace scans rows first and rotates when needed', function()
    local items = { [1] = { name = 'wide', x = 1, y = 1 }, [2] = { name = 'wide', x = 1, y = 2 } }
    local cells = Grid.occupancy(items, 6, getSize)
    local x, y, rotated = Grid.findSpace(cells, 6, 5, 4, 2, true)
    eq(x, 1) eq(y, 3) eq(rotated, false)

    -- a 6x2 strip with a 4x2 hole of height 2 only on the right column: needs rotation
    cells = Grid.occupancy({ [1] = { name = 'rifle', x = 1, y = 1 } }, 5, getSize)
    x, y, rotated = Grid.findSpace(cells, 5, 4, 1, 2, true)
    eq(x, 5) eq(y, 1) eq(rotated, false)
    x, y, rotated = Grid.findSpace(cells, 5, 2, 2, 1, true)
    eq(x, 5) eq(y, 1) eq(rotated, true, 'pistol only fits beside the rifle standing up')
    eq(Grid.findSpace(cells, 5, 2, 2, 1, false), nil, 'and not at all without rotation')
end)

test('findSpace rotated placement', function()
    -- 2 wide, 4 tall: a rifle (4x2) only fits rotated
    local x, y, rotated = Grid.findSpace({}, 2, 4, 4, 2, true)
    eq(x, 1) eq(y, 1) eq(rotated, true)
    eq(Grid.findSpace({}, 2, 4, 4, 2, false), nil, 'rotation not allowed')
end)

test('plan fills existing stacks up to maxStack then opens new ones', function()
    local items = {
        [1] = { name = 'ammo', count = 50, x = 1, y = 1 },
        [3] = { name = 'ammo', count = 60, x = 2, y = 1 },
    }
    local plan = Grid.plan(items, 8, 5, 'ammo', 85, { getSize = getSize, stackable = true, maxStack = 60, matches = matchName('ammo') })
    eq(plan.remaining, 0)
    eq(#plan.stacks, 1) eq(plan.stacks[1].slot, 1) eq(plan.stacks[1].add, 10)
    eq(#plan.new, 2) eq(plan.new[1].count, 60) eq(plan.new[2].count, 15)
    eq(plan.new[1].slot, 2, 'first free identifier') eq(plan.new[2].slot, 4)
    eq(plan.new[1].x, 3) eq(plan.new[1].y, 1)
end)

test('plan is all or nothing friendly: reports what does not fit', function()
    local items = {}
    local plan = Grid.plan(items, 4, 2, 'rifle', 3, { getSize = getSize, stackable = false })
    eq(#plan.new, 1) eq(plan.remaining, 2)
end)

test('plan honours a wanted position only when it fits', function()
    local items = { [1] = { name = 'rifle', x = 1, y = 1 } }
    local plan = Grid.plan(items, 8, 5, 'pistol', 1, { getSize = getSize, stackable = false, position = { x = 3, y = 2 } })
    eq(plan.new[1].x, 5, 'occupied: falls back to the first free space') eq(plan.new[1].y, 1)
    plan = Grid.plan(items, 8, 5, 'pistol', 1, { getSize = getSize, stackable = false, position = { x = 7, y = 5 } })
    eq(plan.new[1].x, 7) eq(plan.new[1].y, 5)
end)

test('wallet item always fits, even with a full grid', function()
    local items = {}

    for i = 1, 40 do items[i] = { name = 'ammo', count = 60, x = (i - 1) % 8 + 1, y = (i - 1) // 8 + 1 } end

    local plan = Grid.plan(items, 8, 5, 'money', 5000, { getSize = getSize, stackable = true, wallet = true, matches = matchName('money') })
    eq(plan.remaining, 0) eq(plan.new[1].wallet, true) eq(plan.new[1].x, nil) eq(plan.new[1].slot, 41)

    items[41] = { name = 'money', count = 5000 }
    plan = Grid.plan(items, 8, 5, 'money', 700, { getSize = getSize, stackable = true, wallet = true, maxStack = 10, matches = matchName('money') })
    eq(#plan.new, 0) eq(plan.stacks[1].slot, 41) eq(plan.stacks[1].add, 700, 'wallet ignores maxStack')

    -- a normal item is refused on the same full grid
    plan = Grid.plan(items, 8, 5, 'pistol', 1, { getSize = getSize, stackable = false })
    eq(plan.remaining, 1)
end)

test('canPlace ignores the moving item itself (rotate in place)', function()
    local items = { [1] = { name = 'rifle', x = 1, y = 1 }, [2] = { name = 'ammo', count = 1, x = 1, y = 3 } }
    eq(Grid.canPlace(items, 8, 5, getSize, 'rifle', 2, 1, false, 1), true, 'shift one cell')
    eq(Grid.canPlace(items, 8, 5, getSize, 'rifle', 1, 1, true, 1), false, 'rotating hits the ammo below')
    eq(Grid.canPlace(items, 8, 5, getSize, 'rifle', 2, 1, true, 1), true, 'rotated beside the ammo')
    eq(Grid.canPlace(items, 8, 5, getSize, 'rifle', 1, 1, false), false, 'another rifle on top')
end)

test('canSwap: both must fit in each other place', function()
    local items = {
        [1] = { slot = 1, name = 'rifle', x = 1, y = 1 },
        [2] = { slot = 2, name = 'pistol', x = 1, y = 3 },
        [3] = { slot = 3, name = 'ammo', count = 1, x = 3, y = 3 },
    }
    local grid = { w = 8, h = 5 }
    -- pistol to the rifle place fits; rifle to the pistol place (1,3) needs 4x2 but ammo sits at (3,3)
    eq(Grid.canSwap(items, grid, items, grid, getSize, items[2], items[1]), false)
    items[3].x = 6
    eq(Grid.canSwap(items, grid, items, grid, getSize, items[2], items[1]), true)

    -- across inventories
    local other = { [1] = { slot = 1, name = 'pack', x = 1, y = 1 } }
    eq(Grid.canSwap(items, grid, other, { w = 3, h = 3 }, getSize, items[1], other[1]), false, 'rifle does not fit a 3x3 bag')
    eq(Grid.canSwap(other, { w = 3, h = 3 }, items, grid, getSize, other[1], items[2]), true, 'pack fits the 3x3 area at the pistol place')
    items[3].x, items[3].y = 2, 4
    eq(Grid.canSwap(other, { w = 3, h = 3 }, items, grid, getSize, other[1], items[2]), false, 'ammo now blocks that area')
end)

test('canSwap from an inventory without grid (equipment slot)', function()
    local items = { [1] = { slot = 1, name = 'pack', x = 1, y = 1 } }
    local equipment = { [10] = { slot = 10, name = 'pack' } }
    eq(Grid.canSwap(equipment, nil, items, { w = 8, h = 5 }, getSize, equipment[10], items[1]), true)
end)

test('normalize converts legacy slots (no position) without overlap', function()
    local items = {}

    for i = 1, 12 do items[i] = { name = (i % 3 == 0) and 'rifle' or 'pistol', count = 1 } end

    local height, moved = Grid.normalize(items, 8, 5, getSize)
    eq(moved, true)
    assertNoOverlap(items, 8)
    assert(height >= 5, 'height never below the configured one')

    local again, movedAgain = Grid.normalize(items, 8, 5, getSize)
    eq(movedAgain, false, 'second run changes nothing') eq(again, height)
end)

test('normalize grows legacy rows when the content does not fit', function()
    local items = {}

    for i = 1, 30 do items[i] = { name = 'rifle', count = 1 } end -- 30 * 8 cells = 240 > 40

    local height = Grid.normalize(items, 8, 5, getSize)
    assertNoOverlap(items, 8)
    eq(height, 30, '15 rows of two rifles each, 2 cells tall')
end)

test('normalize keeps valid positions and fixes overlapping or out of bounds ones', function()
    local items = {
        [1] = { name = 'rifle', x = 1, y = 1 },
        [2] = { name = 'pistol', x = 3, y = 2 }, -- inside the rifle
        [3] = { name = 'pistol', x = 8, y = 1 }, -- past the right border
        [4] = { name = 'water', x = 6, y = 4, rotated = true },
    }
    local height, moved = Grid.normalize(items, 8, 5, getSize)
    eq(moved, true) eq(height, 5)
    eq(items[1].x, 1) eq(items[1].y, 1)
    eq(items[4].x, 6) eq(items[4].y, 4) eq(items[4].rotated, true)
    assertNoOverlap(items, 8)
end)

test('normalize: a rotated stack that loses one unit keeps its footprint', function()
    local items = { [1] = { name = 'water', count = 4, x = 1, y = 1, rotated = true }, [2] = { name = 'ammo', count = 1, x = 1, y = 2 } }
    items[1].count = 3 -- consumed one; position and rotation must survive untouched
    local _, moved = Grid.normalize(items, 8, 5, getSize)
    eq(moved, false) eq(items[1].rotated, true)
    assertNoOverlap(items, 8)
end)

test('normalize clears positions of wallet items', function()
    local items = { [1] = { name = 'money', count = 10, x = 1, y = 1 }, [2] = { name = 'pistol', x = 1, y = 1 } }
    local _, moved = Grid.normalize(items, 8, 5, getSize, function(item) return item.name == 'money' end)
    eq(moved, true) eq(items[1].x, nil) eq(items[2].x, 1) eq(items[2].y, 1)
end)

test('normalize shrinks back when legacy rows empty', function()
    local items = { [1] = { name = 'pistol', x = 1, y = 9 } }
    eq(Grid.normalize(items, 8, 5, getSize), 9)
    items[1] = nil
    eq(Grid.normalize(items, 8, 5, getSize), 5)
end)

test('random fill never overlaps', function()
    math.randomseed(42)

    local names = { 'pistol', 'rifle', 'water', 'ammo', 'pack', 'wide' }

    for _ = 1, 200 do
        local items = {}
        local w, h = math.random(3, 12), math.random(2, 12)

        for _ = 1, 40 do
            local name = names[math.random(#names)]
            local plan = Grid.plan(items, w, h, name, 1, { getSize = getSize, stackable = false })

            for i = 1, #plan.new do
                local entry = plan.new[i]
                items[entry.slot] = { name = name, count = 1, x = entry.x, y = entry.y, rotated = entry.rotated or nil }
            end
        end

        assertNoOverlap(items, w)

        for _, item in pairs(items) do
            local iw, ih = getSize(item.name)
            if item.rotated then iw, ih = ih, iw end
            assert(item.y + ih - 1 <= h, 'item below the configured height')
        end
    end
end)

-- performance: plan one more item into a full 10 x 50 stash
do
    local items = {}

    for i = 1, 500 do items[i] = { name = 'ammo', count = 60, x = (i - 1) % 10 + 1, y = (i - 1) // 10 + 1 } end

    items[500] = nil

    local started = os.clock()
    local runs = 200

    for _ = 1, runs do
        Grid.plan(items, 10, 50, 'pistol', 1, { getSize = getSize, stackable = false })
        Grid.plan(items, 10, 50, 'ammo', 30, { getSize = getSize, stackable = true, maxStack = 60, matches = matchName('ammo') })
    end

    local perCall = (os.clock() - started) / (runs * 2) * 1000

    print(('plan on a full 10x50 stash: %.3f ms per call'):format(perCall))
    test('plan stays under 1 ms on a full 10x50 stash', function() assert(perCall < 1, perCall .. ' ms') end)
end

print(('%d passed, %d failed'):format(passed, failed))

if failed > 0 then os.exit(1) end
