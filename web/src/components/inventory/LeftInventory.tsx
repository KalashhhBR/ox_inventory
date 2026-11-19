import InventoryGrid from './InventoryGrid';
import { useAppSelector } from '../../store';
import { selectBackpackInventory, selectLeftInventory } from '../../store/inventory';
import { getBackpackCarriedWeight } from '../../helpers';
import { Locale } from '../../store/locale';

const LeftInventory: React.FC = () => {
  const leftInventory = useAppSelector(selectLeftInventory);
  // klsh: the worn backpack counts on the carried weight
  const backpack = useAppSelector(selectBackpackInventory);

  // klsh: the player's name goes at the top of the screen; here it is "pockets", with one number for
  // everything carried and the wallet drawn next to the shortcuts
  return (
    <InventoryGrid
      inventory={leftInventory}
      extraWeight={getBackpackCarriedWeight(backpack)}
      label={Locale.ui_pockets || 'Pockets'}
      hideWallet
    />
  );
};

export default LeftInventory;
