// klsh: divides a stack of the main inventory: the chosen amount leaves the stack and takes the
// first free place. It is an ordinary move, validated by the server like any other.
import React, { useEffect, useState } from 'react';
import { store, useAppSelector } from '../../store';
import { selectLeftInventory } from '../../store/inventory';
import { closeSplit, useSplitItem } from '../../store/split';
import { enqueueMove } from '../../dnd/moveQueue';
import { fits, footprint, gridItems, itemSize } from '../../helpers/grid';
import { formatCount, itemLabel } from '../../helpers/format';
import { Locale } from '../../store/locale';
import { typingProps } from '../../hooks/useTyping';
import { InventoryType } from '../../typings';

const SplitDialog: React.FC = () => {
  const item = useSplitItem();
  const inventory = useAppSelector(selectLeftInventory);
  const [amount, setAmount] = useState(1);
  const current = item ? inventory.items[item.slot - 1] : undefined;
  const total = current && current.name === item?.name ? current.count || 0 : 0;
  const max = total - 1;

  useEffect(() => {
    if (item) setAmount(Math.max(1, Math.floor(item.count / 2)));
  }, [item]);

  // the stack changed under the dialog and can no longer be divided
  useEffect(() => {
    if (item && max < 1) closeSplit();
  }, [item, max]);

  if (!item || max < 1) return null;

  const clamp = (value: number) => Math.max(1, Math.min(max, value || 1));

  const confirm = () => {
    const grid = store.getState().inventory.leftInventory.grid;
    const placed = gridItems(store.getState().inventory.leftInventory);
    const size = itemSize(item.name);

    closeSplit();

    if (!grid) return;

    for (const rotated of size[0] === size[1] ? [false] : [!!item.rotated, !item.rotated]) {
      const [w, h] = footprint(size, rotated);

      for (let y = 1; y <= grid.h - h + 1; y++)
        for (let x = 1; x <= grid.w - w + 1; x++)
          if (fits(placed, grid, x, y, w, h))
            return enqueueMove({
              fromSlot: item.slot,
              fromType: InventoryType.PLAYER,
              toType: InventoryType.PLAYER,
              count: clamp(amount),
              toX: x,
              toY: y,
              rotated,
            });
    }
  };

  return (
    <div className="k-modal" onMouseDown={(event) => event.target === event.currentTarget && closeSplit()}>
      <div className="k-dialog">
        <h3>{Locale.ui_split || 'Split'}</h3>
        <p>
          {itemLabel(item)} · ×{formatCount(total)}
        </p>
        <input
          className="k-dialog-input"
          type="text"
          inputMode="numeric"
          autoFocus
          value={amount}
          onChange={(event) => setAmount(clamp(parseInt(event.target.value.replace(/\D/g, ''), 10)))}
          onKeyUp={(event) => {
            if (event.key !== 'Escape' && event.key !== 'Enter') return;

            event.stopPropagation();
            event.key === 'Enter' ? confirm() : closeSplit();
          }}
          {...typingProps}
        />
        <input type="range" min={1} max={max} value={amount} onChange={(event) => setAmount(clamp(Number(event.target.value)))} />
        <div className="k-dialog-row">
          {[2, 3, 4].map((part) => (
            <button key={part} type="button" onClick={() => setAmount(clamp(Math.floor(total / part)))}>
              {['½', '⅓', '¼'][part - 2]}
            </button>
          ))}
        </div>
        <div className="k-dialog-row">
          <button type="button" onClick={closeSplit}>
            {Locale.ui_cancel || 'Cancel'}
          </button>
          <button type="button" className="k-primary" onClick={confirm}>
            {Locale.ui_confirm || 'Confirm'}
          </button>
        </div>
      </div>
    </div>
  );
};

export default SplitDialog;
