// MileLog — custom 24dp icon set. Filled glyphs, 24x24 viewBox.
// All icons accept size + color props.

const Icon = ({ children, size = 24, color = 'currentColor', fill = 'currentColor', ...rest }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" {...rest}>
    {typeof children === 'function' ? children({ color, fill }) : children}
  </svg>
);

// — Bluetooth
const IconBluetooth = (p) => (
  <Icon {...p}>
    <path d="M8 6l8 6-4 3V3l4 3-8 6" stroke={p.color || 'currentColor'} strokeWidth="1.8" strokeLinejoin="round" strokeLinecap="round" fill="none"/>
  </Icon>
);

// — Location / geofence
const IconLocation = (p) => (
  <Icon {...p}>
    <path d="M12 2a7 7 0 00-7 7c0 5.25 7 13 7 13s7-7.75 7-13a7 7 0 00-7-7z" fill={p.color || 'currentColor'}/>
    <circle cx="12" cy="9" r="2.4" fill="var(--bg-elev, #141822)"/>
  </Icon>
);

// — Cloud sync
const IconCloud = (p) => (
  <Icon {...p}>
    <path d="M7 18a4 4 0 01-.7-7.94A6 6 0 0118 10.5a3.5 3.5 0 01-.5 7H7z" fill={p.color || 'currentColor'}/>
    <path d="M10 13.5l2 2 4-4" stroke="var(--bg-elev, #141822)" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" fill="none"/>
  </Icon>
);

// — Odometer
const IconOdometer = (p) => (
  <Icon {...p}>
    <circle cx="12" cy="12" r="9" fill={p.color || 'currentColor'}/>
    <circle cx="12" cy="12" r="6.2" fill="var(--bg-elev, #141822)"/>
    <path d="M12 12l3.8-3.2" stroke={p.color || 'currentColor'} strokeWidth="1.8" strokeLinecap="round"/>
    <circle cx="12" cy="12" r="1.3" fill={p.color || 'currentColor'}/>
    <circle cx="6.5" cy="12" r=".8" fill={p.color || 'currentColor'} opacity=".6"/>
    <circle cx="17.5" cy="12" r=".8" fill={p.color || 'currentColor'} opacity=".6"/>
    <circle cx="9" cy="7.5" r=".7" fill={p.color || 'currentColor'} opacity=".5"/>
    <circle cx="15" cy="7.5" r=".7" fill={p.color || 'currentColor'} opacity=".5"/>
  </Icon>
);

// — Vehicle (car, top-down)
const IconVehicle = (p) => (
  <Icon {...p}>
    <path d="M5 10.5l1-4a2 2 0 012-1.5h8a2 2 0 012 1.5l1 4v7a1 1 0 01-1 1h-1a1 1 0 01-1-1v-1H7v1a1 1 0 01-1 1H5a1 1 0 01-1-1v-7z" fill={p.color || 'currentColor'}/>
    <circle cx="7.5" cy="13.5" r="1.1" fill="var(--bg-elev, #141822)"/>
    <circle cx="16.5" cy="13.5" r="1.1" fill="var(--bg-elev, #141822)"/>
    <rect x="7" y="6.5" width="10" height="3" rx="1" fill="var(--bg-elev, #141822)" opacity=".6"/>
  </Icon>
);

// — Money / rates (€ badge)
const IconMoney = (p) => (
  <Icon {...p}>
    <circle cx="12" cy="12" r="9" fill={p.color || 'currentColor'}/>
    <path d="M15 8.5a3.5 3.5 0 00-5.5 1.2M15 15.5a3.5 3.5 0 01-5.5-1.2M8 11h5M8 13h5" stroke="var(--bg-elev, #141822)" strokeWidth="1.6" strokeLinecap="round" fill="none"/>
  </Icon>
);

// — Profile
const IconProfile = (p) => (
  <Icon {...p}>
    <circle cx="12" cy="8.5" r="3.5" fill={p.color || 'currentColor'}/>
    <path d="M4.5 20c0-4 3.5-6.5 7.5-6.5s7.5 2.5 7.5 6.5" fill={p.color || 'currentColor'}/>
  </Icon>
);

// — Theme (half-circle)
const IconTheme = (p) => (
  <Icon {...p}>
    <circle cx="12" cy="12" r="8" fill="none" stroke={p.color || 'currentColor'} strokeWidth="1.6"/>
    <path d="M12 4a8 8 0 000 16z" fill={p.color || 'currentColor'}/>
  </Icon>
);

// — Trip arrow / route
const IconTrip = (p) => (
  <Icon {...p}>
    <circle cx="6" cy="6" r="2.2" fill={p.color || 'currentColor'}/>
    <circle cx="18" cy="18" r="2.2" fill={p.color || 'currentColor'}/>
    <path d="M6 8.5c0 5 6 4 6 9" stroke={p.color || 'currentColor'} strokeWidth="1.8" strokeLinecap="round" strokeDasharray="2 2" fill="none"/>
  </Icon>
);

// — Play (start trip)
const IconPlay = (p) => (
  <Icon {...p}>
    <path d="M8 5l11 7-11 7V5z" fill={p.color || 'currentColor'}/>
  </Icon>
);

// — Chevron right
const IconChevron = (p) => (
  <Icon {...p}>
    <path d="M9 6l6 6-6 6" stroke={p.color || 'currentColor'} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" fill="none"/>
  </Icon>
);

// — Back
const IconBack = (p) => (
  <Icon {...p}>
    <path d="M15 6l-6 6 6 6" stroke={p.color || 'currentColor'} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" fill="none"/>
  </Icon>
);

// — Plus
const IconPlus = (p) => (
  <Icon {...p}>
    <path d="M12 5v14M5 12h14" stroke={p.color || 'currentColor'} strokeWidth="2" strokeLinecap="round"/>
  </Icon>
);

// — Check
const IconCheck = (p) => (
  <Icon {...p}>
    <path d="M5 12l5 5 9-10" stroke={p.color || 'currentColor'} strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" fill="none"/>
  </Icon>
);

// — Signal (GPS)
const IconSignal = (p) => (
  <Icon {...p}>
    <rect x="4" y="14" width="3" height="6" rx="1" fill={p.color || 'currentColor'}/>
    <rect x="10" y="10" width="3" height="10" rx="1" fill={p.color || 'currentColor'}/>
    <rect x="16" y="5" width="3" height="15" rx="1" fill={p.color || 'currentColor'}/>
  </Icon>
);

// — Clock
const IconClock = (p) => (
  <Icon {...p}>
    <circle cx="12" cy="12" r="8.5" fill="none" stroke={p.color || 'currentColor'} strokeWidth="1.6"/>
    <path d="M12 7.5V12l3 2" stroke={p.color || 'currentColor'} strokeWidth="1.8" strokeLinecap="round" fill="none"/>
  </Icon>
);

// — Settings gear
const IconSettings = (p) => (
  <Icon {...p}>
    <path d="M12 2.5l1.6 2.3 2.7-.6.8 2.6 2.5 1.2-1 2.6 1 2.6-2.5 1.2-.8 2.6-2.7-.6L12 18.5l-1.6-2.3-2.7.6-.8-2.6L4.4 13l1-2.6-1-2.6 2.5-1.2.8-2.6 2.7.6L12 2.5z" fill={p.color || 'currentColor'}/>
    <circle cx="12" cy="10.5" r="2.8" fill="var(--bg, #0A0D12)"/>
  </Icon>
);

// — Chart / reports
const IconChart = (p) => (
  <Icon {...p}>
    <rect x="4" y="14" width="3.5" height="6" rx="1" fill={p.color || 'currentColor'}/>
    <rect x="10.25" y="9" width="3.5" height="11" rx="1" fill={p.color || 'currentColor'}/>
    <rect x="16.5" y="4" width="3.5" height="16" rx="1" fill={p.color || 'currentColor'}/>
  </Icon>
);

// — Home
const IconHome = (p) => (
  <Icon {...p}>
    <path d="M4 11l8-7 8 7v9a1 1 0 01-1 1h-4v-6h-6v6H5a1 1 0 01-1-1v-9z" fill={p.color || 'currentColor'}/>
  </Icon>
);

// — Search
const IconSearch = (p) => (
  <Icon {...p}>
    <circle cx="11" cy="11" r="6" fill="none" stroke={p.color || 'currentColor'} strokeWidth="2"/>
    <path d="M16 16l4 4" stroke={p.color || 'currentColor'} strokeWidth="2" strokeLinecap="round"/>
  </Icon>
);

// — Download
const IconDownload = (p) => (
  <Icon {...p}>
    <path d="M12 4v11m0 0l-4-4m4 4l4-4" stroke={p.color || 'currentColor'} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" fill="none"/>
    <path d="M5 18h14" stroke={p.color || 'currentColor'} strokeWidth="2" strokeLinecap="round"/>
  </Icon>
);

// — Briefcase (business)
const IconBriefcase = (p) => (
  <Icon {...p}>
    <rect x="3" y="7" width="18" height="13" rx="2" fill={p.color || 'currentColor'}/>
    <path d="M9 7V5.5A1.5 1.5 0 0110.5 4h3A1.5 1.5 0 0115 5.5V7" stroke={p.color || 'currentColor'} strokeWidth="1.6" fill="none"/>
    <rect x="3" y="11" width="18" height="1.5" fill="var(--bg-elev, #141822)" opacity=".5"/>
  </Icon>
);

// — Home (personal)
const IconPersonal = (p) => (
  <Icon {...p}>
    <path d="M4 11l8-7 8 7v9a1 1 0 01-1 1h-4v-6h-6v6H5a1 1 0 01-1-1v-9z" fill={p.color || 'currentColor'}/>
  </Icon>
);

Object.assign(window, {
  IconBluetooth, IconLocation, IconCloud, IconOdometer, IconVehicle,
  IconMoney, IconProfile, IconTheme, IconTrip, IconPlay, IconChevron,
  IconBack, IconPlus, IconCheck, IconSignal, IconClock, IconSettings,
  IconChart, IconHome, IconSearch, IconDownload, IconBriefcase, IconPersonal,
});
