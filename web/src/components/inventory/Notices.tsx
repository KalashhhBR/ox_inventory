// klsh: notifications shown inside the inventory. The ones of ox_lib are drawn behind this screen, so
// while it is open the client sends them here (client.lua, `klshNotify`).
import React, { useEffect, useRef, useState } from 'react';
import useNuiEvent from '../../hooks/useNuiEvent';

type Notice = { id: number; title?: string; description?: string; type?: string };

const SHOWN_FOR = 3500;

// one outline icon per kind of notification, as ox_lib does
const ICONS: Record<string, string> = {
  error: 'M12 3a9 9 0 1 0 0 18a9 9 0 0 0 0-18M9 9l6 6M15 9l-6 6',
  success: 'M12 3a9 9 0 1 0 0 18a9 9 0 0 0 0-18M8 12.5l2.8 2.8L16 9.8',
  warning: 'M12 4L2.8 19.5h18.4L12 4zM12 10v4.5M12 17.2v.1',
  inform: 'M12 3a9 9 0 1 0 0 18a9 9 0 0 0 0-18M12 11v5.5M12 7.8v.1',
};

const Notices: React.FC = () => {
  const [notices, setNotices] = useState<Notice[]>([]);
  const nextId = useRef(1);
  const timers = useRef<number[]>([]);

  useNuiEvent<Omit<Notice, 'id'>>('klshNotify', (data) => {
    if (!data || (!data.title && !data.description)) return;

    const id = nextId.current++;

    // the same text again only restarts its time
    setNotices((current) => [...current.filter((notice) => notice.description !== data.description || notice.title !== data.title), { ...data, id }].slice(-4));
    timers.current.push(window.setTimeout(() => setNotices((current) => current.filter((notice) => notice.id !== id)), SHOWN_FOR));
  });

  useNuiEvent('closeInventory', () => setNotices([]));
  useEffect(() => () => timers.current.forEach((timer) => clearTimeout(timer)), []);

  if (notices.length === 0) return null;

  return (
    <div className="k-notices">
      {notices.map((notice) => (
        <div key={notice.id} className={`k-notice k-notice-${notice.type || 'inform'}`}>
          <svg viewBox="0 0 24 24" fill="none" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
            <path d={ICONS[notice.type || 'inform'] || ICONS.inform} />
          </svg>
          <div>
            {notice.title && <b>{notice.title}</b>}
            {notice.description && <span>{notice.description}</span>}
          </div>
          <button type="button" onClick={() => setNotices((current) => current.filter((other) => other.id !== notice.id))}>
            ✕
          </button>
          <i style={{ animationDuration: `${SHOWN_FOR}ms` }} />
        </div>
      ))}
    </div>
  );
};

export default Notices;
