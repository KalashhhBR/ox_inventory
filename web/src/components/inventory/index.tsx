import React, { useEffect, useState } from 'react';
import { useDrop } from 'react-dnd';
import useNuiEvent from '../../hooks/useNuiEvent';
import InventoryHotbar from './InventoryHotbar';
import { store, useAppDispatch, useAppSelector } from '../../store';
import { onUse } from '../../dnd/onUse'; // klsh
import { refreshSlots, setAdditionalMetadata, setBackpack, setGround, setupInventory, setHotbar, setSearch } from '../../store/inventory';
import { useExitListener } from '../../hooks/useExitListener';
import type { DragSource, Inventory as InventoryProps } from '../../typings';
import RightInventory from './RightInventory';
import LeftInventory from './LeftInventory';
import EquipmentPanel from './EquipmentPanel'; // klsh
import HotbarPanel from './HotbarPanel'; // klsh
import SearchPanel from './SearchPanel'; // klsh
import ThrowCharge from './ThrowCharge'; // klsh
import WalletPanel from './WalletPanel'; // klsh
import QuantityInput from './QuantityInput'; // klsh
import SplitDialog from './SplitDialog'; // klsh
import Notices from './Notices'; // klsh
import { Footer, TabBar } from './Chrome'; // klsh
import { canGround, onGround } from '../../dnd/onGround'; // klsh
import { setDragHint } from '../../store/dragHint'; // klsh
import { closeSplit } from '../../store/split'; // klsh
import { Locale } from '../../store/locale';
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
    closeSplit(); // klsh
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

  // klsh: an item released outside every inventory, slot and panel goes to the ground
  const [{ overGround }, groundDrop] = useDrop<DragSource, void, { overGround: boolean }>(
    () => ({
      accept: 'SLOT',
      collect: (monitor) => ({ overGround: monitor.isOver({ shallow: true }) && canGround(monitor.getItem()) }),
      drop: (source, monitor) => {
        if (!monitor.didDrop()) onGround(source);
      },
    }),
    []
  );

  // the shortcuts, the wallet and the quantity field swallow a missed drop instead of dropping the item
  const [, quietDrop] = useDrop<DragSource, void, unknown>(() => ({ accept: 'SLOT' }), []);

  useEffect(() => {
    setDragHint('ground', overGround ? Locale.ui_ground_drop || 'Drop on the ground' : undefined);

    return () => setDragHint('ground');
  }, [overGround]);

  const playerName = useAppSelector((state) => state.inventory.leftInventory.label);

  return (
    <>
      <Fade in={inventoryVisible}>
        <div
          className="k-screen"
          ref={(element) => {
            groundDrop(element);
          }}
        >
          <div className="k-ui">
            <p className="k-who">{playerName}</p>
            <TabBar />
            <p className="k-esc">
              <kbd>Esc</kbd>
              {Locale.ui_close || 'Close'}
            </p>
            <div className="k-col">
              <LeftInventory />
              <BackpackGrid />
            </div>
            <div className="k-centre">
              <EquipmentPanel />
              <div
                className="k-dock"
                ref={(element) => {
                  quietDrop(element);
                }}
              >
                <HotbarPanel />
                <div className="k-purse">
                  <WalletPanel />
                  <QuantityInput />
                </div>
              </div>
            </div>
            <div className="k-col k-col-right">
              <RightInventory />
              <SearchPanel />
              <GroundGrid />
            </div>
            <Footer />
          </div>
          <Tooltip />
          <InventoryContext />
          <SplitDialog />
          <Notices />
        </div>
      </Fade>
      <InventoryHotbar />
      <ThrowCharge />
    </>
  );
};

export default Inventory;
