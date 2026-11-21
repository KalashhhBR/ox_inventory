import { Slot } from './slot';

export enum InventoryType {
  PLAYER = 'player',
  SHOP = 'shop',
  CONTAINER = 'container',
  CRAFTING = 'crafting',
  EQUIPMENT = 'equipment', // klsh
  BACKPACK = 'backpack', // klsh: worn backpack shown below the player's inventory
  GROUND = 'ground', // klsh: ground shown below the secondary inventory
  OTHER_EQUIPMENT = 'otherequipment', // klsh: clothing of the player being searched
  OTHER_BACKPACK = 'otherbackpack', // klsh: worn backpack of the player being searched
}

export type Inventory = {
  id: string;
  type: string;
  slots: number;
  items: Slot[];
  maxWeight?: number;
  label?: string;
  groups?: Record<string, number>;
  // klsh: equipment inventory only; index = slot - 1
  categories?: EquipmentCategory[];
  // klsh: player inventory only; moves between inventories at or above this weight (g) take time
  transferMinWeight?: number;
  // klsh: worn backpack only
  reduction?: number;
  baseWeight?: number;
  // klsh: grid inventories; h includes extra legacy rows; wallet = number of cells when the last two
  // identifiers are the wallet slots (player only)
  grid?: { w: number; h: number; wallet?: number };
  // klsh: ground with more than one drop within reach (index 0 = none of them shown)
  nav?: { index: number; count: number };
  // klsh: a drop with a name of its own (not shown as "Ground")
  named?: boolean;
};

export type EquipmentCategory = {
  name: string;
  label: string;
  items: string[];
  // klsh: outfit bag: categories without a slot (vest, backpack)
  hidden?: boolean;
};
