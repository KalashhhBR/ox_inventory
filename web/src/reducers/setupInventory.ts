import { CaseReducer, PayloadAction } from '@reduxjs/toolkit';
import { getItemData, itemDurability, normalizeLinkedInventory } from '../helpers';
import { Items } from '../store/items';
import { Inventory, State } from '../typings';

export const setupInventoryReducer: CaseReducer<
  State,
  PayloadAction<{
    leftInventory?: Inventory;
    rightInventory?: Inventory;
    equipmentInventory?: Inventory; // klsh
    backpackInventory?: Inventory; // klsh
    groundInventory?: Inventory; // klsh
    otherEquipmentInventory?: Inventory; // klsh
    otherBackpackInventory?: Inventory; // klsh
  }>
> = (state, action) => {
  const { leftInventory, rightInventory, equipmentInventory, backpackInventory, groundInventory } = action.payload;
  const curTime = Math.floor(Date.now() / 1000);

  if (leftInventory)
    state.leftInventory = {
      ...leftInventory,
      items: Array.from(Array(leftInventory.slots), (_, index) => {
        const item = Object.values(leftInventory.items).find((item) => item?.slot === index + 1) || {
          slot: index + 1,
        };

        if (!item.name) return item;

        if (typeof Items[item.name] === 'undefined') {
          getItemData(item.name);
        }

        item.durability = itemDurability(item.metadata, curTime);
        return item;
      }),
    };

  if (rightInventory)
    state.rightInventory = {
      ...rightInventory,
      items: Array.from(Array(rightInventory.slots), (_, index) => {
        const item = Object.values(rightInventory.items).find((item) => item?.slot === index + 1) || {
          slot: index + 1,
        };

        if (!item.name) return item;

        if (typeof Items[item.name] === 'undefined') {
          getItemData(item.name);
        }

        item.durability = itemDurability(item.metadata, curTime);
        return item;
      }),
    };

  // klsh: linked inventories follow the player's inventory; payloads without them (shops, crafting) hide them
  if (leftInventory || equipmentInventory)
    state.equipmentInventory = equipmentInventory && normalizeLinkedInventory(equipmentInventory);

  if (leftInventory || backpackInventory)
    state.backpackInventory = backpackInventory && normalizeLinkedInventory(backpackInventory);

  if (leftInventory || groundInventory)
    state.groundInventory = groundInventory && normalizeLinkedInventory(groundInventory);

  // klsh: equipment and backpack of the player being searched follow the secondary inventory
  if (leftInventory || rightInventory) {
    const { otherEquipmentInventory, otherBackpackInventory } = action.payload;

    state.otherEquipmentInventory = otherEquipmentInventory && normalizeLinkedInventory(otherEquipmentInventory);
    state.otherBackpackInventory = otherBackpackInventory && normalizeLinkedInventory(otherBackpackInventory);
  }

  state.shiftPressed = false;
  state.isBusy = false;
};
