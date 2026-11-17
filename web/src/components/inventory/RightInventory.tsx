import InventoryGrid from './InventoryGrid';
import OutfitPanel from './OutfitPanel'; // klsh
import { useAppSelector } from '../../store';
import { selectRightInventory } from '../../store/inventory';

const RightInventory: React.FC = () => {
  const rightInventory = useAppSelector(selectRightInventory);

  // klsh: an outfit bag shows category slots instead of a grid
  if (rightInventory.categories) return <OutfitPanel inventory={rightInventory} />;

  return <InventoryGrid inventory={rightInventory} />;
};

export default RightInventory;
