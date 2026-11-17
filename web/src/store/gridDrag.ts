// klsh: rotation of the item being dragged over a grid (toggled with R), shared by every grid area
import { useSyncExternalStore } from 'react';

let rotated = false;
const listeners = new Set<() => void>();

export const getDragRotated = () => rotated;

export const setDragRotated = (value: boolean) => {
  if (rotated === value) return;

  rotated = value;
  listeners.forEach((listener) => listener());
};

const subscribe = (listener: () => void) => {
  listeners.add(listener);

  return () => {
    listeners.delete(listener);
  };
};

export const useDragRotated = () => useSyncExternalStore(subscribe, getDragRotated);
