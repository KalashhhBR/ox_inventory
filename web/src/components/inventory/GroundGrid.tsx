// klsh: the ground (nearest drop, or an empty area that creates one), shown below the secondary inventory
import React, { useMemo, useState } from 'react';
import { useAppSelector } from '../../store';
import { selectGroundInventory } from '../../store/inventory';
import { getTotalWeight } from '../../helpers';
import { formatKg } from '../../helpers/format';
import PanelHeader from './PanelHeader';
import InventorySlot from './InventorySlot';
import GridArea from './GridArea';

const GroundGrid: React.FC = () => {
  const ground = useAppSelector(selectGroundInventory);

  const weight = useMemo(() => (ground ? getTotalWeight(ground.items) : 0), [ground]);

  const [query, setQuery] = useState('');

  if (!ground) return null;

  const maxWeight = ground.maxWeight || 0;

  return (
    <div className="k-sec" style={{ width: ground.grid ? `calc(${ground.grid.w} * var(--grid-cell))` : undefined }}>
      <PanelHeader
        label={ground.label}
        info={maxWeight ? `${formatKg(weight)} / ${formatKg(maxWeight, true)} kg` : undefined}
        percent={maxWeight ? (weight / maxWeight) * 100 : 0}
        query={query}
        onQuery={setQuery}
        nav={ground.nav}
      />
      {ground.grid ? (
        <GridArea inventory={ground} query={query} />
      ) : (
        <div className="inventory-grid-container">
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
