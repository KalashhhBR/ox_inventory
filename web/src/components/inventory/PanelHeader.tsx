// klsh: header shared by every inventory on screen: name, weight, search and a thin rule that is
// also the weight bar
import React from 'react';
import { Locale } from '../../store/locale';
import { typingProps } from '../../hooks/useTyping';
import { fetchNui } from '../../utils/fetchNui';

interface Props {
  label?: string;
  sub?: string;
  info?: string;
  percent?: number;
  query?: string;
  onQuery?: (value: string) => void;
  // ground: go through the drops within reach
  nav?: { index: number; count: number };
}

const PanelHeader: React.FC<Props> = ({ label, sub, info, percent = 0, query, onQuery, nav }) => (
  <div className="k-head">
    <div className="k-head-row">
      <p className="k-head-name">
        {label}
        {sub && <small>{sub}</small>}
      </p>
      {nav && nav.count > 1 && (
        <span className="k-nav">
          <button type="button" onClick={() => fetchNui('klshCycleGround', -1)}>
            ‹
          </button>
          {nav.index}/{nav.count}
          <button type="button" onClick={() => fetchNui('klshCycleGround', 1)}>
            ›
          </button>
        </span>
      )}
      {info && <p className="k-head-info">{info}</p>}
      {onQuery && (
        <label className="k-find">
          <svg viewBox="0 0 24 24" fill="none" strokeWidth="2.4" aria-hidden="true">
            <circle cx="11" cy="11" r="7" />
            <path d="m20 20-3.5-3.5" />
          </svg>
          <input
            type="text"
            value={query || ''}
            placeholder={Locale.ui_search || 'Search'}
            spellCheck={false}
            onChange={(event) => onQuery(event.target.value)}
            onKeyUp={(event) => {
              // Escape leaves the field instead of closing the inventory
              if (event.key !== 'Escape') return;

              event.stopPropagation();
              onQuery('');
              event.currentTarget.blur();
            }}
            {...typingProps}
          />
        </label>
      )}
    </div>
    <div className="k-rule">
      <div className={percent > 90 ? 'k-rule-full' : undefined} style={{ width: `${Math.max(0, Math.min(100, percent))}%` }} />
    </div>
  </div>
);

export default PanelHeader;
