// klsh: dropping an item on the character in the middle of the screen is a shortcut: clothing, vest
// and backpack are worn (replacing the piece in that slot); anything else is used (a weapon goes to
// the hand)
import { getEquipmentSlot } from '../helpers';
import { store } from '../store';
import { DragSource, InventoryType } from '../typings';
import { onDrop } from './onDrop';
import { onUse } from './onUse';

const NEVER: string[] = [InventoryType.EQUIPMENT, InventoryType.OTHER_EQUIPMENT, InventoryType.SHOP, InventoryType.CRAFTING];

export const bodyAction = (source: DragSource): 'wear' | 'use' | undefined => {
  if (NEVER.includes(source.inventory)) return;
  if (source.item.name === 'money' || source.item.name === 'black_money') return;

  if (getEquipmentSlot(store.getState().inventory.equipmentInventory, source.item.name)) return 'wear';

  // "use" takes a slot of the main inventory
  if (source.inventory === InventoryType.PLAYER) return 'use';
};

export const onBody = (source: DragSource) => {
  const action = bodyAction(source);

  if (!action) return;

  // from the main inventory "use" already wears (and handles a backpack that is opened on the right)
  if (source.inventory === InventoryType.PLAYER) return onUse(source.item);

  const slot = getEquipmentSlot(store.getState().inventory.equipmentInventory, source.item.name);

  if (slot) onDrop(source, { inventory: InventoryType.EQUIPMENT, item: { slot } });
};
