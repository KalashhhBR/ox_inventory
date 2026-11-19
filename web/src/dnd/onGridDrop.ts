// klsh: drop on a grid inventory. Nothing moves on screen until the server confirms and syncs the slots.
import { canStack, getInventoryByType, isSlotWithItem } from '../helpers';
import { GridItem } from '../helpers/grid';
import { store } from '../store';
import { Items } from '../store/items';
import { enqueueMove } from './moveQueue';
import { DragSource, Inventory, InventoryType, SlotWithItem } from '../typings';
import { onBuy } from './onBuy';
import { onCraft } from './onCraft';

export type GridTarget =
  | { action: 'place'; x: number; y: number; rotated: boolean }
  | { action: 'stack'; item: GridItem }
  | { action: 'swap'; item: GridItem; x: number; y: number; rotated: boolean }
  | { action: 'quick' };

const firstSlot = (inventory: Inventory) => inventory.items.find((slot) => !isSlotWithItem(slot))?.slot || 1;

// how many units of a stack the next move takes: half with Shift, the typed quantity, or all of it
export const movingCount = (total: number) => {
  const { shiftPressed, itemAmount } = store.getState().inventory;

  if (shiftPressed && total > 1) return Math.floor(total / 2);

  return itemAmount === 0 || itemAmount > total ? total : itemAmount;
};

export const onGridDrop = (source: DragSource, inventory: Inventory, target: GridTarget) => {
  if (source.inventory === InventoryType.SHOP)
    return onBuy(source, { inventory: inventory.type, item: { slot: firstSlot(inventory) } });

  if (source.inventory === InventoryType.CRAFTING)
    return onCraft(source, { inventory: inventory.type, item: { slot: firstSlot(inventory) } });

  const { inventory: state } = store.getState();
  const sourceInventory = getInventoryByType(state, source.inventory);
  const sourceSlot = sourceInventory.items[source.item.slot - 1] as SlotWithItem;

  if (!sourceSlot?.name) return;

  const sourceData = Items[sourceSlot.name];

  if (sourceData === undefined) return console.error(`${sourceSlot.name} item data undefined!`);

  if (sourceSlot.metadata?.container !== undefined) {
    if (
      inventory.type === InventoryType.CONTAINER ||
      inventory.type === InventoryType.BACKPACK ||
      inventory.type === InventoryType.OTHER_BACKPACK
    )
      return console.log(`Cannot store container ${sourceSlot.name} inside another container`);

    if (state.rightInventory.id === sourceSlot.metadata.container)
      return console.log(`Cannot move container ${sourceSlot.name} when opened`);
  }

  if (
    target.action === 'swap' &&
    target.item.metadata?.container !== undefined &&
    state.rightInventory.id === target.item.metadata.container
  )
    return console.log(`Cannot swap item ${sourceSlot.name} with container ${target.item.name} when opened`);

  if (target.action === 'stack' && !(sourceData.stack && canStack(sourceSlot, target.item))) return;

  const count = target.action === 'swap' ? sourceSlot.count : movingCount(sourceSlot.count);

  enqueueMove({
      fromSlot: sourceSlot.slot,
      fromType: sourceInventory.type,
      toType: inventory.type,
      count,
      ...(target.action === 'place'
        ? { toX: target.x, toY: target.y, rotated: target.rotated }
        : target.action === 'quick'
          ? {}
          : target.action === 'swap'
            ? { toSlot: target.item.slot, toX: target.x, toY: target.y, rotated: target.rotated }
            : { toSlot: target.item.slot }),
  });
};
