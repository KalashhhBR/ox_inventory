import { createSlice, current, isFulfilled, isPending, isRejected, PayloadAction } from '@reduxjs/toolkit';
import type { RootState } from '.';
import {
  moveSlotsReducer,
  refreshSlotsReducer,
  setupInventoryReducer,
  stackSlotsReducer,
  swapSlotsReducer,
} from '../reducers';
import { Inventory, State } from '../typings';
import { normalizeLinkedInventory } from '../helpers';

const initialState: State = {
  leftInventory: {
    id: '',
    type: '',
    slots: 0,
    maxWeight: 0,
    items: [],
  },
  rightInventory: {
    id: '',
    type: '',
    slots: 0,
    maxWeight: 0,
    items: [],
  },
  additionalMetadata: new Array(),
  hotbar: [false, false, false, false, false],
  itemAmount: 0,
  shiftPressed: false,
  isBusy: false,
};

export const inventorySlice = createSlice({
  name: 'inventory',
  initialState,
  reducers: {
    stackSlots: stackSlotsReducer,
    swapSlots: swapSlotsReducer,
    setupInventory: setupInventoryReducer,
    moveSlots: moveSlotsReducer,
    refreshSlots: refreshSlotsReducer,
    setAdditionalMetadata: (state, action: PayloadAction<Array<{ metadata: string; value: string }>>) => {
      const metadata = [];

      for (let i = 0; i < action.payload.length; i++) {
        const entry = action.payload[i];
        if (!state.additionalMetadata.find((el) => el.value === entry.value)) metadata.push(entry);
      }

      state.additionalMetadata = [...state.additionalMetadata, ...metadata];
    },
    // klsh: hotbar shortcuts as kept by the client
    setHotbar: (state, action: PayloadAction<State['hotbar'] | undefined>) => {
      state.hotbar = Array.from(Array(5), (_, index) => action.payload?.[index] || false);
    },
    setItemAmount: (state, action: PayloadAction<number>) => {
      state.itemAmount = action.payload;
    },
    setShiftPressed: (state, action: PayloadAction<boolean>) => {
      state.shiftPressed = action.payload;
    },
    // klsh: the worn backpack changed while the inventory is open
    setBackpack: (state, action: PayloadAction<State['backpackInventory'] | false>) => {
      state.backpackInventory = action.payload ? normalizeLinkedInventory(action.payload) : undefined;
    },
    // klsh: the ground section now points to another drop (e.g. one just created)
    setGround: (state, action: PayloadAction<State['groundInventory'] | false>) => {
      state.groundInventory = action.payload ? normalizeLinkedInventory(action.payload) : undefined;
    },
    // klsh: the searched player's equipment or backpack changed
    setSearch: (state, action: PayloadAction<{ equipment?: Inventory | false; backpack?: Inventory | false }>) => {
      state.otherEquipmentInventory = action.payload.equipment ? normalizeLinkedInventory(action.payload.equipment) : undefined;
      state.otherBackpackInventory = action.payload.backpack ? normalizeLinkedInventory(action.payload.backpack) : undefined;
    },
    setContainerWeight: (state, action: PayloadAction<number>) => {
      const container = state.leftInventory.items.find((item) => item.metadata?.container === state.rightInventory.id);

      if (!container) return;

      container.weight = action.payload;
    },
  },
  extraReducers: (builder) => {
    builder.addMatcher(isPending, (state) => {
      state.isBusy = true;

      state.history = {
        leftInventory: current(state.leftInventory),
        rightInventory: current(state.rightInventory),
        equipmentInventory: state.equipmentInventory && current(state.equipmentInventory), // klsh
        backpackInventory: state.backpackInventory && current(state.backpackInventory), // klsh
        groundInventory: state.groundInventory && current(state.groundInventory), // klsh
      };
    });
    builder.addMatcher(isFulfilled, (state) => {
      state.isBusy = false;
    });
    builder.addMatcher(isRejected, (state) => {
      if (state.history && state.history.leftInventory && state.history.rightInventory) {
        state.leftInventory = state.history.leftInventory;
        state.rightInventory = state.history.rightInventory;
        state.equipmentInventory = state.history.equipmentInventory; // klsh
        state.backpackInventory = state.history.backpackInventory; // klsh
        state.groundInventory = state.history.groundInventory; // klsh
      }
      state.isBusy = false;
    });
  },
});

export const {
  setAdditionalMetadata,
  setItemAmount,
  setShiftPressed,
  setupInventory,
  swapSlots,
  moveSlots,
  stackSlots,
  refreshSlots,
  setContainerWeight,
  setBackpack,
  setSearch,
  setHotbar,
  setGround,
} = inventorySlice.actions;
export const selectLeftInventory = (state: RootState) => state.inventory.leftInventory;
export const selectRightInventory = (state: RootState) => state.inventory.rightInventory;
export const selectEquipmentInventory = (state: RootState) => state.inventory.equipmentInventory; // klsh
export const selectBackpackInventory = (state: RootState) => state.inventory.backpackInventory; // klsh
export const selectGroundInventory = (state: RootState) => state.inventory.groundInventory; // klsh
export const selectItemAmount = (state: RootState) => state.inventory.itemAmount;
export const selectOtherEquipment = (state: RootState) => state.inventory.otherEquipmentInventory;
export const selectOtherBackpack = (state: RootState) => state.inventory.otherBackpackInventory;
export const selectHotbar = (state: RootState) => state.inventory.hotbar;
export const selectIsBusy = (state: RootState) => state.inventory.isBusy;

export default inventorySlice.reducer;
