// klsh: one item drawn on a grid inventory, taking width x height cells
import React, { useRef, useState } from 'react';
import { useDrag } from 'react-dnd';
import { DragSource, Inventory, InventoryType } from '../../typings';
import { useAppDispatch, useAppSelector, store } from '../../store';
import { selectHotbar } from '../../store/inventory';
import { hotbarIndexOf } from '../../helpers/hotbar';
import { Items } from '../../store/items';
import { getItemUrl, getTargetInventory } from '../../helpers';
import { footprint, GridItem as GridItemData, itemSize } from '../../helpers/grid';
import { setDragRotated } from '../../store/gridDrag';
import { closeTooltip, openTooltip } from '../../store/tooltip';
import { openContextMenu } from '../../store/contextMenu';
import { onDrop } from '../../dnd/onDrop';
import { onGridDrop } from '../../dnd/onGridDrop';
import { onUse } from '../../dnd/onUse';
import useNuiEvent from '../../hooks/useNuiEvent';
import { fetchNui } from '../../utils/fetchNui';
import { clearMoveQueue, useQueuePosition } from '../../dnd/moveQueue';
import WeightBar from '../utils/WeightBar';

const GridItem: React.FC<{ item: GridItemData; inventory: Inventory }> = ({ item, inventory }) => {
  const dispatch = useAppDispatch();
  const timerRef = useRef<number | null>(null);
  const size = itemSize(item.name);
  const [w, h] = footprint(size, item.rotated);

  const [{ isDragging }, drag] = useDrag<DragSource, void, { isDragging: boolean }>(
    () => ({
      type: 'SLOT',
      collect: (monitor) => ({ isDragging: monitor.isDragging() }),
      item: () => {
        setDragRotated(!!item.rotated);

        return {
          inventory: inventory.type,
          item: { name: item.name, slot: item.slot },
          image: `url(${getItemUrl(item)})`,
          size,
        };
      },
    }),
    [inventory.type, item]
  );

  // timed move in progress on this item (heavy transfer or clothing change); clicking cancels
  const [progress, setProgress] = useState<number | undefined>(undefined);

  useNuiEvent<{ inventory?: string | number; slot?: number; duration?: number }>('transferProgress', (data) => {
    const isThisItem =
      !!data && data.slot === item.slot && data.inventory !== undefined && String(data.inventory) === String(inventory.id);

    setProgress(isThisItem ? data.duration : undefined);
  });

  useNuiEvent('closeInventory', () => setProgress(undefined));

  // klsh: place of this item in the queue of pending moves (2 = next after the one running)
  const queued = useQueuePosition(inventory.type, item.slot);

  const clearTimer = () => {
    if (timerRef.current) {
      clearTimeout(timerRef.current);
      timerRef.current = null;
    }
  };

  const handleClick = (event: React.MouseEvent<HTMLDivElement>) => {
    dispatch(closeTooltip());
    clearTimer();

    if (event.ctrlKey) {
      const source = { item: { name: item.name, slot: item.slot }, inventory: inventory.type };
      const { targetInventory } = getTargetInventory(store.getState().inventory, inventory.type);

      if (targetInventory.grid) onGridDrop(source, targetInventory, { action: 'quick' });
      else if (targetInventory.type !== InventoryType.SHOP && targetInventory.type !== InventoryType.CRAFTING)
        onDrop(source);
    } else if (event.altKey && inventory.type === InventoryType.PLAYER) {
      onUse(item);
    }
  };

  const handleContext = (event: React.MouseEvent<HTMLDivElement>) => {
    event.preventDefault();

    if (inventory.type !== InventoryType.PLAYER) return;

    dispatch(openContextMenu({ item, coords: { x: event.clientX, y: event.clientY } }));
  };

  const hotbar = useAppSelector(selectHotbar);
  const hotkey = inventory.type === InventoryType.PLAYER ? hotbarIndexOf(hotbar, item) : 0;

  return (
    <div
      ref={(element) => {
        drag(element);
      }}
      className="grid-item"
      onClick={handleClick}
      onContextMenu={handleContext}
      onMouseEnter={() => {
        timerRef.current = window.setTimeout(() => {
          dispatch(openTooltip({ item, inventoryType: inventory.type }));
        }, 500) as unknown as number;
      }}
      onMouseLeave={() => {
        dispatch(closeTooltip());
        clearTimer();
      }}
      style={{
        left: `calc(${item.x - 1} * var(--grid-cell))`,
        top: `calc(${item.y - 1} * var(--grid-cell))`,
        width: `calc(${w} * var(--grid-cell))`,
        height: `calc(${h} * var(--grid-cell))`,
        opacity: isDragging ? 0.35 : 1,
      }}
    >
      <div
        className="grid-item-image"
        style={{
          backgroundImage: `url(${getItemUrl(item)})`,
          // the picture keeps the item's own proportions and turns with it
          width: `calc(${size[0]} * var(--grid-cell))`,
          height: `calc(${size[1]} * var(--grid-cell))`,
          transform: item.rotated ? 'translate(-50%, -50%) rotate(90deg)' : 'translate(-50%, -50%)',
        }}
      />
      {hotkey > 0 && <div className="grid-item-hotkey">{hotkey}</div>}
      {item.count > 1 && <div className="grid-item-count">{item.count.toLocaleString('en-us')}</div>}
      {item.durability !== undefined && (
        <div className="grid-item-durability">
          <WeightBar percent={item.durability} durability />
        </div>
      )}
      {w * h > 1 && (
        <div className="grid-item-label">{item.metadata?.label || Items[item.name]?.label || item.name}</div>
      )}
      {queued > 1 && progress === undefined && (
        <div
          className="slot-queued"
          onClick={(event) => {
            event.stopPropagation();
            clearMoveQueue();
          }}
        >
          {queued - 1}
        </div>
      )}
      {progress !== undefined && (
        <div
          className="slot-progress"
          onClick={(event) => {
            event.stopPropagation();
            clearMoveQueue();
            fetchNui('cancelEquip');
          }}
        >
          <div className="slot-progress-fill" style={{ animationDuration: `${progress}ms` }} />
          <div className="slot-progress-cancel">✕</div>
        </div>
      )}
    </div>
  );
};

export default React.memo(GridItem);
