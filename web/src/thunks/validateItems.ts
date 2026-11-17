import { createAsyncThunk } from '@reduxjs/toolkit';
import { setContainerWeight } from '../store/inventory';
import { fetchNui } from '../utils/fetchNui';

export const validateMove = createAsyncThunk(
  'inventory/validateMove',
  async (
    data: {
      fromSlot: number;
      fromType: string;
      toSlot?: number;
      toType: string;
      count: number;
      // klsh: grid placement (empty place) instead of a target slot
      toX?: number;
      toY?: number;
      rotated?: boolean;
    },
    { rejectWithValue, dispatch }
  ) => {
    try {
      const response = await fetchNui<boolean | number>('swapItems', data);

      if (response === false) return rejectWithValue(response);

      if (typeof response === 'number') dispatch(setContainerWeight(response));
    } catch (error) {
      return rejectWithValue(false);
    }
  }
);
