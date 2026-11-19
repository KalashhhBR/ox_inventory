import InventoryGrid from './InventoryGrid';
import OutfitPanel from './OutfitPanel'; // klsh
import { useAppSelector } from '../../store';
import { selectRightInventory } from '../../store/inventory';
import { Locale } from '../../store/locale';

const RightInventory: React.FC = () => {
  const rightInventory = useAppSelector(selectRightInventory);
  const searching = useAppSelector((state) => !!state.inventory.otherEquipmentInventory?.categories);

  // klsh: an outfit bag shows category slots instead of a grid
  if (rightInventory.categories) return <OutfitPanel inventory={rightInventory} />;

  // klsh: with nothing else open the right side is the ground
  const ground = rightInventory.type === 'drop' || rightInventory.type === 'newdrop';

  // klsh: the wallet of a player being searched is drawn with their clothing (SearchPanel)
  return (
    <InventoryGrid
      inventory={rightInventory}
      label={ground ? Locale.ui_ground || 'Ground' : undefined}
      hideWallet={searching}
    />
  );
};

export default RightInventory;
