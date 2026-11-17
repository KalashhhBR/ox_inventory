import { CaseReducer, PayloadAction } from '@reduxjs/toolkit';
import { itemDurability } from '../helpers';
import { inventorySlice } from '../store/inventory';
import { Items } from '../store/items';
import { InventoryType, Slot, State } from '../typings';

export type ItemsPayload = { item: Slot; inventory?: InventoryType };

interface Payload {
  items?: ItemsPayload | ItemsPayload[];
  itemCount?: Record<string, number>;
  weightData?: { inventoryId: string; maxWeight: number };
  slotsData?: { inventoryId: string; slots: number; grid?: { w: number; h: number } };
}

export const refreshSlotsReducer: CaseReducer<State, PayloadAction<Payload>> = (state, action) => {
  if (action.payload.items) {
    if (!Array.isArray(action.payload.items)) action.payload.items = [action.payload.items];
    const curTime = Math.floor(Date.now() / 1000);

    Object.values(action.payload.items)
      .filter((data) => !!data)
      .forEach((data) => {
        // klsh: updates addressed to the linked equipment inventory (id 'equip:<owner>')
        const isEquipment = !!state.equipmentInventory && data.inventory === state.equipmentInventory.id;

        const isBackpack = !!state.backpackInventory && data.inventory === state.backpackInventory.id;
        const isGround = !!state.groundInventory && data.inventory === state.groundInventory.id;

        const isOtherEquipment = !!state.otherEquipmentInventory && data.inventory === state.otherEquipmentInventory.id;
        const isOtherBackpack = !!state.otherBackpackInventory && data.inventory === state.otherBackpackInventory.id;

        const targetInventory = isOtherEquipment
          ? state.otherEquipmentInventory!
          : isOtherBackpack
            ? state.otherBackpackInventory!
            : isEquipment
          ? state.equipmentInventory!
          : isBackpack
            ? state.backpackInventory!
            : isGround
              ? state.groundInventory!
              : data.inventory
            ? data.inventory !== InventoryType.PLAYER
              ? state.rightInventory
              : state.leftInventory
            : state.leftInventory;

        data.item.durability = itemDurability(data.item.metadata, curTime);
        // klsh: identifiers above the current length (grid inventories) must not leave holes
        while (targetInventory.items.length < data.item.slot - 1)
          targetInventory.items.push({ slot: targetInventory.items.length + 1 });

        targetInventory.items[data.item.slot - 1] = data.item;
      });

    // Janky workaround to force a state rerender for crafting inventory to
    // run canCraftItem checks
    if (state.rightInventory.type === InventoryType.CRAFTING) {
      state.rightInventory = { ...state.rightInventory };
    }
  }

  if (action.payload.itemCount) {
    const items = Object.entries(action.payload.itemCount);

    for (let i = 0; i < items.length; i++) {
      const item = items[i][0];
      const count = items[i][1];

      if (Items[item]!) {
        Items[item]!.count += count;
      } else console.log(`Item data for ${item} is undefined`);
    }
  }

  // Refresh maxWeight when SetMaxWeight is ran while an inventory is open
  if (action.payload.weightData) {
    const inventoryId = action.payload.weightData.inventoryId;
    const inventoryMaxWeight = action.payload.weightData.maxWeight;
    const inv =
      inventoryId === state.leftInventory.id
        ? 'leftInventory'
        : inventoryId === state.rightInventory.id
          ? 'rightInventory'
          : null;

    if (!inv) return;

    state[inv].maxWeight = inventoryMaxWeight;
  }

  if (action.payload.slotsData) {
    const { inventoryId } = action.payload.slotsData;
    const { slots, grid } = action.payload.slotsData;

    // klsh: grid inventories (any of the four) only grow or shrink; nothing is rebuilt
    if (grid) {
      const target = [state.leftInventory, state.rightInventory, state.backpackInventory, state.groundInventory, state.otherBackpackInventory].find(
        (inventory) => inventory && String(inventory.id) === String(inventoryId)
      );

      if (!target) return;

      target.grid = { ...target.grid, ...grid };
      target.slots = slots;

      while (target.items.length < slots) target.items.push({ slot: target.items.length + 1 });

      return;
    }

    const inv =
      inventoryId === state.leftInventory.id
        ? 'leftInventory'
        : inventoryId === state.rightInventory.id
          ? 'rightInventory'
          : null;

    if (!inv) return;

    state[inv].slots = slots;
    inventorySlice.caseReducers.setupInventory(state, {
      type: 'setupInventory',
      payload: {
        leftInventory: inv === 'leftInventory' ? state[inv] : undefined,
        rightInventory: inv === 'rightInventory' ? state[inv] : undefined,
        equipmentInventory: state.equipmentInventory, // klsh: keep the equipment panel
        backpackInventory: state.backpackInventory, // klsh
        groundInventory: state.groundInventory, // klsh
        otherEquipmentInventory: state.otherEquipmentInventory, // klsh
        otherBackpackInventory: state.otherBackpackInventory, // klsh
      },
    });
  }
};
