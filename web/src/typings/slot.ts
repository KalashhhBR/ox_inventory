export type Slot = {
  slot: number;
  name?: string;
  count?: number;
  weight?: number;
  metadata?: {
    [key: string]: any;
  };
  durability?: number;
  // klsh: grid position (top-left cell, 1-based) and 90 degree rotation
  x?: number;
  y?: number;
  rotated?: boolean;
};

export type SlotWithItem = Slot & {
  name: string;
  count: number;
  weight: number;
  durability?: number;
  price?: number;
  currency?: string;
  ingredients?: { [key: string]: number };
  duration?: number;
  image?: string;
  grade?: number | number[];
};
