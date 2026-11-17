// klsh: force bar shown while a throw is being charged (the inventory itself is closed)
import React, { useState } from 'react';
import useNuiEvent from '../../hooks/useNuiEvent';

const ThrowCharge: React.FC = () => {
  const [duration, setDuration] = useState<number | null>(null);

  useNuiEvent<{ duration: number } | false>('throwCharge', (data) => setDuration(data ? data.duration : null));

  if (duration === null) return null;

  return (
    <div className="throw-charge">
      <div className="throw-charge-fill" style={{ animationDuration: `${duration}ms` }} />
    </div>
  );
};

export default ThrowCharge;
