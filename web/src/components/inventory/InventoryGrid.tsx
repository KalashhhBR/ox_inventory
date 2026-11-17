import React, { useEffect, useMemo, useRef, useState } from 'react';
import { Inventory } from '../../typings';
import WeightBar from '../utils/WeightBar';
import InventorySlot from './InventorySlot';
import { getTotalWeight } from '../../helpers';
import { useAppSelector } from '../../store';
import { useIntersection } from '../../hooks/useIntersection';
import GridArea from './GridArea';

const PAGE_SIZE = 30;

// klsh: extraWeight = weight carried outside the slots (worn backpack)
const InventoryGrid: React.FC<{ inventory: Inventory; extraWeight?: number }> = ({ inventory, extraWeight = 0 }) => {
  const weight = useMemo(
    () =>
      inventory.maxWeight !== undefined
        ? Math.floor((getTotalWeight(inventory.items) + extraWeight) * 1000) / 1000
        : 0,
    [inventory.maxWeight, inventory.items, extraWeight]
  );
  const [page, setPage] = useState(0);
  const containerRef = useRef(null);
  const { ref, entry } = useIntersection({ threshold: 0.5 });
  const isBusy = useAppSelector((state) => state.inventory.isBusy);

  useEffect(() => {
    if (entry && entry.isIntersecting) {
      setPage((prev) => ++prev);
    }
  }, [entry]);
  return (
    <>
      <div className="inventory-grid-wrapper" style={{ pointerEvents: isBusy && !inventory.grid ? 'none' : 'auto' }}>
        <div>
          <div className="inventory-grid-header-wrapper">
            <p>{inventory.label}</p>
            {inventory.maxWeight && (
              <p>
                {weight / 1000}/{inventory.maxWeight / 1000}kg
              </p>
            )}
          </div>
          <WeightBar percent={inventory.maxWeight ? (weight / inventory.maxWeight) * 100 : 0} />
        </div>
        {inventory.grid ? (
          // klsh: grid inventory; the secondary one scrolls when it is tall
          <GridArea inventory={inventory} maxRows={inventory.type === 'player' ? undefined : 7} />
        ) : (
        <div className="inventory-grid-container" ref={containerRef}>
          <>
            {inventory.items.slice(0, (page + 1) * PAGE_SIZE).map((item, index) => (
              <InventorySlot
                key={`${inventory.type}-${inventory.id}-${item.slot}`}
                item={item}
                ref={index === (page + 1) * PAGE_SIZE - 1 ? ref : null}
                inventoryType={inventory.type}
                inventoryGroups={inventory.groups}
                inventoryId={inventory.id}
              />
            ))}
          </>
        </div>
        )}
      </div>
    </>
  );
};

export default InventoryGrid;
