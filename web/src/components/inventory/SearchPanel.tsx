// klsh: clothing and worn backpack of the player being searched, below their inventory
import React, { useMemo, useState } from 'react';
import { useAppSelector } from '../../store';
import { selectOtherBackpack, selectOtherEquipment, selectRightInventory } from '../../store/inventory';
import { Locale } from '../../store/locale';
import InventorySlot from './InventorySlot';
import { getTotalWeight } from '../../helpers';
import { formatKg } from '../../helpers/format';
import EquipmentSlot from './EquipmentSlot';
import GridArea from './GridArea';
import PanelHeader from './PanelHeader';

const SearchPanel: React.FC = () => {
  const equipment = useAppSelector(selectOtherEquipment);
  const backpack = useAppSelector(selectOtherBackpack);
  const weight = useMemo(() => (backpack ? getTotalWeight(backpack.items) : 0), [backpack]);
  const [query, setQuery] = useState('');
  const other = useAppSelector(selectRightInventory);
  const wallet = other.type === 'otherplayer' ? other.grid?.wallet : undefined;

  if (!equipment && !backpack) return null;

  return (
    <>
      {equipment && equipment.categories && (
        <div className="k-sec k-sec-search">
          <PanelHeader label={wallet !== undefined ? Locale.ui_equipment_wallet || equipment.label : equipment.label} />
          <div className="k-search-row">
            <div className="search-equipment">
              {equipment.categories.map((category, index) => (
                <EquipmentSlot
                  key={`search-equipment-${index}`}
                  inventory={equipment}
                  item={equipment.items[index] || { slot: index + 1 }}
                  category={category}
                />
              ))}
            </div>
            {/* the wallet of the player being searched: clean money over dirty money */}
            {wallet !== undefined && (
              <div className="k-search-wallet">
                {[wallet, wallet + 1].map((index) => (
                  <InventorySlot
                    key={`search-wallet-${index}`}
                    item={other.items[index] || { slot: index + 1 }}
                    inventoryType={other.type}
                    inventoryGroups={other.groups}
                    inventoryId={other.id}
                  />
                ))}
              </div>
            )}
          </div>
        </div>
      )}
      {backpack && backpack.grid && (
        <div className="k-sec" style={{ width: `calc(${backpack.grid.w} * var(--grid-cell))` }}>
          <PanelHeader
            label={backpack.label}
            info={backpack.maxWeight ? `${formatKg(weight)} / ${formatKg(backpack.maxWeight, true)} kg` : undefined}
            percent={backpack.maxWeight ? (weight / backpack.maxWeight) * 100 : 0}
            query={query}
            onQuery={setQuery}
          />
          <GridArea inventory={backpack} query={query} />
        </div>
      )}
    </>
  );
};

export default SearchPanel;
