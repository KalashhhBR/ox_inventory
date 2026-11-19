// klsh: numbers as the screen shows them
import { Items } from '../store/items';
import { Locale } from '../store/locale';
import { Slot } from '../typings';

const decimal = (value: number, digits: number) => {
  const text = value.toFixed(digits);

  return Locale.ui_decimal ? text.replace('.', Locale.ui_decimal) : text;
};

// header of an inventory: kilograms with one decimal (a round limit shows no decimal)
export const formatKg = (grams: number, round?: boolean) =>
  round && grams % 1000 === 0 ? String(grams / 1000) : decimal(Math.floor(grams / 100) / 10, 1);

// counts and money, with the thousands separator of the server's language
export const formatCount = (value: number) => {
  const text = Math.floor(value).toLocaleString('en-us');

  return Locale.ui_thousands ? text.replace(/,/g, Locale.ui_thousands) : text;
};

// corner of an item: as short as possible ("240g", "1.1kg", "12kg")
export const shortWeight = (grams: number) => {
  if (!grams || grams <= 0) return '';
  if (grams < 1000) return `${Math.round(grams)}g`;

  const kg = grams / 1000;

  return `${kg >= 10 || Number.isInteger(kg) ? Math.round(kg) : decimal(Math.round(kg * 10) / 10, 1)}kg`;
};

// tooltip and menus
export const longWeight = (grams: number) => (grams < 1000 ? `${Math.round(grams)} g` : `${decimal(Math.round(grams / 10) / 100, 2)} kg`);

export const itemLabel = (item: Slot) => item.metadata?.label || (item.name && Items[item.name]?.label) || item.name || '';

const plain = (text: string) =>
  text
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .trim();

// search of an inventory: the name the player sees or the original name of the item
export const matchesQuery = (item: Slot, query: string) => {
  const wanted = plain(query);

  if (!wanted) return true;

  return plain(`${itemLabel(item)} ${(item.name && Items[item.name]?.label) || ''}`).includes(wanted);
};
