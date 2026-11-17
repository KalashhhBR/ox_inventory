// klsh: outfit bag opened on the right: one slot per clothing category
import React from 'react';
import { Inventory } from '../../typings';
import EquipmentSlot from './EquipmentSlot';

const OutfitPanel: React.FC<{ inventory: Inventory }> = ({ inventory }) => (
  <div className="inventory-grid-wrapper">
    <div className="inventory-grid-header-wrapper">
      <p>{inventory.label}</p>
    </div>
    <div className="search-equipment outfit-panel">
      {inventory.categories?.map((category, index) =>
        category.hidden ? null : (
          <EquipmentSlot
            key={`outfit-${index}`}
            inventory={inventory}
            item={inventory.items[index] || { slot: index + 1 }}
            category={category}
          />
        )
      )}
    </div>
  </div>
);

export default OutfitPanel;
