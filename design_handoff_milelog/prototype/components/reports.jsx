// MileLog — Reports v2: monthly/all-time toggle, hero stats, calendar heatmap, donut by client, export

function Reports({ lang }) {
  const t = STRINGS[lang];
  const [range, setRange] = React.useState('month'); // 'month' | 'all'

  const month = { km: 1247.3, biz: 1018.5, pers: 228.8, trips: 34, hrs: 28.4 };
  const all = { km: 18734.6, biz: 14920.2, pers: 3814.4, trips: 512, hrs: 421.8 };
  const d = range === 'month' ? month : all;
  const rate = 0.55;
  const reim = d.biz * rate;

  // Heatmap — 6 weeks x 7 days (42 cells)
  const heat = React.useMemo(() => Array.from({ length: 42 }, (_, i) => {
    const seed = (i * 37 + 13) % 100;
    if (seed < 20) return 0;
    if (seed < 40) return 0.25;
    if (seed < 70) return 0.5;
    if (seed < 90) return 0.75;
    return 1;
  }), [range]);

  // Donut data — clients
  const clients = [
    { name: 'Nokia Oyj', km: 512, color: 'var(--accent)' },
    { name: 'Metso Oyj', km: 284, color: 'var(--accent-2, var(--accent))' },
    { name: 'Acme Oy',   km: 142, color: 'var(--personal)' },
    { name: lang === 'fi' ? 'Muut' : 'Other', km: 80.5, color: 'var(--fg-ghost)' },
  ];

  return (
    <div style={{ paddingBottom: 24 }}>
      {/* Header */}
      <div style={{ padding: '8px 20px 10px', display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between' }}>
        <div>
          <div style={{
            fontSize: 11, fontFamily: "'JetBrains Mono', monospace",
            color: 'var(--fg-dimmer)', letterSpacing: '0.14em',
          }}>{range === 'month' ? 'APR 2026' : 'SINCE MAR 2024'}</div>
          <div style={{
            fontSize: 28, fontWeight: 600, letterSpacing: '-0.02em',
            color: 'var(--fg)', marginTop: 4,
          }}>{t.tab_reports}</div>
        </div>
        <button style={{
          width: 40, height: 40, borderRadius: 20,
          background: 'var(--bg-elev)', border: '1px solid var(--border)',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          color: 'var(--fg)',
        }}>
          <IconSearch size={18}/>
        </button>
      </div>

      {/* Range toggle */}
      <div style={{ padding: '0 16px 14px' }}>
        <div style={{
          display: 'flex', background: 'var(--bg-elev)',
          border: '1px solid var(--border)', borderRadius: 12, padding: 4, gap: 2,
        }}>
          {[
            { k: 'month', l: lang === 'fi' ? 'Tämä kuu' : 'This month' },
            { k: 'all',   l: lang === 'fi' ? 'Kaikki ajat' : 'All time' },
          ].map(f => (
            <button key={f.k} onClick={() => setRange(f.k)} style={{
              flex: 1, padding: '10px', borderRadius: 9,
              background: range === f.k ? 'var(--accent-tint)' : 'transparent',
              color: range === f.k ? 'var(--accent)' : 'var(--fg-dim)',
              fontSize: 13, fontWeight: 600,
            }}>{f.l}</button>
          ))}
        </div>
      </div>

      {/* Hero year-in-review card */}
      <div style={{ padding: '0 16px 12px' }}>
        <Card style={{ padding: 20, position: 'relative', overflow: 'hidden' }}>
          <div style={{
            fontSize: 10.5, fontFamily: "'JetBrains Mono', monospace",
            color: 'var(--fg-dimmer)', letterSpacing: '0.14em', marginBottom: 10,
          }}>{lang === 'fi' ? 'YHTEENSÄ AJETTU' : 'TOTAL DRIVEN'}</div>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 6 }}>
            <div className="tnum" style={{
              fontSize: 56, fontWeight: 600, color: 'var(--fg)',
              letterSpacing: '-0.03em', lineHeight: 1,
            }}>{fmtKm(d.km, lang)}</div>
            <div style={{ fontSize: 16, color: 'var(--fg-dim)' }}>km</div>
          </div>
          {/* stat row */}
          <div style={{
            display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 10,
            marginTop: 18, paddingTop: 16,
            borderTop: '1px dashed var(--border-strong)',
          }}>
            <Stat label={t.business} value={fmtKm(d.biz, lang)} unit="km" accent/>
            <Stat label={t.personal} value={fmtKm(d.pers, lang)} unit="km"/>
            <Stat label={lang === 'fi' ? 'Matkoja' : 'Trips'} value={fmtInt(d.trips)} unit=""/>
          </div>
          {/* reimbursable */}
          <div style={{
            marginTop: 14, padding: '12px 14px', borderRadius: 12,
            background: 'var(--accent-tint)',
            display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          }}>
            <div>
              <div style={{ fontSize: 10.5, color: 'var(--accent)', fontFamily: "'JetBrains Mono', monospace", letterSpacing: '0.12em' }}>
                {lang === 'fi' ? 'KORVATTAVA' : 'REIMBURSABLE'}
              </div>
              <div className="tnum" style={{ fontSize: 22, fontWeight: 600, color: 'var(--accent)', marginTop: 2 }}>
                {fmtEur(reim, lang)}
              </div>
            </div>
            <div style={{ textAlign: 'right', fontSize: 10.5, color: 'var(--accent)', fontFamily: "'JetBrains Mono', monospace", letterSpacing: '0.1em' }}>
              @ {lang === 'fi' ? '0,55' : '0.55'}<br/>
              €/KM
            </div>
          </div>
        </Card>
      </div>

      {/* Heatmap (monthly only) */}
      {range === 'month' && (
        <>
          <SectionLabel>{lang === 'fi' ? 'Päiväkartta' : 'Daily activity'}</SectionLabel>
          <div style={{ padding: '0 16px 8px' }}>
            <Card style={{ padding: 18 }}>
              <div style={{
                display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', gap: 4,
                marginBottom: 12,
              }}>
                {['M','T','W','T','F','S','S'].map((d, i) => (
                  <div key={i} style={{
                    fontSize: 9.5, fontFamily: "'JetBrains Mono', monospace",
                    color: 'var(--fg-dimmer)', textAlign: 'center', letterSpacing: '0.1em',
                  }}>{d}</div>
                ))}
                {heat.map((v, i) => (
                  <div key={i} style={{
                    aspectRatio: '1', borderRadius: 4,
                    background: v === 0 ? 'var(--bg-inset)' : `oklch(from var(--accent) l c h / ${0.2 + v * 0.8})`,
                    border: v === 0 ? '1px solid var(--border)' : 'none',
                  }}/>
                ))}
              </div>
              <div style={{
                display: 'flex', alignItems: 'center', gap: 6,
                fontSize: 10, fontFamily: "'JetBrains Mono', monospace",
                color: 'var(--fg-dimmer)', letterSpacing: '0.08em',
              }}>
                <span>LESS</span>
                {[0.2, 0.4, 0.6, 0.8, 1].map((o, i) => (
                  <div key={i} style={{
                    width: 10, height: 10, borderRadius: 2,
                    background: `oklch(from var(--accent) l c h / ${o})`,
                  }}/>
                ))}
                <span>MORE</span>
              </div>
            </Card>
          </div>
        </>
      )}

      {/* Donut breakdown by client */}
      <SectionLabel>{lang === 'fi' ? 'Asiakkaittain' : 'By client'}</SectionLabel>
      <div style={{ padding: '0 16px 8px' }}>
        <Card style={{ padding: 18, display: 'flex', gap: 16, alignItems: 'center' }}>
          <Donut data={clients}/>
          <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 8 }}>
            {clients.map(c => {
              const total = clients.reduce((s, x) => s + x.km, 0);
              const pct = Math.round((c.km / total) * 100);
              return (
                <div key={c.name} style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                  <div style={{ width: 9, height: 9, borderRadius: 2, background: c.color }}/>
                  <div style={{ flex: 1, fontSize: 12.5, color: 'var(--fg)', fontWeight: 500 }}>{c.name}</div>
                  <div className="tnum" style={{ fontSize: 11, color: 'var(--fg-dim)', fontFamily: "'JetBrains Mono', monospace" }}>{pct}%</div>
                </div>
              );
            })}
          </div>
        </Card>
      </div>

      {/* Export */}
      <SectionLabel>{lang === 'fi' ? 'Vienti' : 'Export'}</SectionLabel>
      <div style={{ padding: '0 16px', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
        <ExportBtn icon={<IconDoc size={18}/>} label="PDF" sub={lang === 'fi' ? 'Verottaja-valmis' : 'Tax-ready'}/>
        <ExportBtn icon={<IconDownload size={18}/>} label="CSV" sub={lang === 'fi' ? 'Taulukkolaskenta' : 'Spreadsheet'}/>
      </div>
    </div>
  );
}

function Stat({ label, value, unit, accent }) {
  return (
    <div>
      <div style={{
        fontSize: 9.5, fontFamily: "'JetBrains Mono', monospace",
        color: 'var(--fg-dimmer)', letterSpacing: '0.12em',
        textTransform: 'uppercase',
      }}>{label}</div>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 3, marginTop: 4 }}>
        <span className="tnum" style={{
          fontSize: 18, fontWeight: 600,
          color: accent ? 'var(--accent)' : 'var(--fg)',
        }}>{value}</span>
        <span style={{ fontSize: 10, color: 'var(--fg-dimmer)' }}>{unit}</span>
      </div>
    </div>
  );
}

function Donut({ data }) {
  const total = data.reduce((s, d) => s + d.km, 0);
  const R = 42, C = 2 * Math.PI * R;
  let offset = 0;
  return (
    <svg width="110" height="110" viewBox="0 0 110 110">
      <circle cx="55" cy="55" r={R} fill="none" stroke="var(--bg-inset)" strokeWidth="14"/>
      {data.map((d, i) => {
        const len = (d.km / total) * C;
        const seg = (
          <circle key={i}
            cx="55" cy="55" r={R}
            fill="none" stroke={d.color}
            strokeWidth="14"
            strokeDasharray={`${len} ${C}`}
            strokeDashoffset={-offset}
            transform="rotate(-90 55 55)"
          />
        );
        offset += len;
        return seg;
      })}
      <text x="55" y="52" textAnchor="middle" style={{
        fontSize: 11, fill: 'var(--fg-dimmer)', fontFamily: "'JetBrains Mono', monospace", letterSpacing: '0.08em',
      }}>TOTAL</text>
      <text x="55" y="68" textAnchor="middle" style={{
        fontSize: 16, fill: 'var(--fg)', fontWeight: 600, fontVariantNumeric: 'tabular-nums',
      }}>{Math.round(total)}</text>
    </svg>
  );
}

function ExportBtn({ icon, label, sub }) {
  return (
    <button style={{
      padding: '14px', borderRadius: 12,
      background: 'var(--bg-elev)', border: '1px solid var(--border)',
      display: 'flex', flexDirection: 'column', alignItems: 'flex-start', gap: 6,
      color: 'var(--fg)', cursor: 'pointer',
    }}>
      <div style={{
        width: 32, height: 32, borderRadius: 8,
        background: 'var(--accent-tint)', color: 'var(--accent)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
      }}>{icon}</div>
      <div style={{ fontSize: 14, fontWeight: 600 }}>{label}</div>
      <div style={{ fontSize: 10.5, color: 'var(--fg-dim)', fontFamily: "'JetBrains Mono', monospace", letterSpacing: '0.04em' }}>{sub}</div>
    </button>
  );
}

Object.assign(window, { Reports });
