// klsh: what a drop would do where the dragged item is now ("wear", "use", "ground", a hotkey),
// shown as a tag on the drag preview. Each drop target sets its own entry while hovered.
import { useSyncExternalStore } from 'react';

const hints = new Map<string, string>();
let current: string | undefined;
const listeners = new Set<() => void>();

export const setDragHint = (owner: string, text?: string) => {
  if (text) hints.set(owner, text);
  else hints.delete(owner);

  const next = Array.from(hints.values()).pop();

  if (next === current) return;

  current = next;
  listeners.forEach((listener) => listener());
};

const subscribe = (listener: () => void) => {
  listeners.add(listener);

  return () => {
    listeners.delete(listener);
  };
};

export const useDragHint = () => useSyncExternalStore(subscribe, () => current);
