-- klsh: grid geometry (pure functions, no game or framework calls; unit-tested outside the game).
--
-- An inventory with a grid is `w` cells wide and `h` cells tall. Every item has a position
-- (`x`, `y` = top-left cell, 1-based) and `rotated` (90 degrees: width and height swap), stored on the
-- slot data next to name/count/metadata. `slot` is only the item's identifier.
-- Wallet items (accounts in a player inventory) have no position and never take cells.

local Grid = {}

---@param w number item width
---@param h number item height
---@param rotated? boolean
---@return number w, number h footprint on the grid
function Grid.footprint(w, h, rotated)
    if rotated then return h, w end

    return w, h
end

---@return boolean overlap true when two rectangles share at least one cell
function Grid.rectsOverlap(ax, ay, aw, ah, bx, by, bw, bh)
    return ax < bx + bw and bx < ax + aw and ay < by + bh and by < ay + ah
end

---Builds the occupancy of an inventory: cell index -> slot of the item covering it.
---@param items table<number, table> slot -> { name, x, y, rotated }
---@param w number grid width
---@param getSize fun(name: string): number, number item width and height
---@param ignoreSlot? number slot left out (the item being moved)
---@param ignoreSlot2? number second slot left out (swap)
---@return table<number, number> cells
function Grid.occupancy(items, w, getSize, ignoreSlot, ignoreSlot2)
    local cells = {}

    for slot, item in pairs(items) do
        if slot ~= ignoreSlot and slot ~= ignoreSlot2 and item.x and item.y then
            local iw, ih = Grid.footprint(getSize(item.name))

            if item.rotated then iw, ih = ih, iw end

            for dy = 0, ih - 1 do
                local row = (item.y - 1 + dy) * w

                for dx = 0, iw - 1 do
                    cells[row + item.x + dx] = slot
                end
            end
        end
    end

    return cells
end

---@param cells table<number, number>
---@param w number grid width
---@param h number grid height available for the placement
---@return boolean fits true when the rectangle is inside the grid and every cell is free
function Grid.fits(cells, w, h, x, y, iw, ih)
    if math.type(x) ~= 'integer' or math.type(y) ~= 'integer' then return false end
    if x < 1 or y < 1 or x + iw - 1 > w or y + ih - 1 > h then return false end

    for dy = 0, ih - 1 do
        local row = (y - 1 + dy) * w

        for dx = 0, iw - 1 do
            if cells[row + x + dx] then return false end
        end
    end

    return true
end

---Marks a rectangle as taken by a slot.
function Grid.mark(cells, w, x, y, iw, ih, slot)
    for dy = 0, ih - 1 do
        local row = (y - 1 + dy) * w

        for dx = 0, iw - 1 do
            cells[row + x + dx] = slot
        end
    end
end

---First free position for an item, scanning rows top to bottom and columns left to right.
---At each cell the normal orientation is tried before the rotated one.
---@param iw number item width (not rotated)
---@param ih number item height (not rotated)
---@param allowRotate? boolean
---@return number? x, number? y, boolean? rotated
function Grid.findSpace(cells, w, h, iw, ih, allowRotate)
    local canRotate = allowRotate and iw ~= ih

    for y = 1, h do
        for x = 1, w do
            if not cells[(y - 1) * w + x] then
                if Grid.fits(cells, w, h, x, y, iw, ih) then return x, y, false end
                if canRotate and Grid.fits(cells, w, h, x, y, ih, iw) then return x, y, true end
            end
        end
    end
end

---@param items table<number, table>
---@param taken? table<number, boolean> slots reserved by the plan being built
---@return number slot smallest free slot identifier
function Grid.freeSlot(items, taken)
    local slot = 1

    while items[slot] or (taken and taken[slot]) do
        slot = slot + 1
    end

    return slot
end

---@class GridPlanOptions
---@field getSize fun(name: string): number, number
---@field maxStack? number stack limit of the item (nil = unlimited)
---@field stackable boolean
---@field matches? fun(slotItem: table): boolean true when the slot can receive more of this item
---@field wallet? boolean account item in a player inventory: no position, one unlimited stack
---@field position? { x: number, y: number, rotated?: boolean } wanted position for the first new stack
---@field allowRotate? boolean defaults to true

---Plans how `count` units of an item enter an inventory, without changing anything.
---Fills existing stacks first (ascending slot), then opens new stacks or single items.
---@param items table<number, table> slot -> slot data
---@param w number
---@param h number configured height (new items never go to legacy rows)
---@param name string
---@param count number
---@param options GridPlanOptions
---@return { stacks: { slot: number, add: number }[], new: { slot: number, count: number, x?: number, y?: number, rotated?: boolean, wallet?: boolean }[], remaining: number }
function Grid.plan(items, w, h, name, count, options)
    local plan = { stacks = {}, new = {}, remaining = count }
    local getSize = options.getSize

    if options.stackable and options.matches then
        local slots = {}

        for slot, item in pairs(items) do
            if item.name == name and options.matches(item) then slots[#slots + 1] = slot end
        end

        table.sort(slots)

        for i = 1, #slots do
            if plan.remaining == 0 then break end

            local item = items[slots[i]]
            local room = options.wallet and plan.remaining
                or (options.maxStack and math.max(options.maxStack - item.count, 0))
                or plan.remaining
            local add = math.min(room, plan.remaining)

            if add > 0 then
                plan.stacks[#plan.stacks + 1] = { slot = slots[i], add = add }
                plan.remaining = plan.remaining - add
            end
        end
    end

    if plan.remaining == 0 then return plan end

    local taken = {}

    if options.wallet then
        local slot = Grid.freeSlot(items, taken)

        plan.new[1] = { slot = slot, count = plan.remaining, wallet = true }
        plan.remaining = 0

        return plan
    end

    local cells = Grid.occupancy(items, w, getSize)
    local iw, ih = getSize(name)
    local allowRotate = options.allowRotate ~= false
    local perStack = options.stackable and (options.maxStack or plan.remaining) or 1
    local position = options.position

    while plan.remaining > 0 do
        local x, y, rotated

        if position then
            local pw, ph = Grid.footprint(iw, ih, position.rotated)

            if Grid.fits(cells, w, h, position.x, position.y, pw, ph) then
                x, y, rotated = position.x, position.y, position.rotated and true or false
            end

            position = nil
        end

        if not x then
            x, y, rotated = Grid.findSpace(cells, w, h, iw, ih, allowRotate)
        end

        if not x then break end

        local slot = Grid.freeSlot(items, taken)
        local amount = math.min(perStack, plan.remaining)
        local fw, fh = Grid.footprint(iw, ih, rotated)

        taken[slot] = true
        Grid.mark(cells, w, x, y, fw, fh, slot)
        plan.new[#plan.new + 1] = { slot = slot, count = amount, x = x, y = y, rotated = rotated }
        plan.remaining = plan.remaining - amount
    end

    return plan
end

---Checks a move of one item to a position, in the same inventory or coming from another one.
---@param items table<number, table> destination inventory items
---@param movingSlot? number slot of the item when it already is in this inventory (ignored in the check)
---@return boolean fits
function Grid.canPlace(items, w, h, getSize, name, x, y, rotated, movingSlot)
    local iw, ih = Grid.footprint(getSize(name))

    if rotated then iw, ih = ih, iw end

    return Grid.fits(Grid.occupancy(items, w, getSize, movingSlot), w, h, x, y, iw, ih)
end

---Checks whether two different items can trade places: A (moving, with the requested rotation) goes
---to B's position and B (keeping its rotation) goes to A's old position.
---@param fromItems table<number, table> inventory of A
---@param fromGrid? { w: number, h: number } nil when A is in an inventory without a grid
---@param toItems table<number, table> inventory of B
---@param toGrid { w: number, h: number }
---@param a table slot data of A (with slot)
---@param b table slot data of B (with slot)
---@param aRotated? boolean rotation requested for A at the destination
---@return boolean canSwap
function Grid.canSwap(fromItems, fromGrid, toItems, toGrid, getSize, a, b, aRotated)
    local aw, ah = Grid.footprint(getSize(a.name))
    local bw, bh = Grid.footprint(getSize(b.name))

    if aRotated then aw, ah = ah, aw end
    if b.rotated then bw, bh = bh, bw end

    local same = fromItems == toItems
    local toCells = Grid.occupancy(toItems, toGrid.w, getSize, b.slot, same and a.slot or nil)

    if not Grid.fits(toCells, toGrid.w, toGrid.h, b.x, b.y, aw, ah) then return false end
    if not fromGrid then return true end -- e.g. an equipment slot receives B

    local fromCells = same and toCells or Grid.occupancy(fromItems, fromGrid.w, getSize, a.slot)

    if not Grid.fits(fromCells, fromGrid.w, fromGrid.h, a.x, a.y, bw, bh) then return false end

    return not same or not Grid.rectsOverlap(b.x, b.y, aw, ah, a.x, a.y, bw, bh)
end

---Validates and repairs the positions of an inventory. Items with a valid position stay; items without
---position, out of bounds or overlapping are placed in the first free space. When the content does not
---fit the configured height the grid grows ("legacy rows"). Wallet items are skipped.
---@param items table<number, table>
---@param w number
---@param h number configured height
---@param getSize fun(name: string): number, number
---@param isWallet? fun(item: table): boolean
---@return number height height in use (>= h), boolean moved true when any item changed position
function Grid.normalize(items, w, h, getSize, isWallet)
    local slots = {}

    for slot in pairs(items) do slots[#slots + 1] = slot end

    table.sort(slots)

    local cells, pending, moved = {}, {}, false
    local height = h

    for i = 1, #slots do
        local slot = slots[i]
        local item = items[slot]

        if isWallet and isWallet(item) then
            if item.x or item.y or item.rotated then
                item.x, item.y, item.rotated = nil, nil, nil
                moved = true
            end
        else
            local iw, ih = Grid.footprint(getSize(item.name))

            if item.rotated then iw, ih = ih, iw end

            -- valid positions may sit on legacy rows (below the configured height)
            if item.x and item.y and Grid.fits(cells, w, math.huge, item.x, item.y, iw, ih) then
                Grid.mark(cells, w, item.x, item.y, iw, ih, slot)
                height = math.max(height, item.y + ih - 1)
            else
                pending[#pending + 1] = slot
            end
        end
    end

    for i = 1, #pending do
        local slot = pending[i]
        local item = items[slot]
        local iw, ih = getSize(item.name)
        local x, y, rotated = Grid.findSpace(cells, w, height, iw, ih, true)

        -- too wide for this inventory in any orientation: clamp so it is at least reachable
        if not x and math.min(iw, ih) > w then
            x, y, rotated = 1, height + 1, false
            iw = w
        end

        while not x do
            height = height + 1
            x, y, rotated = Grid.findSpace(cells, w, height, iw, ih, true)
        end

        local fw, fh = Grid.footprint(iw, ih, rotated)

        Grid.mark(cells, w, x, y, fw, fh, slot)
        height = math.max(height, y + fh - 1)
        item.x, item.y, item.rotated = x, y, rotated or nil
        moved = true
    end

    return height, moved
end

return Grid
