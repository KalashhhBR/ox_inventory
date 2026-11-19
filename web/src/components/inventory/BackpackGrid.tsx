// klsh: worn backpack, shown as an extra section below the player's inventory
import React, { useMemo, useState } from 'react';
import { useAppSelector } from '../../store';
import { selectBackpackInventory } from '../../store/inventory';
import { getTotalWeight } from '../../helpers';
import { formatKg } from '../../helpers/format';
import PanelHeader from './PanelHeader';
import InventorySlot from './InventorySlot';
import GridArea from './GridArea';

const BackpackGrid: React.FC = () => {
  const backpack = useAppSelector(selectBackpackInventory);

  const weight = useMemo(() => (backpack ? getTotalWeight(backpack.items) : 0), [backpack]);

  const [query, setQuery] = useState('');

  if (!backpack) return null;

  const maxWeight = backpack.maxWeight || 0;

  return (
    <div className="k-sec" style={{ width: backpack.grid ? `calc(${backpack.grid.w} * var(--grid-cell))` : undefined }}>
      <PanelHeader
        label={backpack.label}
        info={maxWeight ? `${formatKg(weight)} / ${formatKg(maxWeight, true)} kg` : undefined}
        percent={maxWeight ? (weight / maxWeight) * 100 : 0}
        query={query}
        onQuery={setQuery}
      />
      {backpack.grid ? (
        <GridArea inventory={backpack} query={query} />
      ) : (
        <div className="inventory-grid-container">
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
