// MileLog — 5-tab nav with elevated center FAB
// Tap FAB = start trip. Swipe up (or long press) = reveal radial action menu.

function NavBar5({ tab, onChange, t, onStartTrip, onFabAction }) {
  const [fabMenu, setFabMenu] = React.useState(false);
  const [dragY, setDragY] = React.useState(0);
  const dragStart = React.useRef(null);

  const items = [
    { key: 'navigation', label: t.tab_navigation || (t === STRINGS.fi ? 'Ajo' : 'Drive'), Icon: IconNavigation },
    { key: 'trips', label: t.tab_trips || (t === STRINGS.fi ? 'Matkat' : 'Trips'), Icon: IconTrip },
    null, // FAB slot
    { key: 'reports', label: t.tab_reports, Icon: IconChart },
    { key: 'settings', label: t.tab_settings, Icon: IconSettings },
  ];

  const onPointerDown = (e) => {
    dragStart.current = e.clientY;
    setDragY(0);
  };
  const onPointerMove = (e) => {
    if (dragStart.current == null) return;
    const dy = dragStart.current - e.clientY;
    setDragY(Math.max(0, Math.min(80, dy)));
    if (dy > 40) setFabMenu(true);
  };
  const onPointerUp = (e) => {
    const dy = dragStart.current != null ? dragStart.current - e.clientY : 0;
    dragStart.current = null;
    if (dy < 8) {
      // tap
      onStartTrip?.();
    }
    setDragY(0);
  };

  return (
    <div style={{ position: 'relative' }}>
      {/* FAB radial menu */}
      {fabMenu && (
        <div
          onClick={() => setFabMenu(false)}
          style={{
            position: 'absolute', bottom: 0, left: 0, right: 0, height: 280,
            background: 'linear-gradient(to top, rgba(0,0,0,.75) 0%, rgba(0,0,0,0) 100%)',
            zIndex: 20,
            pointerEvents: 'auto',
          }}
        >
          <FabRadial t={t} onPick={(k) => { setFabMenu(false); onFabAction?.(k); }}/>
        </div>
      )}

      <div style={{
        display: 'flex', borderTop: '1px solid var(--border)',
        background: 'var(--bg-elev)',
        padding: '8px 0 6px',
        position: 'relative',
        zIndex: 30,
      }}>
        {items.map((item, i) => {
          if (item === null) {
            return (
              <div key="fab" style={{
                flex: 1, display: 'flex', justifyContent: 'center',
                position: 'relative',
              }}>
                <button
                  onPointerDown={onPointerDown}
                  onPointerMove={onPointerMove}
                  onPointerUp={onPointerUp}
                  onPointerCancel={() => { dragStart.current = null; setDragY(0); }}
                  style={{
                    position: 'absolute',
                    top: -26 - dragY,
                    width: 62, height: 62, borderRadius: 20,
                    background: 'var(--accent)',
                    color: 'var(--accent-ink)',
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                    boxShadow: '0 12px 28px oklch(0.72 0.19 5 / 0.45), 0 0 0 6px var(--bg)',
                    transition: dragStart.current ? 'none' : 'top .25s cubic-bezier(.2,.8,.2,1), transform .15s',
                    touchAction: 'none',
                  }}
                >
                  <IconPlay size={28} color="var(--accent-ink)"/>
                </button>
                {/* hint */}
                <div style={{
                  position: 'absolute', top: -48, fontSize: 8.5,
                  fontFamily: "'JetBrains Mono', monospace",
                  color: 'var(--fg-dimmer)', letterSpacing: '0.1em',
                  pointerEvents: 'none',
                  opacity: dragY > 0 ? 1 : 0.5,
                }}>↑ SWIPE</div>
              </div>
            );
          }
          const active = tab === item.key;
          const { Icon } = item;
          return (
            <button key={item.key} onClick={() => onChange(item.key)} style={{
              flex: 1, padding: '6px 0 2px', display: 'flex', flexDirection: 'column',
              alignItems: 'center', gap: 3,
            }}>
              <div style={{
                color: active ? 'var(--accent)' : 'var(--fg-dim)',
                transition: 'color .15s',
              }}>
                <Icon size={22}/>
              </div>
              <div style={{
                fontSize: 10.5, fontWeight: 500,
                color: active ? 'var(--accent)' : 'var(--fg-dim)',
              }}>{item.label}</div>
              {active && (
                <div style={{
                  width: 4, height: 4, borderRadius: 2, background: 'var(--accent)',
                  marginTop: -1,
                }}/>
              )}
            </button>
          );
        })}
      </div>
    </div>
  );
}

// Radial FAB actions — appears above the FAB
function FabRadial({ t, onPick }) {
  const actions = [
    { key: 'trip',     label: t.start_trip,  icon: <IconPlay size={22}/>, angle: -90 },
    { key: 'odometer', label: t === STRINGS.fi ? 'Matkamittari' : 'Odometer', icon: <IconOdometer size={22}/>, angle: -140 },
    { key: 'mileage',  label: t === STRINGS.fi ? 'Kirjaa matka' : 'Log trip', icon: <IconEdit size={22}/>, angle: -40 },
  ];
  return (
    <div style={{
      position: 'absolute', bottom: 60, left: '50%',
      transform: 'translateX(-50%)',
      width: 200, height: 200,
    }}>
      {actions.map((a, i) => {
        const r = 85;
        const rad = (a.angle * Math.PI) / 180;
        const x = Math.cos(rad) * r;
        const y = Math.sin(rad) * r;
        return (
          <button
            key={a.key}
            onClick={(e) => { e.stopPropagation(); onPick(a.key); }}
            style={{
              position: 'absolute',
              left: `calc(50% + ${x}px)`,
              top: `calc(50% + ${y}px)`,
              transform: 'translate(-50%, -50%)',
              display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6,
              animation: `fadeIn .25s ${i * 0.05}s both`,
            }}
          >
            <div style={{
              width: 52, height: 52, borderRadius: 18,
              background: 'var(--bg-elev-2)',
              border: '1px solid var(--border-strong)',
              color: 'var(--accent)',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              boxShadow: '0 8px 20px rgba(0,0,0,.4)',
            }}>{a.icon}</div>
            <div style={{
              fontSize: 10.5,
              fontFamily: "'JetBrains Mono', monospace",
              letterSpacing: '0.04em',
              color: 'var(--fg)',
              background: 'var(--bg)',
              padding: '3px 7px', borderRadius: 5,
              border: '1px solid var(--border)',
              whiteSpace: 'nowrap',
            }}>{a.label}</div>
          </button>
        );
      })}
    </div>
  );
}

// Navigation (arrow) icon
const IconNavigation = (p) => (
  <svg width={p.size || 24} height={p.size || 24} viewBox="0 0 24 24" fill="none">
    <path d="M12 3l7 17-7-4-7 4 7-17z" fill={p.color || 'currentColor'}/>
  </svg>
);
// Edit / pencil
const IconEdit = (p) => (
  <svg width={p.size || 24} height={p.size || 24} viewBox="0 0 24 24" fill="none">
    <path d="M14 4l6 6-11 11H3v-6L14 4z" fill={p.color || 'currentColor'}/>
    <path d="M14 4l2-2 6 6-2 2-6-6z" fill={p.color || 'currentColor'} opacity=".7"/>
  </svg>
);
// Stop square
const IconStop = (p) => (
  <svg width={p.size || 24} height={p.size || 24} viewBox="0 0 24 24" fill="none">
    <rect x="6" y="6" width="12" height="12" rx="2" fill={p.color || 'currentColor'}/>
  </svg>
);
// Document / PDF
const IconDoc = (p) => (
  <svg width={p.size || 24} height={p.size || 24} viewBox="0 0 24 24" fill="none">
    <path d="M6 3h9l4 4v13a2 2 0 01-2 2H6a2 2 0 01-2-2V5a2 2 0 012-2z" fill={p.color || 'currentColor'}/>
    <path d="M15 3v4h4" fill="var(--bg, #000)" opacity=".3"/>
  </svg>
);

Object.assign(window, { NavBar5, FabRadial, IconNavigation, IconEdit, IconStop, IconDoc });
