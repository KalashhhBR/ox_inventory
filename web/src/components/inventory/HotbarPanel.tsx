// klsh: the 5 hotbar shortcuts. Drag an item from the player's inventory onto one to assign its key;
// right click clears it. The item stays where it is in the grid.
import React, { useEffect } from 'react';
import { useDrop } from 'react-dnd';
import { DragSource, InventoryType, State } from '../../typings';
import { useAppSelector } from '../../store';
import { selectHotbar, selectLeftInventory } from '../../store/inventory';
import { resolveHotbar } from '../../helpers/hotbar';
import { getItemUrl } from '../../helpers';
import { Items } from '../../store/items';
import { Locale } from '../../store/locale';
import { fetchNui } from '../../utils/fetchNui';
import { formatCount } from '../../helpers/format';
import { setDragHint } from '../../store/dragHint';

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

  // klsh: the dragged item says which key it would take
  useEffect(() => {
    setDragHint(`hotbar-${index}`, isOver && canDrop ? `${Locale.ui_hotkey || 'Key'} ${index}` : undefined);

    return () => setDragHint(`hotbar-${index}`);
  }, [isOver, canDrop, index]);

  const name = entry ? entry.name : undefined;
  const image = item ? getItemUrl(item) : name ? getItemUrl(name) : undefined;

  return (
    <div
      ref={(element) => {
        drop(element);
      }}
      className={`hotbar-shortcut${entry ? ' hotbar-shortcut-set' : ''}${isOver && canDrop ? ' hotbar-shortcut-over' : ''}`}
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
      {entry && !entry.slot && <div className="grid-item-count">{formatCount(count)}</div>}
    </div>
  );
};

const HotbarPanel: React.FC = () => {
  const hotbar = useAppSelector(selectHotbar);

  return (
    <div className="hotbar-panel">
      <p className="k-cap">{Locale.ui_hotbar || 'Hotbar'}</p>
      <div className="hotbar-shortcuts">
        {hotbar.map((entry, index) => (
          <HotbarSlot key={`shortcut-${index}`} index={index + 1} entry={entry} />
        ))}
      </div>
    </div>
  );
};

export default HotbarPanel;
