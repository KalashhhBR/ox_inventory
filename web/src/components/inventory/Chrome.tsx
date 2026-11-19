// klsh: what frames the inventory screen: the tab bar at the top and the key hints at the bottom
import React from 'react';
import { Locale } from '../../store/locale';

// tabs reserved for other resources (health, crafting, skills); they have no content yet
const RESERVED = [
  ['ui_tab_health', 'Health'],
  ['ui_tab_crafting', 'Crafting'],
  ['ui_tab_skills', 'Skills'],
];

export const TabBar: React.FC = () => (
  <div className="k-tabs">
    <span className="k-tab k-tab-on">{Locale.ui_tab_inventory || 'Inventory'}</span>
    {RESERVED.map(([key, fallback]) => (
      <span key={key} className="k-tab k-tab-soon">
        {Locale[key] || fallback}
      </span>
    ))}
  </div>
);

const HINTS = [
  ['R', 'ui_hint_rotate', 'rotate'],
  ['Shift', 'ui_hint_half', 'half'],
  ['Ctrl', 'ui_hint_quick', 'quick move'],
  ['Alt', 'ui_hint_use', 'use'],
  ['RMB', 'ui_hint_menu', 'actions'],
];

export const Footer: React.FC = () => (
  <div className="k-foot">
    <div>
      {HINTS.map(([key, locale, fallback]) => (
        <span key={locale}>
          <kbd>{key === 'RMB' ? Locale.ui_key_rmb || 'RMB' : key}</kbd>
          {Locale[locale] || fallback}
        </span>
      ))}
    </div>
  </div>
);
