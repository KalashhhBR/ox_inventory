// klsh: the player's wallet (clean and dirty money), next to the shortcuts. Each line is the wallet
// slot of the main inventory: it drags like any item (Shift = half, or the typed quantity) and money
// dropped on it goes back to the wallet.
import React from 'react';
import { useDrag, useDrop } from 'react-dnd';
import { DragSource, Inventory, Slot } from '../../typings';
import { useAppDispatch, useAppSelector } from '../../store';
import { openContextMenu } from '../../store/contextMenu';
import { selectLeftInventory } from '../../store/inventory';
import { getItemUrl, isSlotWithItem } from '../../helpers';
import { Items } from '../../store/items';
import { Locale } from '../../store/locale';
import { onDrop } from '../../dnd/onDrop';
import { formatCount } from '../../helpers/format';

const ACCOUNTS = ['money', 'black_money'];

const WalletRow: React.FC<{ inventory: Inventory; slot: Slot; account: string }> = ({ inventory, slot, account }) => {
  const filled = isSlotWithItem(slot);
  const dispatch = useAppDispatch();

  const [{ isDragging }, drag] = useDrag<DragSource, void, { isDragging: boolean }>(
    () => ({
      type: 'SLOT',
      collect: (monitor) => ({ isDragging: monitor.isDragging() }),
      canDrag: () => filled,
      item: () =>
        filled
          ? { inventory: inventory.type, item: { name: slot.name, slot: slot.slot }, image: `url(${getItemUrl(slot)})` }
          : null,
    }),
    [inventory.type, slot]
  );

  const [{ isOver }, drop] = useDrop<DragSource, void, { isOver: boolean }>(
    () => ({
      accept: 'SLOT',
      collect: (monitor) => ({ isOver: monitor.isOver() && monitor.canDrop() }),
      // only its own kind of money, and not the line being dragged
      canDrop: (source) =>
        source.item.name === (slot.name || account) && !(source.inventory === inventory.type && source.item.slot === slot.slot),
      drop: (source) => onDrop(source, { inventory: inventory.type, item: { slot: slot.slot } }),
    }),
    [inventory.type, slot, account]
  );

  const name = slot.name || account;

  return (
    <div
      ref={(element) => {
        drag(drop(element));
      }}
      className={`k-money${isOver ? ' k-money-over' : ''}`}
      onContextMenu={(event) => {
        // klsh: the same menu as any item of the pockets (give, throw, drop, quick move)
        event.preventDefault();

        if (isSlotWithItem(slot)) dispatch(openContextMenu({ item: slot, coords: { x: event.clientX, y: event.clientY } }));
      }}
      style={{ opacity: isDragging ? 0.4 : 1 }}
    >
      <span>
        <i className={name === 'money' ? undefined : 'k-money-dirty'} />
        {Items[name]?.label || name}
      </span>
      <b>
        {Locale.$ || '$'} {formatCount(slot.count || 0)}
      </b>
    </div>
  );
};

const WalletPanel: React.FC = () => {
  const inventory = useAppSelector(selectLeftInventory);
  const first = inventory.grid?.wallet;

  if (first === undefined) return null;

  return (
    <div className="k-wallet">
      <p className="k-cap">{Locale.ui_wallet || 'Wallet'}</p>
      {ACCOUNTS.map((account, index) => (
        <WalletRow
          key={account}
          inventory={inventory}
          slot={inventory.items[first + index] || { slot: first + index + 1 }}
          account={account}
        />
      ))}
    </div>
  );
};

export default WalletPanel;
