// klsh: hotbar shortcuts resolved against the player's inventory
import { Slot, SlotWithItem, State } from '../typings';
import { isSlotWithItem } from './index';

type Entry = State['hotbar'][number];

// 1-based shortcut number of an item, 0 when it has none
export const hotbarIndexOf = (hotbar: State['hotbar'], item: Slot) =>
  hotbar.findIndex((entry) => !!entry && entry.name === item.name && (entry.slot === undefined || entry.slot === item.slot)) + 1;

// the item a shortcut shows and how many units it stands for (all stacks for a shortcut by name)
export const resolveHotbar = (entry: Entry, items: Slot[]): { item?: SlotWithItem; count: number } => {
  if (!entry) return { count: 0 };

  if (entry.slot !== undefined) {
    const item = items[entry.slot - 1];

    return item && isSlotWithItem(item) && item.name === entry.name ? { item, count: item.count } : { count: 0 };
  }

  const stacks = items.filter((item): item is SlotWithItem => isSlotWithItem(item) && item.name === entry.name);

  return { item: stacks[0], count: stacks.reduce((total, item) => total + item.count, 0) };
};
