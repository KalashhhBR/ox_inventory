// klsh: equipment panel (clothing slots around a silhouette), shown left of the player's inventory
import React from 'react';
import { useAppSelector } from '../../store';
import { selectEquipmentInventory } from '../../store/inventory';
import EquipmentSlot from './EquipmentSlot';

// categories rendered in the left column; every other category goes to the right column
const LEFT_COLUMN = ['hat', 'mask', 'glasses', 'ears', 'neck', 'watch', 'bracelet'];

const EquipmentPanel: React.FC = () => {
  const equipment = useAppSelector(selectEquipmentInventory);

  if (!equipment || !equipment.categories || equipment.categories.length === 0) return null;

  const slots = equipment.categories.map((category, index) => ({
    category,
    item: equipment.items[index] || { slot: index + 1 },
  }));

  const left = LEFT_COLUMN.flatMap((name) => slots.filter((slot) => slot.category.name === name));
  const right = slots.filter((slot) => !LEFT_COLUMN.includes(slot.category.name));

  const renderColumn = (column: typeof slots) => (
    <div className="equipment-column">
      {column.map(({ category, item }) => (
        <EquipmentSlot key={`equipment-${item.slot}`} inventory={equipment} item={item} category={category} />
      ))}
    </div>
  );

  return (
    <div className="equipment-panel">
      <div className="inventory-grid-header-wrapper">
        <p>{equipment.label}</p>
      </div>
      <div className="equipment-body">
        {renderColumn(left)}
        <svg className="equipment-silhouette" viewBox="0 0 60 150" aria-hidden="true">
          <circle cx="30" cy="14" r="11" />
          <path d="M14 30h32a8 8 0 0 1 8 8v40a4 4 0 0 1-8 0V46h-2v94a6 6 0 0 1-12 0V92h-4v48a6 6 0 0 1-12 0V46h-2v32a4 4 0 0 1-8 0V38a8 8 0 0 1 8-8z" />
        </svg>
        {renderColumn(right)}
      </div>
    </div>
  );
};

export default EquipmentPanel;
