// klsh: the character in the middle of the screen: an outline with the clothing slots on both sides.
// Dropping an item anywhere on it wears or uses the item (dnd/onBody.ts).
import React, { useEffect } from 'react';
import { useDrop } from 'react-dnd';
import { useAppSelector } from '../../store';
import { selectEquipmentInventory } from '../../store/inventory';
import { DragSource } from '../../typings';
import { bodyAction, onBody } from '../../dnd/onBody';
import { setDragHint } from '../../store/dragHint';
import { Locale } from '../../store/locale';
import EquipmentSlot from './EquipmentSlot';

// categories rendered in the left column; every other category goes to the right column
const LEFT_COLUMN = ['hat', 'mask', 'glasses', 'ears', 'neck', 'watch', 'bracelet'];

const EquipmentPanel: React.FC = () => {
  const equipment = useAppSelector(selectEquipmentInventory);

  const [{ action }, drop] = useDrop<DragSource, void, { action?: 'wear' | 'use' }>(
    () => ({
      accept: 'SLOT',
      collect: (monitor) => ({
        action: monitor.isOver({ shallow: true }) ? bodyAction(monitor.getItem()) : undefined,
      }),
      drop: (source, monitor) => {
        // a slot under the pointer already took it
        if (!monitor.didDrop()) onBody(source);
      },
    }),
    []
  );

  useEffect(() => {
    setDragHint('body', action === 'wear' ? Locale.ui_wear || 'Wear' : action === 'use' ? Locale.ui_use || 'Use' : undefined);

    return () => setDragHint('body');
  }, [action]);

  if (!equipment || !equipment.categories || equipment.categories.length === 0) return null;

  const slots = equipment.categories.map((category, index) => ({
    category,
    item: equipment.items[index] || { slot: index + 1 },
  }));

  const left = LEFT_COLUMN.flatMap((name) => slots.filter((slot) => slot.category.name === name));
  const right = slots.filter((slot) => !LEFT_COLUMN.includes(slot.category.name));

  const renderColumn = (column: typeof slots, side: string) => (
    <div className={`k-eq-column k-eq-${side}`}>
      {column.map(({ category, item }) => (
        <div key={`equipment-${item.slot}`}>
          <p className="k-cap">{category.label}</p>
          <EquipmentSlot inventory={equipment} item={item} category={category} />
        </div>
      ))}
    </div>
  );

  return (
    <div
      ref={(element) => {
        drop(element);
      }}
      className={`k-body${action ? ' k-body-over' : ''}`}
    >
      {renderColumn(left, 'left')}
      <svg className="k-outline" viewBox="0 0 120 300" aria-hidden="true">
        <circle cx="60" cy="30" r="20" />
        <path d="M34 62h52l14 96-14 4-8-58v186H62V180h-4v110H42V104l-8 58-14-4z" />
      </svg>
      {renderColumn(right, 'right')}
    </div>
  );
};

export default EquipmentPanel;
