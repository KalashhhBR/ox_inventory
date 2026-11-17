import React, { useState } from 'react';
import useNuiEvent from '../../hooks/useNuiEvent';
import InventoryControl from './InventoryControl';
import InventoryHotbar from './InventoryHotbar';
import { store, useAppDispatch } from '../../store';
import { onUse } from '../../dnd/onUse'; // klsh
import { refreshSlots, setAdditionalMetadata, setBackpack, setGround, setupInventory, setHotbar, setSearch } from '../../store/inventory';
import { useExitListener } from '../../hooks/useExitListener';
import type { Inventory as InventoryProps } from '../../typings';
import RightInventory from './RightInventory';
import LeftInventory from './LeftInventory';
import EquipmentPanel from './EquipmentPanel'; // klsh
import HotbarPanel from './HotbarPanel'; // klsh
import SearchPanel from './SearchPanel'; // klsh
import ThrowCharge from './ThrowCharge'; // klsh
import { clearMoveQueue } from '../../dnd/moveQueue'; // klsh
import { State } from '../../typings';
import BackpackGrid from './BackpackGrid'; // klsh
import GroundGrid from './GroundGrid'; // klsh
import Tooltip from '../utils/Tooltip';
import { closeTooltip } from '../../store/tooltip';
import InventoryContext from './InventoryContext';
import { closeContextMenu } from '../../store/contextMenu';
import Fade from '../utils/transitions/Fade';

const Inventory: React.FC = () => {
  const [inventoryVisible, setInventoryVisible] = useState(false);
  const dispatch = useAppDispatch();

  useNuiEvent<boolean>('setInventoryVisible', (visible) => {
    setInventoryVisible(visible);

    // klsh: hidden by the inventory key while the queue goes on
    if (!visible) {
      dispatch(closeContextMenu());
      dispatch(closeTooltip());
    }
  });
  useNuiEvent<false>('closeInventory', () => {
    clearMoveQueue(); // klsh
    setInventoryVisible(false);
    dispatch(closeContextMenu());
    dispatch(closeTooltip());
  });
  useExitListener(setInventoryVisible);

  // klsh: "use" asked again by the client (a backpack that was opened on the right when it was used)
  useNuiEvent<number>('klshUse', (slot) => {
    const item = store.getState().inventory.leftInventory.items[slot - 1];

    if (item?.name) onUse({ name: item.name, slot: item.slot });
  });

  useNuiEvent<{
    leftInventory?: InventoryProps;
    rightInventory?: InventoryProps;
    equipmentInventory?: InventoryProps; // klsh
    backpackInventory?: InventoryProps; // klsh
    groundInventory?: InventoryProps; // klsh
    otherEquipmentInventory?: InventoryProps; // klsh
    otherBackpackInventory?: InventoryProps; // klsh
  }>('setupInventory', (data) => {
    dispatch(setupInventory(data));
    !inventoryVisible && setInventoryVisible(true);
  });

  useNuiEvent('refreshSlots', (data) => dispatch(refreshSlots(data)));

  // klsh: backpack put on, taken off or replaced
  useNuiEvent<InventoryProps | false>('setBackpack', (data) => dispatch(setBackpack(data)));
  useNuiEvent<InventoryProps | false>('setGround', (data) => dispatch(setGround(data)));
  useNuiEvent<State['hotbar']>('setHotbar', (data) => dispatch(setHotbar(data))); // klsh
  useNuiEvent<{ equipment?: InventoryProps | false; backpack?: InventoryProps | false }>('setSearch', (data) =>
    dispatch(setSearch(data))
  ); // klsh

  useNuiEvent('displayMetadata', (data: Array<{ metadata: string; value: string }>) => {
    dispatch(setAdditionalMetadata(data));
  });

  return (
    <>
      <Fade in={inventoryVisible}>
        <div className="inventory-wrapper">
          <div className="equipment-side">
            <EquipmentPanel />
            <HotbarPanel />
          </div>
          <div className="inventory-left-column">
            <LeftInventory />
            <BackpackGrid />
          </div>
          <InventoryControl />
          <div className="inventory-left-column">
            <RightInventory />
            <SearchPanel />
            <GroundGrid />
          </div>
          <Tooltip />
          <InventoryContext />
        </div>
      </Fade>
      <InventoryHotbar />
      <ThrowCharge />
    </>
  );
};

export default Inventory;
