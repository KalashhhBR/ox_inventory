// klsh: the 5 hotbar shortcuts. Drag an item from the player's inventory onto one to assign its key;
// right click clears it. The item stays where it is in the grid.
import React from 'react';
import { useDrop } from 'react-dnd';
import { DragSource, InventoryType, State } from '../../typings';
import { useAppSelector } from '../../store';
import { selectHotbar, selectLeftInventory } from '../../store/inventory';
import { resolveHotbar } from '../../helpers/hotbar';
import { getItemUrl } from '../../helpers';
import { Items } from '../../store/items';
import { Locale } from '../../store/locale';
import { fetchNui } from '../../utils/fetchNui';

const HotbarSlot: React.FC<{ index: number; entry: State['hotbar'][number] }> = ({ index, entry }) => {
  const items = useAppSelector(selectLeftInventory).items;
  const { item, count } = resolveHotbar(entry, items);

  const [{ isOver, canDrop }, drop] = useDrop<DragSource, void, { isOver: boolean; canDrop: boolean }>(
    () => ({
      accept: 'SLOT',
      collect: (monitor) => ({ isOver: monitor.isOver(), canDrop: monitor.canDrop() }),
      canDrop: (source) => source.inventory === InventoryType.PLAYER,
      drop: (source) => {
        fetchNui('setHotbar', { index, slot: source.item.slot });
      },
    }),
    [index]
  );

  const name = entry ? entry.name : undefined;
  const image = item ? getItemUrl(item) : name ? getItemUrl(name) : undefined;

  return (
    <div
      ref={(element) => {
        drop(element);
      }}
      className={`hotbar-shortcut${isOver && canDrop ? ' hotbar-shortcut-over' : ''}`}
      title={name ? Items[name]?.label || name : undefined}
      onContextMenu={(event) => {
        event.preventDefault();

        if (entry) fetchNui('setHotbar', { index });
      }}
    >
      <div className="grid-item-hotkey">{index}</div>
      {image && (
        <div
          className="hotbar-shortcut-image"
          style={{ backgroundImage: `url(${image})`, opacity: item ? 1 : 0.3 }}
        />
      )}
      {entry && !entry.slot && <div className="grid-item-count">{count.toLocaleString('en-us')}</div>}
    </div>
  );
};

const HotbarPanel: React.FC = () => {
  const hotbar = useAppSelector(selectHotbar);

  return (
    <div className="hotbar-panel">
      <p>{Locale.ui_hotbar || 'Hotbar'}</p>
      <div className="hotbar-shortcuts">
        {hotbar.map((entry, index) => (
          <HotbarSlot key={`shortcut-${index}`} index={index + 1} entry={entry} />
        ))}
      </div>
    </div>
  );
};

export default HotbarPanel;
