// MileLog — Dashboard screen
// Distinctive moments:
//  - Huge tabular km figure with a 30-day sparkline beneath
//  - Business/personal split bar
//  - Auto-tracker status card with "corner bracket" chip + paired vehicle
//  - Recent trips with route glyph connecting from→to

// Sparkline — month km, with today marked
function Sparkline({ data, height = 44 }) {
  const max = Math.max(...data, 1);
  const W = 280;
  const H = height;
  const step = W / (data.length - 1);
  const pts = data.map((v, i) => [i * step, H - (v / max) * (H - 6) - 3]);
  const path = pts.map((p, i) => (i === 0 ? `M${p[0]},${p[1]}` : `L${p[0]},${p[1]}`)).join(' ');
  const area = path + ` L${W},${H} L0,${H} Z`;
  const todayIdx = data.length - 1;
  const [tx, ty] = pts[todayIdx];
  return (
    <svg width="100%" height={H} viewBox={`0 0 ${W} ${H}`} preserveAspectRatio="none" style={{ display: 'block' }}>
      <defs>
        <linearGradient id="sparkFill" x1="0" x2="0" y1="0" y2="1">
          <stop offset="0%" stopColor="var(--accent)" stopOpacity="0.25"/>
          <stop offset="100%" stopColor="var(--accent)" stopOpacity="0"/>
        </linearGradient>
      </defs>
      <path d={area} fill="url(#sparkFill)"/>
      <path d={path} fill="none" stroke="var(--accent)" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
      <circle cx={tx} cy={ty} r="3" fill="var(--accent)"/>
      <circle cx={tx} cy={ty} r="6" fill="var(--accent)" opacity="0.25"/>
    </svg>
  );
}

// Split bar — business vs personal
function SplitBar({ biz, personal }) {
  const total = biz + personal;
  const bizPct = (biz / total) * 100;
  return (
    <div>
      <div style={{
        display: 'flex', height: 6, borderRadius: 3, overflow: 'hidden',
        background: 'var(--bg-inset)',
      }}>
        <div style={{ width: `${bizPct}%`, background: 'var(--biz)' }}/>
        <div style={{ width: `${100 - bizPct}%`, background: 'var(--personal)', opacity: 0.7 }}/>
      </div>
    </div>
  );
}

// Trip item with route glyph
function TripItem({ trip, t, onClick }) {
  const isBiz = trip.type === 'business';
  return (
    <div
      onClick={onClick}
      style={{
        display: 'flex', gap: 14, padding: '14px 20px',
        alignItems: 'stretch',
        cursor: 'pointer',
        borderBottom: '1px solid var(--border)',
      }}
    >
      {/* Route glyph */}
      <div style={{
        display: 'flex', flexDirection: 'column', alignItems: 'center',
        paddingTop: 4, paddingBottom: 4,
      }}>
        <div style={{
          width: 9, height: 9, borderRadius: '50%',
          border: '1.8px solid var(--fg-dim)',
        }}/>
        <div style={{
          flex: 1, width: 1.5,
          background: 'repeating-linear-gradient(to bottom, var(--fg-ghost) 0 3px, transparent 3px 6px)',
          margin: '3px 0',
        }}/>
        <div style={{
          width: 9, height: 9, borderRadius: '50%',
          background: isBiz ? 'var(--biz)' : 'var(--personal)',
        }}/>
      </div>
      {/* Locations */}
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{
          fontSize: 14, color: 'var(--fg)', fontWeight: 500,
          whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
        }}>{trip.from}</div>
        <div style={{
          fontSize: 11, color: 'var(--fg-dimmer)', fontFamily: "'JetBrains Mono', monospace",
          letterSpacing: '0.02em', margin: '6px 0',
        }}>
          {trip.time} · {trip.min} {t.min} · {trip.company}
        </div>
        <div style={{
          fontSize: 14, color: 'var(--fg)', fontWeight: 500,
          whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
        }}>{trip.to}</div>
      </div>
      {/* Right metrics */}
      <div style={{
        display: 'flex', flexDirection: 'column', alignItems: 'flex-end', justifyContent: 'space-between',
        flexShrink: 0, minWidth: 68,
      }}>
        <div style={{
          fontSize: 16, fontWeight: 600, fontVariantNumeric: 'tabular-nums',
          color: 'var(--fg)',
        }}>
          {fmtKm(trip.km, t === STRINGS.fi ? 'fi' : 'en')}
          <span style={{ fontSize: 11, color: 'var(--fg-dimmer)', fontWeight: 500, marginLeft: 3 }}>km</span>
        </div>
        <div style={{
          fontSize: 9.5, fontFamily: "'JetBrains Mono', monospace",
          letterSpacing: '0.08em', textTransform: 'uppercase',
          color: isBiz ? 'var(--biz)' : 'var(--personal)',
          fontWeight: 500,
        }}>
          {isBiz ? t.business : t.personal}
        </div>
      </div>
    </div>
  );
}

// Mini map preview — abstract route
function MapPreview() {
  return (
    <div style={{
      position: 'relative', height: 88, borderRadius: 12,
      background: 'var(--bg-inset)',
      border: '1px solid var(--border)',
      overflow: 'hidden',
    }}>
      {/* grid dots */}
      <svg width="100%" height="100%" viewBox="0 0 340 88" style={{ position: 'absolute', inset: 0 }}>
        <defs>
          <pattern id="grid" width="16" height="16" patternUnits="userSpaceOnUse">
            <circle cx="1" cy="1" r="0.8" fill="var(--fg-ghost)" opacity="0.4"/>
          </pattern>
        </defs>
        <rect width="340" height="88" fill="url(#grid)"/>
        {/* roads */}
        <path d="M 0 60 Q 60 60, 90 40 T 180 35 Q 220 33, 260 55 L 340 55"
              stroke="var(--border-strong)" strokeWidth="6" fill="none" strokeLinecap="round"/>
        <path d="M 30 10 L 40 88" stroke="var(--border-strong)" strokeWidth="3" fill="none" opacity="0.6"/>
        <path d="M 200 0 L 210 88" stroke="var(--border-strong)" strokeWidth="3" fill="none" opacity="0.6"/>
        {/* route */}
        <path d="M 24 62 Q 64 62, 92 42 T 182 37 Q 222 35, 262 57"
              stroke="var(--accent)" strokeWidth="2.5" fill="none" strokeLinecap="round"
              strokeDasharray="180" strokeDashoffset="0"/>
        {/* start marker */}
        <circle cx="24" cy="62" r="6" fill="var(--bg-elev)" stroke="var(--accent)" strokeWidth="2.5"/>
        <circle cx="24" cy="62" r="2" fill="var(--accent)"/>
        {/* end marker — pin */}
        <g transform="translate(262,57)">
          <path d="M 0 -10 Q -7 -10 -7 -3 Q -7 3 0 10 Q 7 3 7 -3 Q 7 -10 0 -10Z" fill="var(--accent)"/>
          <circle cx="0" cy="-4" r="2.2" fill="var(--bg-elev)"/>
        </g>
      </svg>
      <div style={{
        position: 'absolute', bottom: 8, right: 10,
        fontSize: 9.5, fontFamily: "'JetBrains Mono', monospace",
        color: 'var(--fg-dim)', letterSpacing: '0.06em',
        background: 'var(--bg-elev)', padding: '2px 6px', borderRadius: 4,
        border: '1px solid var(--border)',
      }}>60.17°N · 24.94°E</div>
    </div>
  );
}

function Dashboard({ lang, theme, onNavigate }) {
  const t = STRINGS[lang];
  const m = MOCK_MONTH;
  const reim = m.businessKm * m.rate;
  const hour = new Date().getHours();
  const greet = hour < 12 ? t.greet_morning : hour < 18 ? t.greet_afternoon : t.greet_evening;
  const [autoOn, setAutoOn] = React.useState(true);

  return (
    <div style={{ paddingBottom: 24 }}>
      {/* Header */}
      <div style={{
        padding: '14px 20px 6px',
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      }}>
        <div>
          <div style={{
            fontSize: 11, fontFamily: "'JetBrains Mono', monospace",
            color: 'var(--fg-dimmer)', letterSpacing: '0.1em',
          }}>
            {greet.toUpperCase()}
          </div>
          <div style={{
            fontSize: 22, fontWeight: 600, letterSpacing: '-0.02em', color: 'var(--fg)',
            marginTop: 2,
          }}>
            Mikko V.
          </div>
        </div>
        <div style={{ display: 'flex', gap: 6 }}>
          <StatusChip tone="success" dot={true}>
            <IconSignal size={11}/>
            <span>{t.gps_strong}</span>
          </StatusChip>
        </div>
      </div>

      {/* Month stats hero card */}
      <div style={{ padding: '10px 16px 0' }}>
        <Card style={{ padding: 20, position: 'relative', overflow: 'hidden' }}>
          {/* Month label */}
          <div style={{
            display: 'flex', alignItems: 'center', justifyContent: 'space-between',
            marginBottom: 14,
          }}>
            <div style={{
              fontSize: 10.5, fontFamily: "'JetBrains Mono', monospace",
              color: 'var(--fg-dimmer)', letterSpacing: '0.14em', textTransform: 'uppercase',
            }}>
              {t.this_month} · APR 2026
            </div>
            <div style={{
              fontSize: 11, color: 'var(--fg-dim)', fontWeight: 500,
            }}>
              {m.trips} {t.trips}
            </div>
          </div>
          {/* Big KM figure */}
          <div style={{
            display: 'flex', alignItems: 'baseline', gap: 8, marginBottom: 4,
          }}>
            <div className="tnum" style={{
              fontSize: 54, fontWeight: 600, color: 'var(--fg)',
              letterSpacing: '-0.03em', lineHeight: 1,
            }}>
              {fmtKm(m.km, lang)}
            </div>
            <div style={{ fontSize: 16, color: 'var(--fg-dim)', fontWeight: 500 }}>km</div>
          </div>
          {/* Reimbursable */}
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 18 }}>
            <div style={{
              fontSize: 13, color: 'var(--fg-dim)',
            }}>{t.total_value}</div>
            <div className="tnum" style={{
              fontSize: 15, fontWeight: 600, color: 'var(--accent)',
            }}>
              {fmtEur(reim, lang)}
            </div>
            <div style={{
              fontSize: 10.5, fontFamily: "'JetBrains Mono', monospace",
              color: 'var(--fg-dimmer)', letterSpacing: '0.08em',
            }}>@ {lang === 'fi' ? '0,55' : '0.55'}/km</div>
          </div>
          {/* Sparkline */}
          <Sparkline data={m.daily} height={44}/>
          <div style={{
            display: 'flex', justifyContent: 'space-between', marginTop: 4,
            fontSize: 9.5, fontFamily: "'JetBrains Mono', monospace",
            color: 'var(--fg-dimmer)', letterSpacing: '0.06em',
          }}>
            <span>APR 01</span>
            <span>APR 19</span>
          </div>
          {/* Split */}
          <div style={{ marginTop: 18, display: 'flex', flexDirection: 'column', gap: 8 }}>
            <SplitBar biz={m.businessKm} personal={m.personalKm}/>
            <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 12 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                <span style={{ width: 8, height: 8, borderRadius: '50%', background: 'var(--biz)', display: 'inline-block' }}/>
                <span style={{ color: 'var(--fg-dim)' }}>{t.business}</span>
                <span className="tnum" style={{ color: 'var(--fg)', fontWeight: 600 }}>
                  {fmtKm(m.businessKm, lang)}
                </span>
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                <span style={{ width: 8, height: 8, borderRadius: '50%', background: 'var(--personal)', display: 'inline-block' }}/>
                <span style={{ color: 'var(--fg-dim)' }}>{t.personal}</span>
                <span className="tnum" style={{ color: 'var(--fg)', fontWeight: 600 }}>
                  {fmtKm(m.personalKm, lang)}
                </span>
              </div>
            </div>
          </div>
        </Card>
      </div>

      {/* Auto-tracker */}
      <div style={{ padding: '12px 16px 0' }}>
        <Card style={{ padding: 16 }}>
          <div style={{
            display: 'flex', alignItems: 'center', justifyContent: 'space-between',
            marginBottom: 12,
          }}>
            <div style={{
              fontSize: 10.5, fontFamily: "'JetBrains Mono', monospace",
              color: 'var(--fg-dimmer)', letterSpacing: '0.14em', textTransform: 'uppercase',
            }}>{t.auto_tracker}</div>
            <StatusChip tone={autoOn ? 'success' : 'dim'}>
              {autoOn ? t.active : t.standby}
            </StatusChip>
          </div>

          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <div style={{
              width: 44, height: 44, borderRadius: 12,
              background: 'var(--accent-tint)',
              color: 'var(--accent)',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              flexShrink: 0,
            }}>
              <IconVehicle size={24} color="currentColor"/>
            </div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontSize: 15, fontWeight: 500, color: 'var(--fg)' }}>Volvo XC60</div>
              <div style={{
                fontSize: 11, color: 'var(--fg-dim)', marginTop: 2,
                display: 'flex', alignItems: 'center', gap: 6,
                fontFamily: "'JetBrains Mono', monospace", letterSpacing: '0.04em',
              }}>
                <IconBluetooth size={11}/>
                <span>RKT-842 · CONNECTED</span>
              </div>
            </div>
            <Switch on={autoOn} onChange={setAutoOn}/>
          </div>

          <div style={{ marginTop: 14 }}>
            <MapPreview/>
          </div>
        </Card>
      </div>

      {/* Start trip CTA */}
      <div style={{ padding: '12px 16px 0' }}>
        <button style={{
          width: '100%', padding: '16px', borderRadius: 16,
          background: 'var(--accent)', color: 'var(--accent-ink)',
          display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 10,
          fontSize: 16, fontWeight: 600, letterSpacing: '-0.01em',
          boxShadow: '0 8px 24px oklch(0.72 0.14 235 / 0.3)',
        }}>
          <IconPlay size={20}/>
          {t.start_trip}
        </button>
      </div>

      {/* Recent trips */}
      <SectionLabel right={
        <button style={{
          fontSize: 12, color: 'var(--accent)', fontWeight: 500,
        }}>{t.see_all}</button>
      }>{t.recent_trips}</SectionLabel>

      <Card style={{
        marginLeft: 16, marginRight: 16,
        padding: 0, overflow: 'hidden',
      }}>
        {MOCK_TRIPS.slice(0, 4).map(trip => (
          <TripItem key={trip.id} trip={trip} t={t}/>
        ))}
      </Card>
    </div>
  );
}

Object.assign(window, { Dashboard });
