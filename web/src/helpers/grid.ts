// klsh: grid geometry for the screen. The server (modules/grid/shared.lua) is the source of truth;
// this only draws items and tells the player in advance whether a place looks free.
import { Items } from '../store/items';
import { Inventory, Slot, SlotWithItem } from '../typings';
import { isSlotWithItem } from './index';

export type GridItem = SlotWithItem & { x: number; y: number };

export const itemSize = (name: string): [number, number] => Items[name]?.size || [1, 1];

export const footprint = (size: [number, number], rotated?: boolean): [number, number] =>
  rotated ? [size[1], size[0]] : [size[0], size[1]];

export const isGridItem = (slot: Slot | undefined): slot is GridItem =>
  !!slot && isSlotWithItem(slot) && slot.x !== undefined && slot.y !== undefined;

export const gridItems = (inventory: Inventory): GridItem[] => inventory.items.filter(isGridItem);

export const itemAt = (items: GridItem[], x: number, y: number): GridItem | undefined =>
  items.find((item) => {
    const [w, h] = footprint(itemSize(item.name), item.rotated);

    return x >= item.x && x < item.x + w && y >= item.y && y < item.y + h;
  });

// true when the rectangle is inside the configured area and overlaps no item (ignoring one slot)
export const fits = (
  items: GridItem[],
  grid: { w: number; h: number },
  x: number,
  y: number,
  w: number,
  h: number,
  ignoreSlot?: number
) => {
  if (x < 1 || y < 1 || x + w - 1 > grid.w || y + h - 1 > grid.h) return false;

  return !items.some((item) => {
    if (item.slot === ignoreSlot) return false;

    const [iw, ih] = footprint(itemSize(item.name), item.rotated);

    return x < item.x + iw && item.x < x + w && y < item.y + ih && item.y < y + h;
  });
};
