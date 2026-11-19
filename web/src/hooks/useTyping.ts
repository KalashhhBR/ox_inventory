// klsh: while a text field has the keyboard the game must not hear the keys (the inventory keeps
// the game input on so the player can walk with it open)
import { fetchNui } from '../utils/fetchNui';

export const typingProps = {
  onFocus: () => {
    fetchNui('klshTyping', true);
  },
  onBlur: () => {
    fetchNui('klshTyping', false);
  },
};
