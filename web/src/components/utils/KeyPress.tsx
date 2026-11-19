import { useEffect } from 'react';
import { setShiftPressed } from '../../store/inventory';
import useKeyPress from '../../hooks/useKeyPress';
import { store, useAppDispatch } from '../../store';

const KeyPress: React.FC = () => {
  const dispatch = useAppDispatch();
  const shiftPressed = useKeyPress('Shift');

  useEffect(() => {
    dispatch(setShiftPressed(shiftPressed));
  }, [shiftPressed, dispatch]);

  // klsh: a Shift released while the screen did not have the keyboard (inventory closed with the key
  // still down, a text field of the game) never reaches the key listener and "half the stack" stays on.
  // Every mouse event carries the real state of the key, so the pointer keeps it honest.
  useEffect(() => {
    const sync = (event: MouseEvent) => {
      if (store.getState().inventory.shiftPressed !== event.shiftKey) dispatch(setShiftPressed(event.shiftKey));
    };

    window.addEventListener('mousedown', sync, true);
    window.addEventListener('mousemove', sync, true);

    return () => {
      window.removeEventListener('mousedown', sync, true);
      window.removeEventListener('mousemove', sync, true);
    };
  }, [dispatch]);

  return <></>;
};

export default KeyPress;
