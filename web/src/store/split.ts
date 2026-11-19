// klsh: the stack being divided by the split dialog
import { useSyncExternalStore } from 'react';
import { SlotWithItem } from '../typings';

let item: SlotWithItem | null = null;
const listeners = new Set<() => void>();

const set = (value: SlotWithItem | null) => {
  item = value;
  listeners.forEach((listener) => listener());
};

export const openSplit = (value: SlotWithItem) => set(value);
export const closeSplit = () => set(null);

const subscribe = (listener: () => void) => {
  listeners.add(listener);

  return () => {
    listeners.delete(listener);
  };
};

export const useSplitItem = () => useSyncExternalStore(subscribe, () => item);
