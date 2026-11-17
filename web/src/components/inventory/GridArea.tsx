// klsh: a grid inventory. Cells are only a background; items are placed over them.
// One drop target for the whole area: the cell comes from the pointer position.
import React, { useEffect, useMemo, useRef, useState } from 'react';
import { useDragDropManager, useDrop } from 'react-dnd';
import { DragSource, Inventory, InventoryType } from '../../typings';
import { canStack } from '../../helpers';
import { fits, footprint, gridItems, GridItem as GridItemData, itemAt } from '../../helpers/grid';
import { getDragRotated, setDragRotated, useDragRotated } from '../../store/gridDrag';
import { Items } from '../../store/items';
import { useAppDispatch, store } from '../../store';
import { closeTooltip } from '../../store/tooltip';
import { GridTarget, onGridDrop } from '../../dnd/onGridDrop';
import { getInventoryByType } from '../../helpers';
import GridItem from './GridItem';
import InventorySlot from './InventorySlot';
import { Locale } from '../../store/locale';

type Hover = { x: number; y: number; w: number; h: number; state: 'ok' | 'swap' | 'no'; target: GridTarget | null };

const sameHover = (a: Hover | null, b: Hover | null) =>
  a === b || (!!a && !!b && a.x === b.x && a.y === b.y && a.w === b.w && a.h === b.h && a.state === b.state);

const GridArea: React.FC<{ inventory: Inventory; maxRows?: number }> = ({ inventory, maxRows }) => {
  const grid = inventory.grid!;
  const areaRef = useRef<HTMLDivElement>(null);
  const dispatch = useAppDispatch();
  const manager = useDragDropManager();
  const [hover, setHover] = useState<Hover | null>(null);
  const dragRotated = useDragRotated();
  const items = useMemo(() => gridItems(inventory), [inventory.items]);

  const compute = (source: DragSource, pointer: { x: number; y: number } | null): Hover | null => {
    const area = areaRef.current;

    if (!area || !pointer) return null;

    const rect = area.getBoundingClientRect();
    const cell = rect.width / grid.w;
    const px = Math.floor((pointer.x - rect.left) / cell) + 1;
    const py = Math.floor((pointer.y - rect.top) / cell) + 1;

    if (px < 1 || py < 1 || px > grid.w || py > grid.h) return null;

    const sameInventory = source.inventory === inventory.type;
    const self = sameInventory ? source.item.slot : undefined;
    const under = itemAt(items, px, py);

    if (under && under.slot !== self) {
      const [uw, uh] = footprint(Items[under.name]?.size || [1, 1], under.rotated);
      const sourceSlot = getInventoryByType(store.getState().inventory, source.inventory).items[source.item.slot - 1];
      const stack = !!Items[source.item.name]?.stack && !!sourceSlot && canStack(sourceSlot, under);

      if (stack) return { x: under.x, y: under.y, w: uw, h: uh, state: 'ok', target: { action: 'stack', item: under } };

      // swap: show where the dragged item would land (centred on the pointer); the server looks for
      // the nearest arrangement that works and refuses when there is none
      const turned = getDragRotated();
      const [sw, sh] = footprint(source.size || Items[source.item.name]?.size || [1, 1], turned);
      const sx = Math.min(Math.max(Math.round((pointer.x - rect.left) / cell - sw / 2) + 1, 1), Math.max(grid.w - sw + 1, 1));
      const sy = Math.min(Math.max(Math.round((pointer.y - rect.top) / cell - sh / 2) + 1, 1), Math.max(grid.h - sh + 1, 1));

      return {
        x: sx,
        y: sy,
        w: sw,
        h: sh,
        state: 'swap',
        target: { action: 'swap', item: under, x: sx, y: sy, rotated: turned },
      };
    }

    const rotated = getDragRotated();
    // sources that are not grid items (equipment and wallet slots, shop) carry no size
    const [w, h] = footprint(source.size || Items[source.item.name]?.size || [1, 1], rotated);
    // the item is centred on the pointer and kept inside the area
    const x = Math.min(Math.max(Math.round((pointer.x - rect.left) / cell - w / 2) + 1, 1), Math.max(grid.w - w + 1, 1));
    const y = Math.min(Math.max(Math.round((pointer.y - rect.top) / cell - h / 2) + 1, 1), Math.max(grid.h - h + 1, 1));
    const free = fits(items, grid, x, y, w, h, self);

    return { x, y, w, h, state: free ? 'ok' : 'no', target: free ? { action: 'place', x, y, rotated } : null };
  };

  const [, drop] = useDrop<DragSource, void, unknown>(
    () => ({
      accept: 'SLOT',
      drop: (source, monitor) => {
        const result = compute(source, monitor.getClientOffset());

        dispatch(closeTooltip());
        setHover(null);

        if (result?.target) onGridDrop(source, inventory, result.target);
      },
    }),
    [inventory, items]
  );

  // the highlight follows the pointer through the monitor: inside a target's hover callback the
  // offset is still the one from the previous move
  const computeRef = useRef(compute);
  computeRef.current = compute;

  useEffect(() => {
    const monitor = manager.getMonitor();

    const update = () => {
      const source = monitor.isDragging() ? (monitor.getItem() as DragSource | null) : null;
      const next = source ? computeRef.current(source, monitor.getClientOffset()) : null;

      setHover((previous) => (sameHover(previous, next) ? previous : next));
    };

    const onKey = (event: KeyboardEvent) => {
      if ((event.key !== 'r' && event.key !== 'R') || !monitor.isDragging()) return;

      // every grid area hears the key; only the first one flips the shared state
      if (!event.defaultPrevented) {
        event.preventDefault();
        setDragRotated(!getDragRotated());
      }

      update();
    };

    const offOffset = monitor.subscribeToOffsetChange(update);
    const offState = monitor.subscribeToStateChange(update);

    window.addEventListener('keydown', onKey);

    return () => {
      offOffset();
      offState();
      window.removeEventListener('keydown', onKey);
    };
  }, [manager]);

  const shown = hover;
  // the player's own wallet, or the wallet of the player being searched
  const wallet = inventory.type === InventoryType.PLAYER || inventory.type === 'otherplayer' ? grid.wallet : undefined;

  return (
    <>
      <div
        className="grid-scroll"
        style={maxRows && grid.h > maxRows ? { maxHeight: `calc(${maxRows} * var(--grid-cell))`, overflowY: 'scroll' } : undefined}
      >
        <div
          ref={(element) => {
            areaRef.current = element;
            drop(element);
          }}
          className="grid-area"
          data-rotated={dragRotated ? 'true' : undefined}
          style={{
            width: `calc(${grid.w} * var(--grid-cell))`,
            height: `calc(${grid.h} * var(--grid-cell))`,
          }}
        >
          {items.map((item: GridItemData) => (
            <GridItem key={`${inventory.id}-${item.slot}`} item={item} inventory={inventory} />
          ))}
          {shown && (
            <div
              className={`grid-highlight grid-highlight-${shown.state}`}
              style={{
                left: `calc(${shown.x - 1} * var(--grid-cell))`,
                top: `calc(${shown.y - 1} * var(--grid-cell))`,
                width: `calc(${shown.w} * var(--grid-cell))`,
                height: `calc(${shown.h} * var(--grid-cell))`,
              }}
            />
          )}
        </div>
      </div>
      {wallet !== undefined && (
        <div className="grid-wallet">
          <p>{Locale.ui_wallet || 'Wallet'}</p>
          {[wallet, wallet + 1].map((index) => {
            const slot = inventory.items[index] || { slot: index + 1 };

            return (
              <InventorySlot
                key={`wallet-${slot.slot}`}
                item={slot}
                inventoryType={inventory.type}
                inventoryGroups={inventory.groups}
                inventoryId={inventory.id}
              />
            );
          })}
        </div>
      )}
    </>
  );
};

export default GridArea;
