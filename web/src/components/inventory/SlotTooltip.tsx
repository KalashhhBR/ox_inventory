import { Inventory, SlotWithItem } from '../../typings';
import React, { Fragment, useMemo } from 'react';
import { Items } from '../../store/items';
import { Locale } from '../../store/locale';
import { useAppSelector } from '../../store';
import ClockIcon from '../utils/icons/ClockIcon';
import { getItemUrl } from '../../helpers';
import Divider from '../utils/Divider';
import Markdown from '../utils/Markdown';
import { longWeight } from '../../helpers/format'; // klsh

const SlotTooltip: React.ForwardRefRenderFunction<
  HTMLDivElement,
  { item: SlotWithItem; inventoryType: Inventory['type']; style: React.CSSProperties }
> = ({ item, inventoryType, style }, ref) => {
  const additionalMetadata = useAppSelector((state) => state.inventory.additionalMetadata);
  const reduction = useAppSelector((state) => state.inventory.backpackInventory?.reduction || 0); // klsh
  const itemData = useMemo(() => Items[item.name], [item]);
  const ingredients = useMemo(() => {
    if (!item.ingredients) return null;
    return Object.entries(item.ingredients).sort((a, b) => a[1] - b[1]);
  }, [item]);
  const description = item.metadata?.description || itemData?.description;
  const ammoName = itemData?.ammoName && Items[itemData?.ammoName]?.label;

  return (
    <>
      {!itemData ? (
        <div className="tooltip-wrapper" ref={ref} style={style}>
          <div className="tooltip-header-wrapper">
            <p>{item.name}</p>
          </div>
          <Divider />
        </div>
      ) : (
        <div style={{ ...style }} className="tooltip-wrapper" ref={ref}>
          <div className="tooltip-header-wrapper">
            <p>{item.metadata?.label || itemData.label || item.name}</p>
            {inventoryType === 'crafting' ? (
              <div className="tooltip-crafting-duration">
                <ClockIcon />
                <p>{(item.duration !== undefined ? item.duration : 3000) / 1000}s</p>
              </div>
            ) : (
              <p>{item.metadata?.type}</p>
            )}
          </div>
          <Divider />
          {description && (
            <div className="tooltip-description">
              <Markdown content={description} className="tooltip-markdown" />
            </div>
          )}
          {inventoryType !== 'crafting' ? (
            <>
              {/* klsh: a renamed item always shows what it really is */}
              {item.metadata?.label && item.metadata.label !== itemData.label && (
                <p>
                  {Locale.ui_original || 'Item'}: {itemData.label}
                </p>
              )}
              {/* klsh: clothing shows its data here instead of in the name */}
              {item.metadata?.drawable !== undefined && (
                <>
                  {item.metadata.model && (
                    <p>
                      {Locale.ui_model || 'Model'}: {Locale[`ui_model_${item.metadata.model}`] || item.metadata.model}
                    </p>
                  )}
                  <p>
                    {Locale.ui_piece || 'Piece'}: {item.metadata.drawable}
                  </p>
                  <p>
                    {Locale.ui_variant || 'Variant'}: {item.metadata.texture ?? 0}
                  </p>
                </>
              )}
              {/* klsh: weight of one unit, of the stack and, inside the worn backpack, what it really adds */}
              {item.weight > 0 && item.count > 1 && (
                <p>
                  {Locale.ui_weight_unit || 'Weight each'}: {longWeight(item.weight / item.count)}
                </p>
              )}
              {item.weight > 0 && (
                <p>
                  {Locale.ui_weight_total || 'Weight'}: {longWeight(item.weight)}
                </p>
              )}
              {item.weight > 0 && inventoryType === 'backpack' && reduction > 0 && (
                <p>
                  {Locale.ui_weight_carried || 'Carried'}: {longWeight(item.weight * (1 - reduction))}
                </p>
              )}
              {item.durability !== undefined && (
                <p>
                  {Locale.ui_durability}: {Math.trunc(item.durability)}
                </p>
              )}
              {item.metadata?.ammo !== undefined && (
                <p>
                  {Locale.ui_ammo}: {item.metadata.ammo}
                </p>
              )}
              {ammoName && (
                <p>
                  {Locale.ammo_type}: {ammoName}
                </p>
              )}
              {item.metadata?.serial && (
                <p>
                  {Locale.ui_serial}: {item.metadata.serial}
                </p>
              )}
              {item.metadata?.components && item.metadata?.components[0] && (
                <p>
                  {Locale.ui_components}:{' '}
                  {(item.metadata?.components).map((component: string, index: number, array: []) =>
                    index + 1 === array.length ? Items[component]?.label : Items[component]?.label + ', '
                  )}
                </p>
              )}
              {item.metadata?.weapontint && (
                <p>
                  {Locale.ui_tint}: {item.metadata.weapontint}
                </p>
              )}
              {additionalMetadata.map((data: { metadata: string; value: string }, index: number) => (
                <Fragment key={`metadata-${index}`}>
                  {item.metadata && item.metadata[data.metadata] && (
                    <p>
                      {data.value}: {item.metadata[data.metadata]}
                    </p>
                  )}
                </Fragment>
              ))}
            </>
          ) : (
            <div className="tooltip-ingredients">
              {ingredients &&
                ingredients.map((ingredient) => {
                  const [item, count] = [ingredient[0], ingredient[1]];
                  return (
                    <div className="tooltip-ingredient" key={`ingredient-${item}`}>
                      <img src={getItemUrl(item)} alt="item-image" />
                      <p>
                        {count >= 1
                          ? `${count}x ${Items[item]?.label || item}`
                          : count === 0
                            ? `${Items[item]?.label || item}`
                            : count < 1 && `${count * 100}% ${Items[item]?.label || item}`}
                      </p>
                    </div>
                  );
                })}
            </div>
          )}
        </div>
      )}
    </>
  );
};

export default React.forwardRef(SlotTooltip);
