// MileLog — App shell with 5-tab nav + FAB, screens per device

const { useState, useEffect } = React;

function Phone({ theme, palette, children, label }) {
  return (
    <div className="device-wrap">
      <div className="stage-label">{label}</div>
      <AndroidDevice dark={theme === 'dark'} width={380} height={820}>
        <div data-theme={theme} data-palette={palette} className="screen" style={{
          background: 'var(--bg)',
          display: 'flex', flexDirection: 'column',
          position: 'relative',
        }}>
          {children}
        </div>
      </AndroidDevice>
    </div>
  );
}

function PhoneShell({ theme, palette, lang, startTab, label }) {
  const [tab, setTab] = useState(startTab);
  const [tripSheet, setTripSheet] = useState(false);
  const [tripDetail, setTripDetail] = useState(false);
  const [tripActive, setTripActive] = useState(startTab === 'navigation');
  const t = STRINGS[lang];

  // Apply theme+palette to this phone only
  useEffect(() => {
    const el = document.querySelectorAll(`[data-phone-label="${label}"]`);
    el.forEach(e => {
      e.dataset.theme = theme;
      e.dataset.palette = palette;
    });
  }, [theme, palette, label]);

  const onFabAction = (k) => {
    if (k === 'trip') setTripSheet(true);
    else if (k === 'mileage') setTripDetail(true);
    else if (k === 'odometer') setTab('odometer');
  };

  const renderScreen = () => {
    if (tripActive) return <ActiveNavigation lang={lang} onStop={() => { setTripActive(false); setTripDetail(true); }}/>;
    if (tab === 'navigation') {
      return (
        <div style={{ padding: 40, textAlign: 'center' }}>
          <div style={{
            width: 72, height: 72, borderRadius: 36, margin: '40px auto 24px',
            background: 'var(--accent-tint)', color: 'var(--accent)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <IconNavigation size={36}/>
          </div>
          <div style={{ fontSize: 20, fontWeight: 600, color: 'var(--fg)', marginBottom: 8 }}>
            {lang === 'fi' ? 'Ei aktiivista matkaa' : 'No active trip'}
          </div>
          <div style={{ fontSize: 13, color: 'var(--fg-dim)', marginBottom: 24, lineHeight: 1.5 }}>
            {lang === 'fi' ? 'Paina oranssia nappia aloittaaksesi matkan.' : 'Tap the accent button to start tracking a trip.'}
          </div>
          <button onClick={() => setTripActive(true)} style={{
            padding: '12px 24px', borderRadius: 12,
            background: 'var(--accent)', color: 'var(--accent-ink)',
            fontSize: 14, fontWeight: 600,
          }}>{lang === 'fi' ? 'Käynnistä demo' : 'Launch demo trip'}</button>
        </div>
      );
    }
    if (tab === 'trips') return <Dashboard lang={lang} theme={theme}/>;
    if (tab === 'reports') return <Reports lang={lang}/>;
    if (tab === 'settings') return <Settings lang={lang} theme={theme} onTheme={() => {}} onLang={() => {}}/>;
    if (tab === 'odometer') return <OdometerLog lang={lang}/>;
    return null;
  };

  return (
    <>
      <div data-screen-label={`${label} ${tripActive ? 'Active Navigation' : tab}`} style={{
        flex: 1, overflowY: 'auto', position: 'relative',
      }}>
        {renderScreen()}
      </div>
      {!tripActive && (
        <NavBar5
          tab={tab} onChange={setTab} t={t}
          onStartTrip={() => setTripSheet(true)}
          onFabAction={onFabAction}
        />
      )}

      <Sheet open={tripSheet} onClose={() => setTripSheet(false)} title={t.start_trip}>
        <StartTripSheet lang={lang} onClose={() => setTripSheet(false)}
          onStart={() => { setTripSheet(false); setTripActive(true); }}/>
      </Sheet>

      <Sheet open={tripDetail} onClose={() => setTripDetail(false)} title={lang === 'fi' ? 'Matkan tiedot' : 'Trip details'}>
        <TripDetailEditor lang={lang}
          onClose={() => setTripDetail(false)}
          onSave={() => setTripDetail(false)}/>
      </Sheet>
    </>
  );
}

function App() {
  const [theme, setTheme] = useState(window.__TWEAKS.theme || 'dark');
  const [palette, setPalette] = useState(window.__TWEAKS.palette || 'magenta');
  const [lang, setLang] = useState(window.__TWEAKS.language || 'en');

  useEffect(() => {
    document.documentElement.dataset.theme = theme;
    document.documentElement.dataset.palette = palette;
  }, [theme, palette]);

  useEffect(() => {
    const onMsg = (e) => {
      const d = e.data || {};
      if (d.type === '__activate_edit_mode') document.getElementById('tweaks').classList.add('on');
      else if (d.type === '__deactivate_edit_mode') document.getElementById('tweaks').classList.remove('on');
    };
    window.addEventListener('message', onMsg);
    window.parent.postMessage({ type: '__edit_mode_available' }, '*');

    const wireSeg = (id, cur, set, key) => {
      const seg = document.getElementById(id);
      if (!seg) return;
      seg.querySelectorAll('button').forEach(b => {
        b.classList.toggle('sel', b.dataset.v === cur);
        b.onclick = () => {
          set(b.dataset.v);
          window.parent.postMessage({ type: '__edit_mode_set_keys', edits: { [key]: b.dataset.v } }, '*');
        };
      });
    };
    wireSeg('themeSeg', theme, setTheme, 'theme');
    wireSeg('paletteSeg', palette, setPalette, 'palette');
    wireSeg('langSeg', lang, setLang, 'language');

    return () => window.removeEventListener('message', onMsg);
  }, [theme, palette, lang]);

  const phones = [
    { label: '01 · DRIVE', start: 'navigation' },
    { label: '02 · REPORTS', start: 'reports' },
    { label: '03 · SETTINGS', start: 'settings' },
  ];

  return (
    <>
      {phones.map(p => (
        <Phone key={p.label} theme={theme} palette={palette} label={p.label}>
          <PhoneShell theme={theme} palette={palette} lang={lang} startTab={p.start} label={p.label}/>
        </Phone>
      ))}
    </>
  );
}

ReactDOM.createRoot(document.getElementById('stage')).render(<App/>);
