// klsh: worn backpack, shown as an extra section below the player's inventory
import React, { useMemo } from 'react';
import { useAppSelector } from '../../store';
import { selectBackpackInventory } from '../../store/inventory';
import { getTotalWeight } from '../../helpers';
import WeightBar from '../utils/WeightBar';
import InventorySlot from './InventorySlot';
import GridArea from './GridArea';

const BackpackGrid: React.FC = () => {
  const backpack = useAppSelector(selectBackpackInventory);

  const weight = useMemo(() => (backpack ? getTotalWeight(backpack.items) : 0), [backpack]);

  if (!backpack) return null;

  const maxWeight = backpack.maxWeight || 0;
  const reduction = Math.round((backpack.reduction || 0) * 100);

  return (
    <div className="inventory-grid-wrapper backpack-grid-wrapper">
      <div>
        <div className="inventory-grid-header-wrapper">
          <p>{backpack.label}</p>
          <p>
            {Math.floor(weight) / 1000}/{maxWeight / 1000}kg{reduction > 0 ? ` · -${reduction}%` : ''}
          </p>
        </div>
        <WeightBar percent={maxWeight ? (weight / maxWeight) * 100 : 0} />
      </div>
      {backpack.grid ? (
        <GridArea inventory={backpack} maxRows={4} />
      ) : (
      <div className="inventory-grid-container backpack-grid-container">
        {backpack.items.map((item) => (
          <InventorySlot
            key={`${backpack.type}-${backpack.id}-${item.slot}`}
            item={item}
            inventoryType={backpack.type}
            inventoryGroups={backpack.groups}
            inventoryId={backpack.id}
          />
        ))}
      </div>
      )}
    </div>
  );
};

export default BackpackGrid;
