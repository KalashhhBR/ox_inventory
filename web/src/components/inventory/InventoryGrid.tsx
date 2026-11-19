import React, { useEffect, useMemo, useState } from 'react';
import { Inventory } from '../../typings';
import InventorySlot from './InventorySlot';
import { getTotalWeight } from '../../helpers';
import { formatKg, matchesQuery } from '../../helpers/format';
import { useAppSelector } from '../../store';
import { useIntersection } from '../../hooks/useIntersection';
import GridArea from './GridArea';
import PanelHeader from './PanelHeader';

const PAGE_SIZE = 30;

// klsh: extraWeight = weight carried outside the slots (worn backpack); label replaces the
// inventory's own; hideWallet = the wallet is drawn somewhere else (player)
const InventoryGrid: React.FC<{ inventory: Inventory; extraWeight?: number; label?: string; hideWallet?: boolean }> = ({
  inventory,
  extraWeight = 0,
  label,
  hideWallet,
}) => {
  const weight = useMemo(
    () => (inventory.maxWeight !== undefined ? getTotalWeight(inventory.items) + extraWeight : 0),
    [inventory.maxWeight, inventory.items, extraWeight]
  );
  const [page, setPage] = useState(0);
  const [query, setQuery] = useState('');
  const { ref, entry } = useIntersection({ threshold: 0.5 });
  const isBusy = useAppSelector((state) => state.inventory.isBusy);

  useEffect(() => {
    if (entry && entry.isIntersecting) {
      setPage((prev) => ++prev);
    }
  }, [entry]);

  // another inventory took this place: the search starts over
  useEffect(() => setQuery(''), [inventory.id, inventory.type]);

  const listed = useMemo(
    () => (inventory.grid || !query ? inventory.items : inventory.items.filter((item) => matchesQuery(item, query))),
    [inventory.grid, inventory.items, query]
  );

  return (
    <div
      className="k-sec"
      style={{
        pointerEvents: isBusy && !inventory.grid ? 'none' : 'auto',
        // klsh: as wide as its grid, so the header and the rule end where the cells end
        width: inventory.grid ? `calc(${inventory.grid.w} * var(--grid-cell))` : undefined,
      }}
    >
      <PanelHeader
        label={label || inventory.label}
        info={inventory.maxWeight ? `${formatKg(weight)} / ${formatKg(inventory.maxWeight, true)} kg` : undefined}
        percent={inventory.maxWeight ? (weight / inventory.maxWeight) * 100 : 0}
        query={query}
        onQuery={setQuery}
        nav={inventory.nav}
      />
      {inventory.grid ? (
        <GridArea inventory={inventory} query={query} hideWallet={hideWallet} />
      ) : (
        <div className="inventory-grid-container">
          {listed.slice(0, (page + 1) * PAGE_SIZE).map((item, index) => (
            <InventorySlot
              key={`${inventory.type}-${inventory.id}-${item.slot}`}
              item={item}
              ref={index === (page + 1) * PAGE_SIZE - 1 ? ref : null}
              inventoryType={inventory.type}
              inventoryGroups={inventory.groups}
              inventoryId={inventory.id}
            />
          ))}
        </div>
      )}
    </div>
  );
};

export default InventoryGrid;
