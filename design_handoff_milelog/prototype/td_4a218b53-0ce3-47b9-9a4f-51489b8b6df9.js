// MileLog — shared UI primitives & mock data

// ─────────────────────────────────────────────────────────────
// i18n
// ─────────────────────────────────────────────────────────────
const STRINGS = {
  en: {
    // Dashboard
    appName: 'MileLog',
    greet_morning: 'Good morning',
    greet_afternoon: 'Good afternoon',
    greet_evening: 'Good evening',
    this_month: 'This month',
    total_km: 'Total distance',
    total_value: 'Reimbursable',
    business: 'Business',
    personal: 'Personal',
    auto_tracker: 'Auto-tracker',
    active: 'Active',
    standby: 'Standby',
    start_trip: 'Start trip',
    recent_trips: 'Recent trips',
    see_all: 'See all',
    // Tabs
    tab_home: 'Home',
    tab_reports: 'Reports',
    tab_settings: 'Settings',
    tab_navigation: 'Drive',
    tab_trips: 'Trips',
    // Settings
    settings: 'Settings',
    auto_tracking: 'Auto-tracking',
    bluetooth_autostart: 'Bluetooth auto-start',
    bluetooth_desc: 'Start a trip when connecting to a paired vehicle',
    geofencing: 'Geofencing',
    geofencing_desc: 'Detect arrivals and departures at workplaces',
    gps_tracking: 'Continuous GPS',
    gps_desc: 'Use high-accuracy location while driving',
    cloud: 'Cloud services',
    sync_now: 'Sync now',
    last_sync: 'Last synced',
    restore_backup: 'Restore from backup',
    sign_out: 'Sign out',
    management: 'Management',
    vehicles: 'Vehicles',
    workplaces: 'Workplaces',
    odometer_log: 'Odometer log',
    preferences: 'Preferences',
    mileage_rate: 'Mileage rate',
    theme: 'Appearance',
    language: 'Language',
    about: 'About & help',
    version: 'Version',
    permissions: 'Permissions',
    loc_bg: 'Background location',
    loc_bg_desc: 'Required for auto-tracking',
    bt_perm: 'Nearby devices',
    bt_perm_desc: 'Required for Bluetooth auto-start',
    granted: 'Granted',
    needs_review: 'Review',
    // Cards
    gps_strong: 'GPS strong',
    gps_weak: 'GPS weak',
    no_gps: 'No GPS',
    synced: 'Synced',
    pending: 'Pending sync',
    // Rate dialog
    rate_title: 'Default mileage rate',
    rate_hint: 'Finnish 2026 standard: €0.55/km',
    per_km: 'per km',
    save: 'Save',
    cancel: 'Cancel',
    // Vehicle
    add_vehicle: 'Add vehicle',
    primary: 'Primary',
    // Theme dialog
    theme_system: 'Follow system',
    theme_light: 'Light',
    theme_dark: 'Dark',
    // Misc
    today: 'Today',
    yesterday: 'Yesterday',
    km: 'km',
    min: 'min',
    trips: 'trips',
    active_trip_banner: 'Trip in progress',
    tap_to_open: 'Tap to open',
  },
  fi: {
    appName: 'MileLog',
    greet_morning: 'Hyvää huomenta',
    greet_afternoon: 'Hyvää iltapäivää',
    greet_evening: 'Hyvää iltaa',
    this_month: 'Tässä kuussa',
    total_km: 'Kokonaismatka',
    total_value: 'Korvattava',
    business: 'Työ',
    personal: 'Oma',
    auto_tracker: 'Automaattiseuranta',
    active: 'Aktiivinen',
    standby: 'Valmiustila',
    start_trip: 'Aloita matka',
    recent_trips: 'Viimeaikaiset matkat',
    see_all: 'Näytä kaikki',
    tab_home: 'Koti',
    tab_reports: 'Raportit',
    tab_settings: 'Asetukset',
    tab_navigation: 'Ajo',
    tab_trips: 'Matkat',
    settings: 'Asetukset',
    auto_tracking: 'Automaattiseuranta',
    bluetooth_autostart: 'Bluetooth-automaatti',
    bluetooth_desc: 'Aloita matka yhdistettäessä autoon',
    geofencing: 'Maantieteellinen aitaus',
    geofencing_desc: 'Tunnista saapumiset ja lähdöt työpaikoilta',
    gps_tracking: 'Jatkuva GPS',
    gps_desc: 'Käytä tarkkaa sijaintia ajon aikana',
    cloud: 'Pilvipalvelut',
    sync_now: 'Synkronoi',
    last_sync: 'Viimeisin synkronointi',
    restore_backup: 'Palauta varmuuskopiosta',
    sign_out: 'Kirjaudu ulos',
    management: 'Hallinta',
    vehicles: 'Ajoneuvot',
    workplaces: 'Työpaikat',
    odometer_log: 'Matkamittari',
    preferences: 'Mieltymykset',
    mileage_rate: 'Kilometrikorvaus',
    theme: 'Ulkoasu',
    language: 'Kieli',
    about: 'Tietoja ja apu',
    version: 'Versio',
    permissions: 'Käyttöoikeudet',
    loc_bg: 'Taustasijainti',
    loc_bg_desc: 'Tarvitaan automaattiseurantaan',
    bt_perm: 'Lähellä olevat laitteet',
    bt_perm_desc: 'Tarvitaan Bluetooth-automaattiin',
    granted: 'Myönnetty',
    needs_review: 'Tarkista',
    gps_strong: 'GPS vahva',
    gps_weak: 'GPS heikko',
    no_gps: 'Ei GPS:ää',
    synced: 'Synkronoitu',
    pending: 'Odottaa',
    rate_title: 'Oletuskorvaus',
    rate_hint: 'Suomi 2026: 0,55 €/km',
    per_km: '€/km',
    save: 'Tallenna',
    cancel: 'Peruuta',
    add_vehicle: 'Lisää ajoneuvo',
    primary: 'Ensisijainen',
    theme_system: 'Järjestelmä',
    theme_light: 'Vaalea',
    theme_dark: 'Tumma',
    today: 'Tänään',
    yesterday: 'Eilen',
    km: 'km',
    min: 'min',
    trips: 'matkaa',
    active_trip_banner: 'Matka käynnissä',
    tap_to_open: 'Avaa',
  }
};

// ─────────────────────────────────────────────────────────────
// Money / number formatting — Finnish style
// ─────────────────────────────────────────────────────────────
const fmtKm = (n, lang='en') => {
  const rounded = Math.round(n * 10) / 10;
  if (lang === 'fi') return rounded.toString().replace('.', ',');
  return rounded.toLocaleString('en-US', { maximumFractionDigits: 1 });
};
const fmtEur = (n, lang='en') => {
  const s = n.toFixed(2);
  if (lang === 'fi') return s.replace('.', ',') + ' €';
  return '€' + s;
};
const fmtInt = (n) => n.toLocaleString('en-US');

// ─────────────────────────────────────────────────────────────
// Mock data — Finnish flavor
// ─────────────────────────────────────────────────────────────
const MOCK_TRIPS = [
  { id: 1, from: 'Kotitoimisto', to: 'Nokia HQ, Espoo', km: 47.3, min: 38, date: 'Today', time: '14:22', type: 'business', company: 'Nokia Oyj' },
  { id: 2, from: 'Nokia HQ, Espoo', to: 'Ravintola Savoy, Helsinki', km: 18.1, min: 24, date: 'Today', time: '12:05', type: 'business', company: 'Client lunch' },
  { id: 3, from: 'Kotitoimisto', to: 'Nokia HQ, Espoo', km: 47.6, min: 41, date: 'Today', time: '08:30', type: 'business', company: 'Nokia Oyj' },
  { id: 4, from: 'Hartwall Arena', to: 'Kotitoimisto', km: 9.8, min: 18, date: 'Yesterday', time: '22:10', type: 'personal', company: '—' },
  { id: 5, from: 'Stockmann, Helsinki', to: 'Vantaa', km: 22.4, min: 29, date: 'Yesterday', time: '17:45', type: 'business', company: 'Acme Oy' },
  { id: 6, from: 'Kotitoimisto', to: 'Tampere', km: 182.7, min: 128, date: '17 Apr', time: '09:00', type: 'business', company: 'Metso Oyj' },
];

const MOCK_MONTH = {
  km: 1247.3,
  businessKm: 1018.5,
  personalKm: 228.8,
  rate: 0.55,
  trips: 34,
  // 30-day sparkline data (km per day)
  daily: [32,48,12,0,67,45,38,52,0,0,41,58,36,29,47,52,0,0,38,61,44,55,48,0,0,52,47,183,38,47]
};

const MOCK_VEHICLES = [
  { id: 1, name: 'Volvo XC60', plate: 'RKT-842', year: 2023, odo: 42180, primary: true, bt: true },
  { id: 2, name: 'Tesla Model 3', plate: 'ABC-112', year: 2021, odo: 68420, primary: false, bt: true },
];

const MOCK_WORKPLACES = [
  { id: 1, name: 'Nokia HQ', addr: 'Karaportti 3, Espoo', radius: 150 },
  { id: 2, name: 'Kotitoimisto', addr: 'Pohjoisranta 8, Helsinki', radius: 80 },
  { id: 3, name: 'Acme Oy', addr: 'Mannerheimintie 12', radius: 100 },
];

// ─────────────────────────────────────────────────────────────
// UI primitives
// ─────────────────────────────────────────────────────────────
const Card = ({ children, style, onClick, interactive }) => (
  <div
    onClick={onClick}
    style={{
      background: 'var(--bg-elev)',
      border: '1px solid var(--border)',
      borderRadius: 18,
      ...(interactive ? { cursor: 'pointer', transition: 'transform .15s, border-color .15s' } : {}),
      ...style
    }}
  >
    {children}
  </div>
);

// Material-style switch
const Switch = ({ on, onChange }) => (
  <div
    onClick={(e) => { e.stopPropagation(); onChange?.(!on); }}
    style={{
      width: 48, height: 28, borderRadius: 14,
      background: on ? 'var(--accent)' : 'var(--bg-inset)',
      border: on ? '1px solid var(--accent)' : '1.5px solid var(--border-strong)',
      position: 'relative', cursor: 'pointer',
      transition: 'background .2s, border-color .2s',
      flexShrink: 0,
    }}
  >
    <div style={{
      position: 'absolute',
      top: '50%',
      left: on ? 22 : 4,
      transform: 'translateY(-50%)',
      width: on ? 20 : 14,
      height: on ? 20 : 14,
      borderRadius: '50%',
      background: on ? 'var(--accent-ink)' : 'var(--fg-dim)',
      transition: 'left .2s, width .2s, height .2s, background .2s',
    }}/>
  </div>
);

// Row — 64dp settings list row
const SettingRow = ({ icon, iconBg, title, subtitle, right, onClick, divider = true, danger }) => (
  <div
    onClick={onClick}
    style={{
      display: 'flex', alignItems: 'center', gap: 14,
      padding: '14px 18px', minHeight: 64,
      borderBottom: divider ? '1px solid var(--border)' : 'none',
      cursor: onClick ? 'pointer' : 'default',
    }}
  >
    {icon && (
      <div style={{
        width: 38, height: 38, borderRadius: 10,
        background: iconBg || 'var(--bg-inset)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        color: danger ? 'var(--danger)' : 'var(--accent)',
        flexShrink: 0,
      }}>
        {icon}
      </div>
    )}
    <div style={{ flex: 1, minWidth: 0 }}>
      <div style={{
        fontSize: 15, fontWeight: 500, lineHeight: 1.3,
        color: danger ? 'var(--danger)' : 'var(--fg)',
      }}>{title}</div>
      {subtitle && (
        <div style={{ fontSize: 12.5, color: 'var(--fg-dim)', marginTop: 2, lineHeight: 1.35 }}>
          {subtitle}
        </div>
      )}
    </div>
    {right && <div style={{ flexShrink: 0 }}>{right}</div>}
  </div>
);

// Status chip with corner brackets — a distinctive moment
const StatusChip = ({ tone = 'accent', children, dot = true }) => {
  const colorMap = {
    accent: 'var(--accent)',
    success: 'var(--success)',
    danger: 'var(--danger)',
    warning: 'var(--warning)',
    dim: 'var(--fg-dim)',
  };
  const c = colorMap[tone];
  return (
    <div style={{
      display: 'inline-flex', alignItems: 'center', gap: 6,
      padding: '5px 10px',
      fontSize: 11,
      fontFamily: "'JetBrains Mono', monospace",
      letterSpacing: '0.06em',
      textTransform: 'uppercase',
      color: c,
      background: 'transparent',
      border: `1px solid ${c === 'var(--fg-dim)' ? 'var(--border-strong)' : c}`,
      borderRadius: 6,
      position: 'relative',
    }}>
      {dot && (
        <span className={tone === 'success' ? 'pulse-dot' : ''} style={{
          width: 6, height: 6, borderRadius: '50%', background: c, display: 'inline-block',
        }}/>
      )}
      {children}
    </div>
  );
};

// Top app bar for in-screen use (inside android device, above our content)
const TopBar = ({ title, onBack, right, large = false }) => (
  <div style={{
    display: 'flex', flexDirection: large ? 'column' : 'row',
    alignItems: large ? 'stretch' : 'center',
    padding: large ? '6px 8px 14px' : '6px 8px',
    background: 'var(--bg)',
    borderBottom: '1px solid var(--border)',
  }}>
    <div style={{ display: 'flex', alignItems: 'center', gap: 4, minHeight: 48 }}>
      {onBack && (
        <button onClick={onBack} style={{
          width: 40, height: 40, borderRadius: 20,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          color: 'var(--fg)',
        }}>
          <IconBack size={22} />
        </button>
      )}
      {!large && (
        <div style={{
          fontSize: 18, fontWeight: 600, color: 'var(--fg)', letterSpacing: '-0.01em',
          paddingLeft: onBack ? 4 : 14,
          flex: 1,
        }}>{title}</div>
      )}
      {large && <div style={{ flex: 1 }} />}
      {right && <div style={{ display: 'flex', gap: 4, paddingRight: 8 }}>{right}</div>}
    </div>
    {large && (
      <div style={{
        padding: '6px 16px 0',
        fontSize: 30, fontWeight: 600, color: 'var(--fg)',
        letterSpacing: '-0.02em',
      }}>{title}</div>
    )}
  </div>
);

// Bottom nav — 3 tabs
const BottomNav = ({ tab, onChange, t }) => {
  const items = [
    { key: 'home', label: t.tab_home, Icon: IconHome },
    { key: 'reports', label: t.tab_reports, Icon: IconChart },
    { key: 'settings', label: t.tab_settings, Icon: IconSettings },
  ];
  return (
    <div style={{
      display: 'flex', borderTop: '1px solid var(--border)',
      background: 'var(--bg-elev)',
      padding: '6px 0 4px',
    }}>
      {items.map(({ key, label, Icon }) => {
        const active = tab === key;
        return (
          <button key={key} onClick={() => onChange(key)} style={{
            flex: 1, padding: '8px 0', display: 'flex', flexDirection: 'column',
            alignItems: 'center', gap: 2,
          }}>
            <div style={{
              padding: '4px 18px',
              borderRadius: 14,
              background: active ? 'var(--accent-tint)' : 'transparent',
              color: active ? 'var(--accent)' : 'var(--fg-dim)',
              transition: 'background .15s',
            }}>
              <Icon size={22} />
            </div>
            <div style={{
              fontSize: 11, fontWeight: 500,
              color: active ? 'var(--accent)' : 'var(--fg-dim)',
              letterSpacing: '0.02em',
            }}>{label}</div>
          </button>
        );
      })}
    </div>
  );
};

// Section label (monospace uppercase)
const SectionLabel = ({ children, right }) => (
  <div style={{
    display: 'flex', alignItems: 'center', justifyContent: 'space-between',
    padding: '20px 20px 8px',
  }}>
    <div style={{
      fontSize: 10.5,
      fontFamily: "'JetBrains Mono', monospace",
      letterSpacing: '0.16em',
      textTransform: 'uppercase',
      color: 'var(--fg-dimmer)',
      fontWeight: 500,
    }}>{children}</div>
    {right && <div>{right}</div>}
  </div>
);

// Modal / sheet
const Sheet = ({ open, onClose, children, title }) => {
  if (!open) return null;
  return (
    <div style={{
      position: 'absolute', inset: 0, zIndex: 50,
      display: 'flex', alignItems: 'flex-end',
      background: 'rgba(0,0,0,.5)',
      animation: 'fadeIn .2s ease-out',
    }} onClick={onClose}>
      <div
        onClick={(e) => e.stopPropagation()}
        style={{
          width: '100%',
          background: 'var(--bg-elev)',
          borderTopLeftRadius: 22, borderTopRightRadius: 22,
          padding: 20,
          maxHeight: '80%',
          overflowY: 'auto',
          animation: 'slideUp .25s cubic-bezier(.2,.8,.2,1)',
          border: '1px solid var(--border)',
          borderBottom: 'none',
        }}
      >
        <div style={{
          width: 36, height: 4, borderRadius: 2, background: 'var(--border-strong)',
          margin: '0 auto 18px',
        }}/>
        {title && (
          <div style={{
            fontSize: 20, fontWeight: 600, marginBottom: 14, letterSpacing: '-0.01em',
          }}>{title}</div>
        )}
        {children}
      </div>
    </div>
  );
};

// Radio row for sheets
const RadioRow = ({ label, selected, onClick, right }) => (
  <button onClick={onClick} style={{
    display: 'flex', alignItems: 'center', gap: 12, width: '100%',
    padding: '14px 0', textAlign: 'left',
  }}>
    <div style={{
      width: 20, height: 20, borderRadius: 10,
      border: `2px solid ${selected ? 'var(--accent)' : 'var(--border-strong)'}`,
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      flexShrink: 0,
    }}>
      {selected && <div style={{
        width: 10, height: 10, borderRadius: 5, background: 'var(--accent)',
      }}/>}
    </div>
    <div style={{ flex: 1, fontSize: 15, color: 'var(--fg)' }}>{label}</div>
    {right}
  </button>
);

Object.assign(window, {
  STRINGS, fmtKm, fmtEur, fmtInt,
  MOCK_TRIPS, MOCK_MONTH, MOCK_VEHICLES, MOCK_WORKPLACES,
  Card, Switch, SettingRow, StatusChip, TopBar, BottomNav, SectionLabel, Sheet, RadioRow,
});
