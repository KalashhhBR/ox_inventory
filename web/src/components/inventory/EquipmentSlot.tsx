// klsh: one equipment slot (reuses the upstream slot for drag and drop, tooltip and item rendering)
import React from 'react';
import { EquipmentCategory, Inventory, Slot } from '../../typings';
import { imagepath } from '../../store/imagepath';
import InventorySlot from './InventorySlot';

interface Props {
  inventory: Inventory;
  item: Slot;
  category: EquipmentCategory;
}

const EquipmentSlot: React.FC<Props> = ({ inventory, item, category }) => {
  const isEmpty = item.name === undefined;

  return (
    <div className={`equipment-slot${isEmpty ? ' equipment-slot-empty' : ''}`} title={category.label}>
      {isEmpty && (
        <>
          <div
            className="equipment-slot-ghost"
            style={{ backgroundImage: `url(${imagepath}/clothing_${category.name}.png)` }}
          />
          <div className="equipment-slot-label">{category.label}</div>
        </>
      )}
      <InventorySlot item={item} inventoryType={inventory.type} inventoryGroups={inventory.groups} inventoryId={inventory.id} />
    </div>
  );
};

export default React.memo(EquipmentSlot);
