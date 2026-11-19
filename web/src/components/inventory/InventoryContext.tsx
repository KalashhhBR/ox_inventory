import { onUse } from '../../dnd/onUse';
import { onGive } from '../../dnd/onGive';
import { onDrop } from '../../dnd/onDrop';
import { onGround } from '../../dnd/onGround'; // klsh
import { openSplit } from '../../store/split'; // klsh
import { formatCount, itemLabel, longWeight } from '../../helpers/format'; // klsh
import { Items } from '../../store/items';
import { fetchNui } from '../../utils/fetchNui';
import { Locale } from '../../store/locale';
import { isSlotWithItem } from '../../helpers';
import { setClipboard } from '../../utils/setClipboard';
import { store, useAppSelector } from '../../store';
import React from 'react';
import { Menu, MenuItem } from '../utils/menu/Menu';

interface DataProps {
  action: string;
  component?: string;
  slot?: number;
  serial?: string;
  id?: number;
}

interface Button {
  label: string;
  index: number;
  group?: string;
}

interface Group {
  groupName: string | null;
  buttons: ButtonWithIndex[];
}

interface ButtonWithIndex extends Button {
  index: number;
}

interface GroupedButtons extends Array<Group> {}

const InventoryContext: React.FC = () => {
  const contextMenu = useAppSelector((state) => state.contextMenu);
  const item = contextMenu.item;
  const amount = useAppSelector((state) => state.inventory.itemAmount); // klsh
  // klsh: the wallet lines open this menu too; money is not used and does not split inside the wallet
  const money = item?.name === 'money' || item?.name === 'black_money';
  const grid = useAppSelector((state) => !!state.inventory.leftInventory.grid); // klsh

  const handleClick = (data: DataProps) => {
    if (!item) return;

    switch (data && data.action) {
      case 'use':
        onUse({ name: item.name, slot: item.slot });
        break;
      case 'open':
        // klsh: opens a container item; "use" wears a backpack and swaps the outfit of an outfit bag
        fetchNui('openContainer', item.slot);
        break;
      case 'rename':
        // klsh: the client asks the name; itemAmount (when set) renames only part of a stack
        fetchNui('renameItem', { slot: item.slot, count: store.getState().inventory.itemAmount });
        break;
      case 'give':
        onGive({ name: item.name, slot: item.slot });
        break;
      case 'throw':
        // klsh: the client closes the inventory and enters the aim; itemAmount (when set) limits the count
        fetchNui('throwItem', { slot: item.slot, count: store.getState().inventory.itemAmount });
        break;
      case 'drop':
        // klsh: always the ground, even with another inventory open on the right
        isSlotWithItem(item) && onGround({ item: item, inventory: 'player' });
        break;
      case 'quick':
        // klsh: to the inventory on the right
        isSlotWithItem(item) && onDrop({ item: item, inventory: 'player' });
        break;
      case 'split':
        isSlotWithItem(item) && openSplit(item);
        break;
      case 'remove':
        fetchNui('removeComponent', { component: data?.component, slot: data?.slot });
        break;
      case 'removeAmmo':
        fetchNui('removeAmmo', item.slot);
        break;
      case 'copy':
        setClipboard(data.serial || '');
        break;
      case 'custom':
        fetchNui('useButton', { id: (data?.id || 0) + 1, slot: item.slot });
        break;
    }
  };

  const groupButtons = (buttons: any): GroupedButtons => {
    return buttons.reduce((groups: Group[], button: Button, index: number) => {
      if (button.group) {
        const groupIndex = groups.findIndex((group) => group.groupName === button.group);
        if (groupIndex !== -1) {
          groups[groupIndex].buttons.push({ ...button, index });
        } else {
          groups.push({
            groupName: button.group,
            buttons: [{ ...button, index }],
          });
        }
      } else {
        groups.push({
          groupName: null,
          buttons: [{ ...button, index }],
        });
      }
      return groups;
    }, []);
  };

  return (
    <>
      <Menu>
        {/* klsh: what was clicked, how many and how heavy; the typed quantity when there is one */}
        {item && (
          <div className="context-menu-head">
            <b>{itemLabel(item)}</b>
            <span>
              {[
                money ? `${Locale.$ || '$'} ${formatCount(item.count)}` : item.count > 1 && formatCount(item.count),
                item.weight > 0 && longWeight(item.weight),
                amount > 0 && amount < item.count && `${Locale.ui_quantity || 'Quantity'}: ${formatCount(amount)}`,
              ]
                .filter(Boolean)
                .join(' · ')}
            </span>
          </div>
        )}
        {!money && <MenuItem onClick={() => handleClick({ action: 'use' })} label={Locale.ui_use || 'Use'} hint="Alt" />}
        {item && item.metadata?.container !== undefined && (
          <MenuItem onClick={() => handleClick({ action: 'open' })} label={Locale.ui_open || 'Open'} />
        )}
        <MenuItem onClick={() => handleClick({ action: 'give' })} label={Locale.ui_give || 'Give'} />
        <MenuItem onClick={() => handleClick({ action: 'throw' })} label={Locale.ui_throw || 'Throw'} />
        <MenuItem onClick={() => handleClick({ action: 'drop' })} label={Locale.ui_drop || 'Drop'} />
        <MenuItem onClick={() => handleClick({ action: 'quick' })} label={Locale.ui_quick_move || 'Quick move'} hint="Ctrl" />
        {item && item.count > 1 && grid && !money && (
          <MenuItem onClick={() => handleClick({ action: 'split' })} label={Locale.ui_split || 'Split'} />
        )}
        {item?.name !== 'money' && item?.name !== 'black_money' && (
          <MenuItem onClick={() => handleClick({ action: 'rename' })} label={Locale.ui_rename || 'Rename'} />
        )}
        {item && item.metadata?.ammo > 0 && (
          <MenuItem onClick={() => handleClick({ action: 'removeAmmo' })} label={Locale.ui_remove_ammo} />
        )}
        {item && item.metadata?.serial && (
          <MenuItem
            onClick={() => handleClick({ action: 'copy', serial: item.metadata?.serial })}
            label={Locale.ui_copy}
          />
        )}
        {item && item.metadata?.components && item.metadata?.components.length > 0 && (
          <Menu label={Locale.ui_removeattachments}>
            {item &&
              item.metadata?.components.map((component: string, index: number) => (
                <MenuItem
                  key={index}
                  onClick={() => handleClick({ action: 'remove', component, slot: item.slot })}
                  label={Items[component]?.label || ''}
                />
              ))}
          </Menu>
        )}
        {((item && item.name && Items[item.name]?.buttons?.length) || 0) > 0 && (
          <>
            {item &&
              item.name &&
              groupButtons(Items[item.name]?.buttons).map((group: Group, index: number) => (
                <React.Fragment key={index}>
                  {group.groupName ? (
                    <Menu label={group.groupName}>
                      {group.buttons.map((button: Button) => (
                        <MenuItem
                          key={button.index}
                          onClick={() => handleClick({ action: 'custom', id: button.index })}
                          label={button.label}
                        />
                      ))}
                    </Menu>
                  ) : (
                    group.buttons.map((button: Button) => (
                      <MenuItem
                        key={button.index}
                        onClick={() => handleClick({ action: 'custom', id: button.index })}
                        label={button.label}
                      />
                    ))
                  )}
                </React.Fragment>
              ))}
          </>
        )}
      </Menu>
    </>
  );
};

export default InventoryContext;
