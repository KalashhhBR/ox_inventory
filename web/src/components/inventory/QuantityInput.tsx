// klsh: how many units the next move takes (dragging, quick move, dropping on the ground, the
// wallet). Empty means the whole stack; Shift while dragging is still half.
import React from 'react';
import { useAppDispatch, useAppSelector } from '../../store';
import { selectItemAmount, setItemAmount } from '../../store/inventory';
import { Locale } from '../../store/locale';
import { formatCount } from '../../helpers/format';
import { typingProps } from '../../hooks/useTyping';

const QuantityInput: React.FC = () => {
  const amount = useAppSelector(selectItemAmount);
  const dispatch = useAppDispatch();

  return (
    <div className="k-qty">
      <p className="k-cap">{Locale.ui_quantity || 'Quantity'}</p>
      <label className={amount > 0 ? 'k-qty-set' : undefined}>
        <input
          type="text"
          inputMode="numeric"
          value={amount > 0 ? formatCount(amount) : ''}
          placeholder={Locale.ui_all || 'all'}
          onChange={(event) => dispatch(setItemAmount(Math.min(parseInt(event.target.value.replace(/\D/g, ''), 10) || 0, 99999999)))}
          onKeyUp={(event) => {
            if (event.key !== 'Escape' && event.key !== 'Enter') return;

            event.stopPropagation();
            event.currentTarget.blur();
          }}
          {...typingProps}
        />
        <button type="button" onClick={() => dispatch(setItemAmount(0))}>
          ✕
        </button>
      </label>
    </div>
  );
};

export default QuantityInput;
