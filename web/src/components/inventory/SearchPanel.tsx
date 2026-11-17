// klsh: clothing and worn backpack of the player being searched, below their inventory
import React, { useMemo } from 'react';
import { useAppSelector } from '../../store';
import { selectOtherBackpack, selectOtherEquipment } from '../../store/inventory';
import { getTotalWeight } from '../../helpers';
import WeightBar from '../utils/WeightBar';
import EquipmentSlot from './EquipmentSlot';
import GridArea from './GridArea';

const SearchPanel: React.FC = () => {
  const equipment = useAppSelector(selectOtherEquipment);
  const backpack = useAppSelector(selectOtherBackpack);
  const weight = useMemo(() => (backpack ? getTotalWeight(backpack.items) : 0), [backpack]);

  if (!equipment && !backpack) return null;

  return (
    <div className="search-panel">
      {equipment && equipment.categories && (
        <div className="inventory-grid-wrapper">
          <div className="inventory-grid-header-wrapper">
            <p>{equipment.label}</p>
          </div>
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
        </div>
      )}
      {backpack && backpack.grid && (
        <div className="inventory-grid-wrapper">
          <div>
            <div className="inventory-grid-header-wrapper">
              <p>{backpack.label}</p>
              <p>
                {Math.floor(weight) / 1000}/{(backpack.maxWeight || 0) / 1000}kg
              </p>
            </div>
            <WeightBar percent={backpack.maxWeight ? (weight / backpack.maxWeight) * 100 : 0} />
          </div>
          <GridArea inventory={backpack} maxRows={3} />
        </div>
      )}
    </div>
  );
};

export default SearchPanel;
