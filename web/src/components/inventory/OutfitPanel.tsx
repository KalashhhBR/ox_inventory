// klsh: outfit bag opened on the right: one slot per clothing category
import React from 'react';
import { Inventory } from '../../typings';
import EquipmentSlot from './EquipmentSlot';
import PanelHeader from './PanelHeader';

const OutfitPanel: React.FC<{ inventory: Inventory }> = ({ inventory }) => (
  <div className="k-sec">
    <PanelHeader label={inventory.label} />
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
