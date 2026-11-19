// klsh: dragging an item out of the pockets or the worn backpack, onto no inventory at all, drops it
// on the ground: the ground section when another inventory is open, the drop on the right otherwise
import { store } from '../store';
import { DragSource, Inventory, InventoryType, State } from '../typings';
import { onDrop } from './onDrop';
import { onGridDrop } from './onGridDrop';

export const groundTarget = (state: State): Inventory | undefined =>
  state.groundInventory ||
  (state.rightInventory.type === 'drop' || state.rightInventory.type === 'newdrop' ? state.rightInventory : undefined);

export const canGround = (source: DragSource) =>
  (source.inventory === InventoryType.PLAYER || source.inventory === InventoryType.BACKPACK) &&
  !!groundTarget(store.getState().inventory);

export const onGround = (source: DragSource) => {
  if (!canGround(source)) return;

  const target = groundTarget(store.getState().inventory)!;

  // the server picks the place (and joins a nearby drop or starts another one when this one is full)
  if (target.grid) return onGridDrop(source, target, { action: 'quick' });

  if (source.inventory === InventoryType.PLAYER && target.type !== InventoryType.GROUND) onDrop(source);
};
