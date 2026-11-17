import { canStack, findAvailableSlot, getEquipmentSlot, getTargetInventory, isSlotWithItem } from '../helpers';
import { validateMove } from '../thunks/validateItems';
import { store } from '../store';
import { DragSource, DropTarget, InventoryType, SlotWithItem } from '../typings';
import { moveSlots, stackSlots, swapSlots } from '../store/inventory';
import { Items } from '../store/items';
import { onGridDrop } from './onGridDrop';
import { enqueueMove } from './moveQueue';

export const onDrop = (source: DragSource, target?: DropTarget) => {
  const { inventory: state } = store.getState();

  const { sourceInventory, targetInventory } = getTargetInventory(state, source.inventory, target?.inventory);

  const sourceSlot = sourceInventory.items[source.item.slot - 1] as SlotWithItem;

  const sourceData = Items[sourceSlot.name];

  if (sourceData === undefined) return console.error(`${sourceSlot.name} item data undefined!`);

  // If dragging from container slot
  if (sourceSlot.metadata?.container !== undefined) {
    // Prevent storing container in container
    if (
      targetInventory.type === InventoryType.CONTAINER ||
      targetInventory.type === InventoryType.BACKPACK ||
      targetInventory.type === InventoryType.OTHER_BACKPACK
    )
      return console.log(`Cannot store container ${sourceSlot.name} inside another container`);

    // Prevent dragging of container slot when opened
    if (state.rightInventory.id === sourceSlot.metadata.container)
      return console.log(`Cannot move container ${sourceSlot.name} when opened`);
  }

  // klsh: quick move into a grid inventory: the server picks the place
  if (!target && targetInventory.grid)
    return onGridDrop(source, targetInventory, { action: 'quick' });

  // klsh: an outfit bag opened on the right keeps each piece in the slot of its category
  const outfitSlot =
    targetInventory.type === InventoryType.CONTAINER && targetInventory.categories
      ? getEquipmentSlot(targetInventory, sourceSlot.name)
      : undefined;

  if (targetInventory.type === InventoryType.CONTAINER && targetInventory.categories && !outfitSlot)
    return console.log(`${sourceSlot.name} does not go in an outfit bag`);

  const targetSlot = target
    ? targetInventory.items[target.item.slot - 1]
    : outfitSlot
      ? targetInventory.items[outfitSlot - 1]
      : findAvailableSlot(sourceSlot, sourceData, targetInventory.items);

  if (targetSlot === undefined) return console.error('Target slot undefined!');

  // klsh: equipment slots only take items of their own category (the server validates again)
  if (
    targetInventory.type === InventoryType.EQUIPMENT ||
    targetInventory.type === InventoryType.OTHER_EQUIPMENT ||
    outfitSlot
  ) {
    if (getEquipmentSlot(targetInventory, sourceSlot.name) !== targetSlot.slot)
      return console.log(`${sourceSlot.name} does not fit equipment slot ${targetSlot.slot}`);
  }

  if (
    (sourceInventory.type === InventoryType.EQUIPMENT || sourceInventory.type === InventoryType.OTHER_EQUIPMENT) &&
    targetSlot.name !== undefined
  ) {
    if (getEquipmentSlot(sourceInventory, targetSlot.name) !== sourceSlot.slot)
      return console.log(`${targetSlot.name} cannot be swapped into equipment slot ${sourceSlot.slot}`);
  }

  // If dropping on container slot when opened
  if (targetSlot.metadata?.container !== undefined && state.rightInventory.id === targetSlot.metadata.container)
    return console.log(`Cannot swap item ${sourceSlot.name} with container ${targetSlot.name} when opened`);

  const count =
    state.shiftPressed && sourceSlot.count > 1 && sourceInventory.type !== 'shop'
      ? Math.floor(sourceSlot.count / 2)
      : state.itemAmount === 0 || state.itemAmount > sourceSlot.count
        ? sourceSlot.count
        : state.itemAmount;

  const data = {
    fromSlot: sourceSlot,
    toSlot: targetSlot,
    fromType: sourceInventory.type,
    toType: targetInventory.type,
    count: count,
  };

  const move = { ...data, fromSlot: sourceSlot.slot, toSlot: targetSlot.slot };
  const linked: string[] = [InventoryType.EQUIPMENT, InventoryType.OTHER_EQUIPMENT];

  // klsh: clothing changes, heavy transfers and anything in a grid only move when the server confirms
  // (it syncs the inventories), so they can wait in the queue behind a move that is still running
  if (
    linked.includes(sourceInventory.type) ||
    linked.includes(targetInventory.type) ||
    sourceInventory.grid ||
    targetInventory.grid
  )
    return enqueueMove(move);

  store.dispatch(validateMove(move));

  const minWeight = state.leftInventory.transferMinWeight;

  if (minWeight !== undefined && sourceInventory !== targetInventory) {
    let movingWeight = (sourceSlot.weight / sourceSlot.count) * count;

    if (isSlotWithItem(targetSlot, true) && !(sourceData.stack && canStack(sourceSlot, targetSlot)))
      movingWeight += targetSlot.weight;

    if (movingWeight >= minWeight) return;
  }

  isSlotWithItem(targetSlot, true)
    ? sourceData.stack && canStack(sourceSlot, targetSlot)
      ? store.dispatch(
          stackSlots({
            ...data,
            toSlot: targetSlot,
          })
        )
      : store.dispatch(
          swapSlots({
            ...data,
            toSlot: targetSlot,
          })
        )
    : store.dispatch(moveSlots(data));
};
