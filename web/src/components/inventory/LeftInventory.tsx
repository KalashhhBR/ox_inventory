import InventoryGrid from './InventoryGrid';
import { useAppSelector } from '../../store';
import { selectBackpackInventory, selectLeftInventory } from '../../store/inventory';
import { getBackpackCarriedWeight } from '../../helpers';

const LeftInventory: React.FC = () => {
  const leftInventory = useAppSelector(selectLeftInventory);
  // klsh: the worn backpack counts on the carried weight
  const backpack = useAppSelector(selectBackpackInventory);

  return <InventoryGrid inventory={leftInventory} extraWeight={getBackpackCarriedWeight(backpack)} />;
};

export default LeftInventory;
