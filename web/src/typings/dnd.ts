import { Inventory } from './inventory';
import { Slot, SlotWithItem } from './slot';

export type DragSource = {
  item: Pick<SlotWithItem, 'slot' | 'name'>;
  inventory: Inventory['type'];
  image?: string;
  // klsh: grid footprint of the dragged item, before rotation
  size?: [number, number];
};

export type DropTarget = {
  item: Pick<Slot, 'slot'>;
  inventory: Inventory['type'];
};
