// MileLog — Active Navigation + Trip Detail + Odometer Log + Start Trip sheet

// ── Active Navigation (trip in progress) ────────────────────────────
function ActiveNavigation({ lang, onStop }) {
  const t = STRINGS[lang];
  const [elapsed, setElapsed] = React.useState(1847); // seconds
  const [km, setKm] = React.useState(23.4);
  const [speed, setSpeed] = React.useState(62);

  React.useEffect(() => {
    const id = setInterval(() => {
      setElapsed(e => e + 1);
      setKm(k => +(k + 0.02).toFixed(2));
      setSpeed(s => Math.max(30, Math.min(90, s + (Math.random() - 0.5) * 4)));
    }, 1000);
    return () => clearInterval(id);
  }, []);

  const hh = Math.floor(elapsed / 3600);
  const mm = Math.floor((elapsed % 3600) / 60).toString().padStart(2, '0');
  const ss = (elapsed % 60).toString().padStart(2, '0');

  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', background: 'var(--bg)' }}>
      {/* Map area */}
      <div style={{ flex: 1, position: 'relative', background: 'var(--bg-inset)', overflow: 'hidden' }}>
        <svg width="100%" height="100%" viewBox="0 0 380 400" preserveAspectRatio="xMidYMid slice" style={{ display: 'block' }}>
          <defs>
            <pattern id="gridBig" width="24" height="24" patternUnits="userSpaceOnUse">
              <circle cx="1" cy="1" r="0.7" fill="var(--fg-ghost)" opacity="0.35"/>
            </pattern>
          </defs>
          <rect width="380" height="400" fill="url(#gridBig)"/>
          {/* roads */}
          <path d="M-20 340 Q 100 340, 140 260 T 260 180 Q 320 140, 400 170" stroke="var(--border-strong)" strokeWidth="10" fill="none" strokeLinecap="round" opacity="0.6"/>
          <path d="M80 0 L 120 400" stroke="var(--border-strong)" strokeWidth="5" fill="none" opacity="0.4"/>
          <path d="M260 0 L 300 400" stroke="var(--border-strong)" strokeWidth="5" fill="none" opacity="0.4"/>
          {/* traveled */}
          <path d="M-20 340 Q 100 340, 140 260" stroke="var(--accent)" strokeWidth="4" fill="none" strokeLinecap="round"/>
          {/* remaining */}
          <path d="M140 260 T 260 180 Q 320 140, 400 170" stroke="var(--accent)" strokeWidth="4" fill="none" strokeLinecap="round" strokeDasharray="4 6" opacity="0.5"/>
          {/* start */}
          <g transform="translate(20,340)">
            <circle r="11" fill="var(--bg-elev)" stroke="var(--accent)" strokeWidth="3"/>
            <circle r="4" fill="var(--accent)"/>
          </g>
          {/* current vehicle — triangle */}
          <g transform="translate(140,260) rotate(-40)">
            <circle r="18" fill="var(--accent)" opacity="0.2"/>
            <circle r="13" fill="var(--accent-ink)" stroke="var(--accent)" strokeWidth="2.5"/>
            <path d="M0 -6 L 4 4 L -4 4 Z" fill="var(--accent)"/>
          </g>
        </svg>
        {/* Top status pill */}
        <div style={{
          position: 'absolute', top: 14, left: 14, right: 14,
          display: 'flex', justifyContent: 'space-between', gap: 8,
        }}>
          <StatusChip tone="success"><IconSignal size={11}/> GPS</StatusChip>
          <StatusChip tone="accent" dot={false}>
            <span className="pulse-dot" style={{ width: 6, height: 6, borderRadius: 3, background: 'var(--accent)', display: 'inline-block' }}/>
            {t.active_trip_banner || 'Recording'}
          </StatusChip>
        </div>
        {/* Speed badge */}
        <div style={{
          position: 'absolute', bottom: 16, left: 14,
          background: 'var(--bg-elev)', border: '1px solid var(--border)',
          borderRadius: 14, padding: '10px 14px',
          display: 'flex', alignItems: 'baseline', gap: 4,
        }}>
          <span className="tnum" style={{ fontSize: 26, fontWeight: 600, color: 'var(--fg)' }}>{Math.round(speed)}</span>
          <span style={{ fontSize: 11, color: 'var(--fg-dim)', fontFamily: "'JetBrains Mono', monospace" }}>km/h</span>
        </div>
      </div>

      {/* Bottom sheet — distance + stop */}
      <div style={{
        background: 'var(--bg-elev)',
        borderTop: '1px solid var(--border)',
        padding: '18px 18px 16px',
      }}>
        <div style={{
          fontSize: 10.5, fontFamily: "'JetBrains Mono', monospace",
          color: 'var(--fg-dimmer)', letterSpacing: '0.14em', marginBottom: 4,
        }}>TRIP IN PROGRESS · BUSINESS</div>
        <div style={{
          display: 'flex', alignItems: 'baseline', justifyContent: 'space-between',
          marginBottom: 14,
        }}>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 8 }}>
            <div className="tnum" style={{
              fontSize: 58, fontWeight: 600, color: 'var(--fg)',
              letterSpacing: '-0.03em', lineHeight: 1,
            }}>{fmtKm(km, lang)}</div>
            <div style={{ fontSize: 18, color: 'var(--fg-dim)', fontWeight: 500 }}>km</div>
          </div>
          <div style={{ textAlign: 'right' }}>
            <div className="tnum" style={{ fontSize: 20, fontWeight: 600, color: 'var(--fg)' }}>
              {hh > 0 && `${hh}:`}{mm}:{ss}
            </div>
            <div style={{ fontSize: 10, color: 'var(--fg-dimmer)', fontFamily: "'JetBrains Mono', monospace", letterSpacing: '0.1em' }}>ELAPSED</div>
          </div>
        </div>
        {/* Route snippet */}
        <div style={{
          display: 'flex', alignItems: 'center', gap: 10,
          padding: '10px 12px', borderRadius: 10,
          background: 'var(--bg-inset)', marginBottom: 14,
          fontSize: 12,
        }}>
          <div style={{ width: 8, height: 8, borderRadius: 4, border: '1.5px solid var(--fg-dim)' }}/>
          <span style={{ color: 'var(--fg-dim)' }}>Kotitoimisto</span>
          <span style={{ flex: 1, textAlign: 'center', color: 'var(--fg-dimmer)', fontFamily: "'JetBrains Mono', monospace" }}>→</span>
          <span style={{ color: 'var(--fg)', fontWeight: 500 }}>Tampere</span>
          <div style={{ width: 8, height: 8, borderRadius: 4, background: 'var(--accent)' }}/>
        </div>
        <button onClick={onStop} style={{
          width: '100%', padding: '14px', borderRadius: 14,
          background: 'var(--danger)', color: '#fff',
          display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
          fontSize: 15, fontWeight: 600,
        }}>
          <IconStop size={18} color="#fff"/>
          {lang === 'fi' ? 'Lopeta matka' : 'End trip'}
        </button>
      </div>
    </div>
  );
}

// ── Trip Route Map — full route with start / stops / end markers ─────
function TripRouteMap({ lang, height = 200 }) {
  const stops = [
    { x: 38,  y: 250, name: lang === 'fi' ? 'Lähtö' : 'Start', sub: 'Kotitoimisto · 09:00', kind: 'start' },
    { x: 120, y: 200, name: lang === 'fi' ? 'Tauko' : 'Stop', sub: 'Neste, Hämeenlinna · 09:52', kind: 'stop' },
    { x: 230, y: 150, name: lang === 'fi' ? 'Pysähdys' : 'Stop', sub: 'Asiakas, Valkeakoski · 10:30', kind: 'stop' },
    { x: 332, y: 96,  name: lang === 'fi' ? 'Määränpää' : 'End', sub: 'Metso HQ, Tampere · 11:08', kind: 'end' },
  ];
  const path = `M ${stops[0].x} ${stops[0].y} Q 80 250 ${stops[1].x} ${stops[1].y} T ${stops[2].x} ${stops[2].y} Q 290 130 ${stops[3].x} ${stops[3].y}`;
  return (
    <div style={{
      position: 'relative', height, borderRadius: 14, overflow: 'hidden',
      background: 'var(--bg-inset)', border: '1px solid var(--border)',
    }}>
      <svg width="100%" height="100%" viewBox="0 0 380 300" preserveAspectRatio="xMidYMid slice" style={{ display: 'block' }}>
        <defs>
          <pattern id="tripGrid" width="22" height="22" patternUnits="userSpaceOnUse">
            <circle cx="1" cy="1" r="0.7" fill="var(--fg-ghost)" opacity="0.35"/>
          </pattern>
        </defs>
        <rect width="380" height="300" fill="url(#tripGrid)"/>
        {/* background roads */}
        <path d="M-20 270 Q 120 250, 180 180 T 400 70" stroke="var(--border-strong)" strokeWidth="9" fill="none" strokeLinecap="round" opacity="0.5"/>
        <path d="M60 0 L 95 300" stroke="var(--border-strong)" strokeWidth="4" fill="none" opacity="0.35"/>
        <path d="M230 0 L 270 300" stroke="var(--border-strong)" strokeWidth="4" fill="none" opacity="0.35"/>
        {/* the driven route */}
        <path d={path} stroke="var(--accent)" strokeWidth="3.5" fill="none" strokeLinecap="round"/>
        {/* intermediate stop markers */}
        {stops.filter(s => s.kind === 'stop').map((s, i) => (
          <g key={i} transform={`translate(${s.x},${s.y})`}>
            <circle r="7" fill="var(--bg-elev)" stroke="var(--accent)" strokeWidth="2.5"/>
            <circle r="2.5" fill="var(--accent)"/>
          </g>
        ))}
        {/* start marker — ringed circle */}
        <g transform={`translate(${stops[0].x},${stops[0].y})`}>
          <circle r="13" fill="var(--accent)" opacity="0.18"/>
          <circle r="9" fill="var(--bg-elev)" stroke="var(--accent)" strokeWidth="3"/>
          <circle r="3.5" fill="var(--accent)"/>
        </g>
        {/* end marker — teardrop pin */}
        <g transform={`translate(${stops[3].x},${stops[3].y})`}>
          <circle cx="0" cy="0" r="14" fill="var(--accent)" opacity="0.16"/>
          <path d="M 0 -16 Q -10 -16 -10 -5 Q -10 4 0 14 Q 10 4 10 -5 Q 10 -16 0 -16 Z" fill="var(--accent)"/>
          <circle cx="0" cy="-6" r="3.4" fill="var(--accent-ink)"/>
        </g>
      </svg>
      {/* corner legend */}
      <div style={{
        position: 'absolute', top: 10, left: 10, display: 'flex', gap: 6,
      }}>
        <span style={{
          fontSize: 9.5, fontFamily: "'JetBrains Mono', monospace",
          background: 'var(--bg-elev)', border: '1px solid var(--border)',
          color: 'var(--fg-dim)', padding: '3px 7px', borderRadius: 5, letterSpacing: '0.06em',
        }}>4 {lang === 'fi' ? 'PISTETTÄ' : 'POINTS'} · 182 KM</span>
      </div>
      <div style={{
        position: 'absolute', bottom: 10, right: 10,
        fontSize: 9, fontFamily: "'JetBrains Mono', monospace",
        background: 'var(--bg-elev)', border: '1px solid var(--border)',
        color: 'var(--fg-dimmer)', padding: '2px 6px', borderRadius: 4,
      }}>61.49°N · 23.76°E</div>
    </div>
  );
}

// Stop list — vertical timeline of all points
function TripStopList({ lang }) {
  const stops = [
    { name: 'Kotitoimisto, Helsinki', time: '09:00', kind: 'start', meta: lang === 'fi' ? 'Lähtö' : 'Departure' },
    { name: 'Neste, Hämeenlinna', time: '09:52', kind: 'stop', meta: lang === 'fi' ? 'Tauko 8 min' : 'Break · 8 min' },
    { name: 'Asiakas, Valkeakoski', time: '10:30', kind: 'stop', meta: lang === 'fi' ? 'Pysähdys 15 min' : 'Stop · 15 min' },
    { name: 'Metso HQ, Tampere', time: '11:08', kind: 'end', meta: lang === 'fi' ? 'Saapuminen' : 'Arrival' },
  ];
  return (
    <div style={{ paddingTop: 4 }}>
      {stops.map((s, i) => {
        const last = i === stops.length - 1;
        const isEnd = s.kind === 'end';
        const isStart = s.kind === 'start';
        return (
          <div key={i} style={{ display: 'flex', gap: 12 }}>
            <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
              {isStart && <div style={{ width: 11, height: 11, borderRadius: '50%', border: '2.5px solid var(--accent)', background: 'var(--bg-elev)' }}/>}
              {s.kind === 'stop' && <div style={{ width: 9, height: 9, borderRadius: '50%', border: '2px solid var(--accent)', background: 'var(--bg-elev)', marginTop: 1 }}/>}
              {isEnd && <div style={{ width: 11, height: 11, borderRadius: '50% 50% 50% 0', background: 'var(--accent)', transform: 'rotate(45deg)' }}/>}
              {!last && <div style={{ flex: 1, width: 2, minHeight: 26, background: 'repeating-linear-gradient(to bottom, var(--accent) 0 4px, transparent 4px 8px)', opacity: 0.5, margin: '3px 0' }}/>}
            </div>
            <div style={{ flex: 1, paddingBottom: last ? 0 : 14 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', gap: 8 }}>
                <span style={{ fontSize: 13.5, fontWeight: 500, color: 'var(--fg)' }}>{s.name}</span>
                <span className="mono" style={{ fontSize: 11, color: 'var(--fg-dim)', flexShrink: 0 }}>{s.time}</span>
              </div>
              <div style={{
                fontSize: 10.5, fontFamily: "'JetBrains Mono', monospace",
                color: 'var(--fg-dimmer)', letterSpacing: '0.04em', marginTop: 2,
                textTransform: 'uppercase',
              }}>{s.meta}</div>
            </div>
          </div>
        );
      })}
    </div>
  );
}

// ── Trip Detail editor (shown right after a trip ends) ───────────────
// lastReading = the vehicle's previously recorded odometer. The new start can
// never be below it, and end can never be below start — the audit guard.
function TripDetailEditor({ lang, onClose, onSave, recap = true, lastReading = 42180 }) {
  const t = STRINGS[lang];
  const L = (en, fi) => (lang === 'fi' ? fi : en);
  const [type, setType] = React.useState('business');
  const [odoStart, setOdoStart] = React.useState(42180);
  const [odoEnd, setOdoEnd] = React.useState(42362);
  const [company, setCompany] = React.useState('Metso Oyj');
  const [notes, setNotes] = React.useState('');

  // ── Validation: odometer can't go backwards ──
  const startTooLow = odoStart < lastReading;
  const endTooLow = odoEnd < odoStart;
  const km = Math.max(0, odoEnd - odoStart);
  const gpsKm = 182; // distance the GPS actually measured
  const mismatch = !startTooLow && !endTooLow && Math.abs(km - gpsKm) > 5;
  const valid = !startTooLow && !endTooLow;

  return (
    <div style={{ padding: '0 16px 24px' }}>
      {/* ── Trip recap (auto-captured) ── */}
      {recap && (
        <div style={{
          margin: '0 -16px 18px', padding: '4px 16px 18px',
          borderBottom: '1px solid var(--border)',
        }}>
          <div style={{
            display: 'flex', alignItems: 'center', gap: 8, marginBottom: 14,
          }}>
            <StatusChip tone="success"><IconCheck size={10}/>{lang === 'fi' ? 'Tallennettu' : 'Captured'}</StatusChip>
            <span style={{
              fontSize: 11, fontFamily: "'JetBrains Mono', monospace",
              color: 'var(--fg-dimmer)', letterSpacing: '0.06em',
            }}>18 APR · 09:00–11:08</span>
          </div>

          {/* Full route map with start / stops / end markers — GPS evidence, read-only */}
          <div style={{ position: 'relative' }}>
            <TripRouteMap lang={lang} height={190}/>
            <div style={{
              position: 'absolute', top: 10, right: 10,
              display: 'flex', alignItems: 'center', gap: 5,
              fontSize: 9, fontFamily: "'JetBrains Mono', monospace",
              background: 'var(--bg-elev)', border: '1px solid var(--border)',
              color: 'var(--fg-dim)', padding: '3px 7px', borderRadius: 5, letterSpacing: '0.06em',
            }}>
              <svg width="10" height="10" viewBox="0 0 24 24" fill="none"><path d="M6 11V8a6 6 0 0112 0v3M5 11h14v9H5z" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/></svg>
              {L('GPS-VERIFIED', 'GPS-VARMENNETTU')}
            </div>
          </div>
          <div style={{
            fontSize: 11, color: 'var(--fg-dimmer)', marginTop: 8, lineHeight: 1.4,
            display: 'flex', gap: 6, alignItems: 'flex-start',
          }}>
            <span style={{ color: 'var(--success)', marginTop: 1 }}>●</span>
            {L('The recorded route is locked as audit evidence and cannot be edited. Only the details below are editable.',
               'Tallennettu reitti on lukittu tositteeksi eikä sitä voi muokata. Vain alla olevat tiedot ovat muokattavissa.')}
          </div>

          {/* Vertical stop timeline */}
          <div style={{ marginTop: 16 }}>
            <TripStopList lang={lang}/>
          </div>

          {/* Recap metrics */}
          <div style={{
            display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 8,
            marginTop: 16,
          }}>
            {[
              { v: fmtKm(182.0, lang), u: 'km', l: lang === 'fi' ? 'Matka' : 'Distance' },
              { v: '2:08', u: 'h', l: lang === 'fi' ? 'Kesto' : 'Duration' },
              { v: '86', u: 'km/h', l: lang === 'fi' ? 'Keskinop.' : 'Avg speed' },
            ].map(s => (
              <div key={s.l} style={{
                background: 'var(--bg-inset)', borderRadius: 10, padding: '10px 12px',
              }}>
                <div style={{ display: 'flex', alignItems: 'baseline', gap: 3 }}>
                  <span className="tnum" style={{ fontSize: 19, fontWeight: 600, color: 'var(--fg)' }}>{s.v}</span>
                  <span style={{ fontSize: 10, color: 'var(--fg-dimmer)' }}>{s.u}</span>
                </div>
                <div style={{
                  fontSize: 9, fontFamily: "'JetBrains Mono', monospace",
                  color: 'var(--fg-dimmer)', letterSpacing: '0.08em',
                  textTransform: 'uppercase', marginTop: 3,
                }}>{s.l}</div>
              </div>
            ))}
          </div>
        </div>
      )}

      <div style={{
        fontSize: 10.5, fontFamily: "'JetBrains Mono', monospace",
        color: 'var(--fg-dimmer)', letterSpacing: '0.12em',
        textTransform: 'uppercase', marginBottom: 10,
      }}>{lang === 'fi' ? 'Luokittele matka' : 'Classify this trip'}</div>

      {/* Type segmented */}
      <div style={{
        display: 'flex', background: 'var(--bg-inset)',
        border: '1px solid var(--border)', borderRadius: 12, padding: 4, gap: 2,
        marginBottom: 18,
      }}>
        {[
          { k: 'business', l: t.business, I: IconBriefcase },
          { k: 'personal', l: t.personal, I: IconPersonal },
        ].map(({ k, l, I }) => (
          <button key={k} onClick={() => setType(k)} style={{
            flex: 1, padding: '10px', borderRadius: 9,
            background: type === k ? 'var(--accent-tint)' : 'transparent',
            color: type === k ? 'var(--accent)' : 'var(--fg-dim)',
            fontSize: 13, fontWeight: 600,
            display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
          }}>
            <I size={16}/>
            {l}
          </button>
        ))}
      </div>

      {/* Odometer in/out — with audit validation */}
      <div style={{
        fontSize: 10.5, fontFamily: "'JetBrains Mono', monospace",
        color: 'var(--fg-dimmer)', letterSpacing: '0.12em',
        textTransform: 'uppercase', marginBottom: 8,
        display: 'flex', justifyContent: 'space-between',
      }}>
        <span>{L('Odometer', 'Matkamittari')}</span>
        <span style={{ color: 'var(--fg-dim)' }}>{L('Last', 'Viim.')}: {fmtInt(lastReading)} km</span>
      </div>
      <div style={{
        display: 'grid', gridTemplateColumns: '1fr auto 1fr', gap: 10,
        marginBottom: startTooLow || endTooLow ? 8 : 16,
      }}>
        <OdoField label={lang === 'fi' ? 'Alku' : 'Start'} value={odoStart} onChange={setOdoStart} error={startTooLow}/>
        <div style={{ display: 'flex', alignItems: 'center', color: 'var(--fg-dimmer)', paddingTop: 16 }}>→</div>
        <OdoField label={lang === 'fi' ? 'Loppu' : 'End'} value={odoEnd} onChange={setOdoEnd} error={endTooLow}/>
      </div>

      {/* Validation messages */}
      {startTooLow && (
        <ValidationMsg tone="danger">
          {L(`Start can't be below the last reading (${fmtInt(lastReading)} km). The odometer never runs backwards.`,
             `Alku ei voi olla pienempi kuin viimeisin lukema (${fmtInt(lastReading)} km). Mittari ei koskaan vähene.`)}
        </ValidationMsg>
      )}
      {endTooLow && (
        <ValidationMsg tone="danger">
          {L('End reading must be greater than the start reading.',
             'Loppulukeman on oltava suurempi kuin alkulukema.')}
        </ValidationMsg>
      )}

      {/* Computed km */}
      <div style={{
        padding: '14px 16px', borderRadius: 12,
        background: valid ? 'var(--accent-tint)' : 'var(--bg-inset)',
        border: `1px solid ${valid ? 'var(--accent)' : 'var(--border)'}`,
        display: 'flex', alignItems: 'baseline', justifyContent: 'space-between',
        marginBottom: mismatch ? 8 : 20, marginTop: 8,
      }}>
        <div style={{
          fontSize: 10, fontFamily: "'JetBrains Mono', monospace",
          color: valid ? 'var(--accent)' : 'var(--fg-dimmer)', letterSpacing: '0.12em',
        }}>{lang === 'fi' ? 'MATKA' : 'DISTANCE'}</div>
        <div className="tnum" style={{
          fontSize: 26, fontWeight: 600, color: valid ? 'var(--accent)' : 'var(--fg-dim)',
        }}>{fmtKm(km, lang)} <span style={{ fontSize: 13, opacity: 0.7 }}>km</span></div>
      </div>

      {/* GPS cross-check warning */}
      {mismatch && (
        <ValidationMsg tone="warning">
          {L(`Entered distance (${fmtKm(km, lang)} km) differs from the GPS-measured ${gpsKm} km. Double-check the readings.`,
             `Syötetty matka (${fmtKm(km, lang)} km) poikkeaa GPS:n mittaamasta ${gpsKm} km:stä. Tarkista lukemat.`)}
        </ValidationMsg>
      )}
      <div style={{ height: mismatch ? 12 : 0 }}/>

      <LabeledInput label={lang === 'fi' ? 'Yritys' : 'Company'} value={company} onChange={setCompany}/>
      <LabeledInput label={lang === 'fi' ? 'Muistiinpanot' : 'Notes'} value={notes} onChange={setNotes} multiline/>

      <div style={{ display: 'flex', gap: 10, marginTop: 6 }}>
        <button onClick={onClose} style={{
          flex: 1, padding: '14px', borderRadius: 12,
          background: 'var(--bg-inset)', color: 'var(--fg)',
          border: '1px solid var(--border)', fontSize: 14, fontWeight: 500,
        }}>{t.cancel}</button>
        <button onClick={valid ? onSave : undefined} disabled={!valid} style={{
          flex: 2, padding: '14px', borderRadius: 12,
          background: valid ? 'var(--accent)' : 'var(--bg-inset)',
          color: valid ? 'var(--accent-ink)' : 'var(--fg-dimmer)',
          border: valid ? 'none' : '1px solid var(--border)',
          fontSize: 14, fontWeight: 600,
          cursor: valid ? 'pointer' : 'not-allowed',
        }}>{t.save}</button>
      </div>
    </div>
  );
}

function ValidationMsg({ tone, children }) {
  const c = tone === 'danger' ? 'var(--danger)' : 'var(--warning)';
  return (
    <div style={{
      display: 'flex', gap: 8, alignItems: 'flex-start',
      padding: '10px 12px', borderRadius: 10, marginBottom: 12,
      background: tone === 'danger' ? 'oklch(0.68 0.22 25 / 0.1)' : 'oklch(0.82 0.16 85 / 0.1)',
      border: `1px solid ${c}`,
    }}>
      <svg width="15" height="15" viewBox="0 0 24 24" fill="none" style={{ flexShrink: 0, marginTop: 1 }}>
        <path d="M12 8v5M12 16.5v.5" stroke={c} strokeWidth="2" strokeLinecap="round"/>
        <circle cx="12" cy="12" r="9" stroke={c} strokeWidth="1.6"/>
      </svg>
      <span style={{ fontSize: 12, color: 'var(--fg)', lineHeight: 1.4 }}>{children}</span>
    </div>
  );
}

function OdoField({ label, value, onChange, error }) {
  return (
    <div>
      <div style={{
        fontSize: 10, fontFamily: "'JetBrains Mono', monospace",
        color: error ? 'var(--danger)' : 'var(--fg-dimmer)', letterSpacing: '0.1em', marginBottom: 4,
      }}>{label.toUpperCase()}</div>
      <input
        value={fmtInt(value)}
        onChange={(e) => onChange(parseInt(e.target.value.replace(/\D/g, '')) || 0)}
        style={{
          width: '100%', padding: '12px 14px', borderRadius: 12,
          background: error ? 'oklch(0.68 0.22 25 / 0.08)' : 'var(--bg-inset)',
          border: `1px solid ${error ? 'var(--danger)' : 'var(--border)'}`,
          color: error ? 'var(--danger)' : 'var(--fg)', fontSize: 16, fontWeight: 600,
          fontVariantNumeric: 'tabular-nums', outline: 'none',
        }}
      />
    </div>
  );
}

function LabeledInput({ label, value, onChange, multiline }) {
  const Tag = multiline ? 'textarea' : 'input';
  return (
    <div style={{ marginBottom: 14 }}>
      <div style={{
        fontSize: 10, fontFamily: "'JetBrains Mono', monospace",
        color: 'var(--fg-dimmer)', letterSpacing: '0.1em', marginBottom: 4,
      }}>{label.toUpperCase()}</div>
      <Tag
        value={value}
        onChange={(e) => onChange(e.target.value)}
        rows={multiline ? 3 : undefined}
        style={{
          width: '100%', padding: '12px 14px', borderRadius: 12,
          background: 'var(--bg-inset)', border: '1px solid var(--border)',
          color: 'var(--fg)', fontSize: 14, outline: 'none',
          resize: 'none', fontFamily: 'inherit',
        }}
      />
    </div>
  );
}

// ── Odometer Log ─────────────────────────────────────────────────────
function OdometerLog({ lang }) {
  const t = STRINGS[lang];
  const entries = [
    { date: 'Apr 18', km: 42180, delta: 47 },
    { date: 'Apr 17', km: 42133, delta: 182 },
    { date: 'Apr 15', km: 41951, delta: 22 },
    { date: 'Apr 14', km: 41929, delta: 65 },
    { date: 'Apr 12', km: 41864, delta: 47 },
    { date: 'Apr 11', km: 41817, delta: 91 },
    { date: 'Apr 09', km: 41726, delta: 47 },
  ];
  const max = Math.max(...entries.map(e => e.delta));
  return (
    <div style={{ paddingBottom: 24 }}>
      <div style={{ padding: '6px 20px 14px' }}>
        <div style={{
          fontSize: 11, fontFamily: "'JetBrains Mono', monospace",
          color: 'var(--fg-dimmer)', letterSpacing: '0.14em',
        }}>VOLVO XC60 · RKT-842</div>
        <div style={{
          fontSize: 28, fontWeight: 600, letterSpacing: '-0.02em',
          color: 'var(--fg)', marginTop: 6,
        }}>{t.odometer_log}</div>
      </div>
      <div style={{ padding: '0 16px 14px' }}>
        <Card style={{ padding: 18 }}>
          <div style={{
            fontSize: 10, fontFamily: "'JetBrains Mono', monospace",
            color: 'var(--fg-dimmer)', letterSpacing: '0.14em',
          }}>{lang === 'fi' ? 'NYKYINEN LUKEMA' : 'CURRENT READING'}</div>
          <div className="tnum" style={{
            fontSize: 46, fontWeight: 600, color: 'var(--fg)',
            letterSpacing: '-0.02em', marginTop: 4,
          }}>{fmtInt(42180)} <span style={{ fontSize: 16, color: 'var(--fg-dim)' }}>km</span></div>
        </Card>
      </div>
      <Card style={{ margin: '0 16px', overflow: 'hidden' }}>
        {entries.map((e, i) => (
          <div key={i} style={{
            display: 'grid', gridTemplateColumns: '70px 1fr 70px',
            gap: 10, alignItems: 'center',
            padding: '12px 18px',
            borderBottom: i < entries.length - 1 ? '1px solid var(--border)' : 'none',
          }}>
            <div style={{
              fontSize: 11, fontFamily: "'JetBrains Mono', monospace",
              color: 'var(--fg-dim)', letterSpacing: '0.04em',
            }}>{e.date.toUpperCase()}</div>
            <div style={{
              height: 22, background: 'var(--bg-inset)', borderRadius: 6,
              overflow: 'hidden', position: 'relative',
            }}>
              <div style={{
                width: `${(e.delta / max) * 100}%`,
                height: '100%', background: 'var(--accent)',
                opacity: 0.8,
              }}/>
              <span className="tnum" style={{
                position: 'absolute', left: 8, top: '50%', transform: 'translateY(-50%)',
                fontSize: 11, color: 'var(--accent-ink)', fontWeight: 600,
              }}>+{e.delta} km</span>
            </div>
            <div className="tnum" style={{
              fontSize: 13, fontWeight: 600, color: 'var(--fg)', textAlign: 'right',
            }}>{fmtInt(e.km)}</div>
          </div>
        ))}
      </Card>
    </div>
  );
}

// ── Start-Trip Sheet (opened by FAB tap) ─────────────────────────────
function StartTripSheet({ lang, onClose, onStart }) {
  const t = STRINGS[lang];
  const [vehicle, setVehicle] = React.useState(MOCK_VEHICLES[0]);
  const [type, setType] = React.useState('business');
  return (
    <div>
      <div style={{ display: 'flex', gap: 8, marginBottom: 18 }}>
        {[
          { k: 'business', l: t.business, I: IconBriefcase },
          { k: 'personal', l: t.personal, I: IconPersonal },
        ].map(({ k, l, I }) => (
          <button key={k} onClick={() => setType(k)} style={{
            flex: 1, padding: '14px', borderRadius: 12,
            background: type === k ? 'var(--accent-tint)' : 'var(--bg-inset)',
            color: type === k ? 'var(--accent)' : 'var(--fg-dim)',
            border: `1px solid ${type === k ? 'var(--accent)' : 'var(--border)'}`,
            fontSize: 14, fontWeight: 600,
            display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
          }}>
            <I size={18}/>
            {l}
          </button>
        ))}
      </div>
      <div style={{
        fontSize: 10, fontFamily: "'JetBrains Mono', monospace",
        color: 'var(--fg-dimmer)', letterSpacing: '0.12em', marginBottom: 8,
      }}>{t.vehicles.toUpperCase()}</div>
      {MOCK_VEHICLES.map(v => (
        <button key={v.id} onClick={() => setVehicle(v)} style={{
          width: '100%', display: 'flex', alignItems: 'center', gap: 12,
          padding: '12px', borderRadius: 12, marginBottom: 8,
          background: vehicle.id === v.id ? 'var(--accent-tint)' : 'var(--bg-inset)',
          border: `1px solid ${vehicle.id === v.id ? 'var(--accent)' : 'var(--border)'}`,
        }}>
          <div style={{
            width: 38, height: 38, borderRadius: 10,
            background: 'var(--bg)', color: vehicle.id === v.id ? 'var(--accent)' : 'var(--fg-dim)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <IconVehicle size={22}/>
          </div>
          <div style={{ flex: 1, textAlign: 'left' }}>
            <div style={{ fontSize: 14, fontWeight: 600, color: 'var(--fg)' }}>{v.name}</div>
            <div className="mono" style={{ fontSize: 11, color: 'var(--fg-dim)', letterSpacing: '0.04em', marginTop: 2 }}>
              {v.plate} · {fmtInt(v.odo)} km
            </div>
          </div>
          {vehicle.id === v.id && <IconCheck size={18} color="var(--accent)"/>}
        </button>
      ))}

      <button onClick={onStart} style={{
        width: '100%', padding: '16px', borderRadius: 14, marginTop: 10,
        background: 'var(--accent)', color: 'var(--accent-ink)',
        display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 10,
        fontSize: 15, fontWeight: 600,
      }}>
        <IconPlay size={18}/>
        {t.start_trip}
      </button>
    </div>
  );
}

Object.assign(window, { ActiveNavigation, TripDetailEditor, OdometerLog, StartTripSheet });
