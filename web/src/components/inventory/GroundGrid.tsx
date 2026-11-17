// klsh: the ground (nearest drop, or an empty area that creates one), shown below the secondary inventory
import React, { useMemo } from 'react';
import { useAppSelector } from '../../store';
import { selectGroundInventory } from '../../store/inventory';
import { getTotalWeight } from '../../helpers';
import WeightBar from '../utils/WeightBar';
import InventorySlot from './InventorySlot';
import GridArea from './GridArea';

const GroundGrid: React.FC = () => {
  const ground = useAppSelector(selectGroundInventory);

  const weight = useMemo(() => (ground ? getTotalWeight(ground.items) : 0), [ground]);

  if (!ground) return null;

  const maxWeight = ground.maxWeight || 0;

  return (
    <div className="inventory-grid-wrapper backpack-grid-wrapper">
      <div>
        <div className="inventory-grid-header-wrapper">
          <p>{ground.label}</p>
          <p>
            {Math.floor(weight) / 1000}/{maxWeight / 1000}kg
          </p>
        </div>
        <WeightBar percent={maxWeight ? (weight / maxWeight) * 100 : 0} />
      </div>
      {ground.grid ? (
        <GridArea inventory={ground} maxRows={3} />
      ) : (
      <div className="inventory-grid-container backpack-grid-container">
        {ground.items.map((item) => (
          <InventorySlot
            key={`${ground.type}-${ground.id}-${item.slot}`}
            item={item}
            inventoryType={ground.type}
            inventoryGroups={ground.groups}
            inventoryId={ground.id}
          />
        ))}
      </div>
      )}
    </div>
  );
};

export default GroundGrid;
