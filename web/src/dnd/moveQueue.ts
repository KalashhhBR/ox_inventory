// klsh: moves asked while another one is still running (timed transfers, clothing changes) wait in a
// queue and run in the order they were asked. The server validates each one when its turn comes, so a
// queued move that no longer makes sense is simply refused and the queue goes on.
import { useSyncExternalStore } from 'react';
import { store } from '../store';
import { validateMove } from '../thunks/validateItems';
import { fetchNui } from '../utils/fetchNui';

type Move = Parameters<typeof validateMove>[0];

let queue: Move[] = [];
let running = false;
let snapshot: Move[] = [];
const listeners = new Set<() => void>();

let busy = false;

const notify = () => {
  snapshot = [...queue];

  // the client keeps the inventory open (only hidden) for as long as there are moves to run
  if (busy !== queue.length > 0) {
    busy = queue.length > 0;
    fetchNui('klshQueue', { busy });
  }

  listeners.forEach((listener) => listener());
};

const pump = async () => {
  if (running) return;

  running = true;

  while (queue.length > 0) {
    const move = queue[0];

    await store.dispatch(validateMove(move));

    // cleared while this move was running: nothing left to remove
    if (queue[0] === move) queue.shift();

    notify();
  }

  running = false;
};

export const enqueueMove = (move: Move) => {
  // one pending move per item
  if (queue.some((queued) => queued.fromType === move.fromType && queued.fromSlot === move.fromSlot)) return;

  queue.push(move);
  notify();
  pump();
};

// drops everything that has not started yet (the running move is cancelled by the caller)
export const clearMoveQueue = () => {
  if (queue.length === 0) return;

  queue = [];
  notify();
};

const subscribe = (listener: () => void) => {
  listeners.add(listener);

  return () => {
    listeners.delete(listener);
  };
};

// 0 when the item has no pending move; 1 is the one running now, 2 the next, and so on
export const useQueuePosition = (inventoryType: string, slot: number) =>
  useSyncExternalStore(
    subscribe,
    () => snapshot.findIndex((move) => move.fromType === inventoryType && move.fromSlot === slot) + 1
  );
