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

// ── Trip Detail editor ───────────────────────────────────────────────
function TripDetailEditor({ lang, onClose, onSave }) {
  const t = STRINGS[lang];
  const [type, setType] = React.useState('business');
  const [odoStart, setOdoStart] = React.useState(42180);
  const [odoEnd, setOdoEnd] = React.useState(42205);
  const [company, setCompany] = React.useState('Nokia Oyj');
  const [notes, setNotes] = React.useState('');
  const km = Math.max(0, odoEnd - odoStart);

  return (
    <div style={{ padding: '18px 16px 24px' }}>
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

      {/* Odometer in/out */}
      <div style={{
        display: 'grid', gridTemplateColumns: '1fr auto 1fr', gap: 10,
        marginBottom: 16,
      }}>
        <OdoField label={lang === 'fi' ? 'Alku' : 'Start'} value={odoStart} onChange={setOdoStart}/>
        <div style={{ display: 'flex', alignItems: 'center', color: 'var(--fg-dimmer)', paddingTop: 16 }}>→</div>
        <OdoField label={lang === 'fi' ? 'Loppu' : 'End'} value={odoEnd} onChange={setOdoEnd}/>
      </div>

      {/* Computed km */}
      <div style={{
        padding: '14px 16px', borderRadius: 12,
        background: 'var(--accent-tint)',
        border: '1px solid var(--accent)',
        display: 'flex', alignItems: 'baseline', justifyContent: 'space-between',
        marginBottom: 20,
      }}>
        <div style={{
          fontSize: 10, fontFamily: "'JetBrains Mono', monospace",
          color: 'var(--accent)', letterSpacing: '0.12em',
        }}>{lang === 'fi' ? 'MATKA' : 'DISTANCE'}</div>
        <div className="tnum" style={{
          fontSize: 26, fontWeight: 600, color: 'var(--accent)',
        }}>{fmtKm(km, lang)} <span style={{ fontSize: 13, opacity: 0.7 }}>km</span></div>
      </div>

      <LabeledInput label={lang === 'fi' ? 'Yritys' : 'Company'} value={company} onChange={setCompany}/>
      <LabeledInput label={lang === 'fi' ? 'Muistiinpanot' : 'Notes'} value={notes} onChange={setNotes} multiline/>

      <div style={{ display: 'flex', gap: 10, marginTop: 6 }}>
        <button onClick={onClose} style={{
          flex: 1, padding: '14px', borderRadius: 12,
          background: 'var(--bg-inset)', color: 'var(--fg)',
          border: '1px solid var(--border)', fontSize: 14, fontWeight: 500,
        }}>{t.cancel}</button>
        <button onClick={onSave} style={{
          flex: 2, padding: '14px', borderRadius: 12,
          background: 'var(--accent)', color: 'var(--accent-ink)',
          fontSize: 14, fontWeight: 600,
        }}>{t.save}</button>
      </div>
    </div>
  );
}

function OdoField({ label, value, onChange }) {
  return (
    <div>
      <div style={{
        fontSize: 10, fontFamily: "'JetBrains Mono', monospace",
        color: 'var(--fg-dimmer)', letterSpacing: '0.1em', marginBottom: 4,
      }}>{label.toUpperCase()}</div>
      <input
        value={fmtInt(value)}
        onChange={(e) => onChange(parseInt(e.target.value.replace(/\D/g, '')) || 0)}
        style={{
          width: '100%', padding: '12px 14px', borderRadius: 12,
          background: 'var(--bg-inset)', border: '1px solid var(--border)',
          color: 'var(--fg)', fontSize: 16, fontWeight: 600,
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
