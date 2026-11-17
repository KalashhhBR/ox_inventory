import { Inventory } from './inventory';
import { Slot } from './slot';

// klsh: hotbar shortcut; by slot for items that do not stack, by name for stackable ones
export type HotbarEntry = { name: string; slot?: number };

export type State = {
  leftInventory: Inventory;
  rightInventory: Inventory;
  equipmentInventory?: Inventory; // klsh
  backpackInventory?: Inventory; // klsh
  groundInventory?: Inventory; // klsh
  otherEquipmentInventory?: Inventory; // klsh: search
  otherBackpackInventory?: Inventory; // klsh: search
  hotbar: Array<HotbarEntry | false | null>; // klsh: 5 shortcuts, sent by the client
  itemAmount: number;
  shiftPressed: boolean;
  isBusy: boolean;
  additionalMetadata: Array<{ metadata: string; value: string }>;
  history?: {
    leftInventory: Inventory;
    rightInventory: Inventory;
    equipmentInventory?: Inventory; // klsh
    backpackInventory?: Inventory; // klsh
    groundInventory?: Inventory; // klsh
  };
};
