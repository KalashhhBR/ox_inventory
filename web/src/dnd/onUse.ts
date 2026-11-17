//import toast from "react-hot-toast";
import { fetchNui } from '../utils/fetchNui';
import { InventoryType, Slot } from '../typings';
import { store } from '../store';
import { getEquipmentSlot } from '../helpers';
import { onDrop } from './onDrop';

export const onUse = (item: Slot) => {
  // klsh: "using" a clothing item wears it (moves it to its equipment slot)
  const equipment = store.getState().inventory.equipmentInventory;
  const equipmentSlot = getEquipmentSlot(equipment, item.name);

  // klsh: a backpack opened on the right cannot move; the client closes that view and uses it again
  const state = store.getState().inventory;
  const container = state.leftInventory.items[item.slot - 1]?.metadata?.container;

  if (equipmentSlot && container !== undefined && state.rightInventory.id === container)
    return fetchNui('wearOpenedContainer', item.slot);

  if (equipmentSlot && item.name)
    return onDrop(
      { item: { name: item.name, slot: item.slot }, inventory: InventoryType.PLAYER },
      { inventory: InventoryType.EQUIPMENT, item: { slot: equipmentSlot } }
    );

  //toast.success(`Use ${item.name}`);
  fetchNui('useItem', item.slot);
};
