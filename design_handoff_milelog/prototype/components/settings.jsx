// MileLog — Settings screen
// Sections: Permissions callout, Auto-tracking, Cloud, Management, Preferences, About
// Plus: Rate editor sheet, Theme sheet, Vehicle list sheet, Workplace list sheet

function Settings({ lang, theme, onTheme, onLang, onNavigate }) {
  const t = STRINGS[lang];
  const [btOn, setBtOn] = React.useState(true);
  const [geoOn, setGeoOn] = React.useState(true);
  const [gpsOn, setGpsOn] = React.useState(true);
  const [rate, setRate] = React.useState(0.55);
  const [sheet, setSheet] = React.useState(null); // 'rate' | 'theme' | 'vehicles' | 'workplaces' | 'language'

  // Permission state — one needs review
  const permLoc = 'granted';
  const permBt = 'review';

  return (
    <div style={{ paddingBottom: 28, position: 'relative' }}>
      {/* Large title */}
      <div style={{
        padding: '6px 20px 16px',
      }}>
        <div style={{
          fontSize: 11, fontFamily: "'JetBrains Mono', monospace",
          color: 'var(--fg-dimmer)', letterSpacing: '0.14em',
        }}>MILELOG / v2.4.1</div>
        <div style={{
          fontSize: 32, fontWeight: 600, letterSpacing: '-0.025em',
          color: 'var(--fg)', marginTop: 6, lineHeight: 1,
        }}>{t.settings}</div>
      </div>

      {/* Permissions alert (only shown if any need review) */}
      {permBt === 'review' && (
        <div style={{ padding: '0 16px 4px' }}>
          <Card style={{
            padding: 14,
            border: '1px solid var(--warning)',
            background: 'oklch(0.78 0.14 75 / 0.08)',
            display: 'flex', gap: 12, alignItems: 'flex-start',
          }}>
            <div style={{
              width: 32, height: 32, borderRadius: 8,
              background: 'oklch(0.78 0.14 75 / 0.2)',
              color: 'var(--warning)',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              flexShrink: 0,
            }}>
              <IconBluetooth size={18}/>
            </div>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 13.5, fontWeight: 500, color: 'var(--fg)' }}>{t.bt_perm}</div>
              <div style={{ fontSize: 12, color: 'var(--fg-dim)', marginTop: 2, lineHeight: 1.4 }}>
                {t.bt_perm_desc}
              </div>
            </div>
            <button style={{
              padding: '6px 12px', borderRadius: 8,
              background: 'var(--warning)', color: '#1a1a1a',
              fontSize: 12, fontWeight: 600, flexShrink: 0,
            }}>{t.needs_review}</button>
          </Card>
        </div>
      )}

      {/* AUTO-TRACKING */}
      <SectionLabel>{t.auto_tracking}</SectionLabel>
      <Card style={{ margin: '0 16px', overflow: 'hidden' }}>
        <SettingRow
          icon={<IconBluetooth size={20}/>}
          iconBg="oklch(0.72 0.14 235 / 0.15)"
          title={t.bluetooth_autostart}
          subtitle={t.bluetooth_desc}
          right={<Switch on={btOn} onChange={setBtOn}/>}
        />
        <SettingRow
          icon={<IconLocation size={20}/>}
          iconBg="oklch(0.72 0.14 235 / 0.15)"
          title={t.geofencing}
          subtitle={t.geofencing_desc}
          right={<Switch on={geoOn} onChange={setGeoOn}/>}
        />
        <SettingRow
          icon={<IconSignal size={20}/>}
          iconBg="oklch(0.72 0.14 235 / 0.15)"
          title={t.gps_tracking}
          subtitle={t.gps_desc}
          right={<Switch on={gpsOn} onChange={setGpsOn}/>}
          divider={false}
        />
      </Card>

      {/* CLOUD */}
      <SectionLabel>{t.cloud}</SectionLabel>
      <Card style={{ margin: '0 16px', overflow: 'hidden' }}>
        <div style={{
          padding: '14px 18px',
          borderBottom: '1px solid var(--border)',
          display: 'flex', alignItems: 'center', gap: 12,
        }}>
          <div style={{
            width: 38, height: 38, borderRadius: 10,
            background: 'oklch(0.74 0.14 160 / 0.15)',
            color: 'var(--success)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            flexShrink: 0,
          }}>
            <IconCloud size={20}/>
          </div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{
              fontSize: 14, fontWeight: 500,
              whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
            }}>
              mikko.virtanen@acme.fi
            </div>
            <div style={{
              fontSize: 11, fontFamily: "'JetBrains Mono', monospace",
              color: 'var(--fg-dim)', marginTop: 3, letterSpacing: '0.04em',
              display: 'flex', alignItems: 'center', gap: 8,
            }}>
              <span>{t.last_sync.toUpperCase()} · 11:42</span>
              <StatusChip tone="success">
                <IconCheck size={10}/>
                {t.synced}
              </StatusChip>
            </div>
          </div>
        </div>
        <div style={{
          display: 'flex', padding: 12, gap: 10,
        }}>
          <button style={{
            flex: 1, padding: '12px',
            background: 'var(--accent-tint)', color: 'var(--accent)',
            borderRadius: 10, fontSize: 13.5, fontWeight: 600,
            display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
          }}>
            <IconCloud size={16}/>
            {t.sync_now}
          </button>
          <button style={{
            flex: 1, padding: '12px',
            background: 'var(--bg-inset)', color: 'var(--fg)',
            border: '1px solid var(--border)',
            borderRadius: 10, fontSize: 13.5, fontWeight: 500,
            display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
          }}>
            <IconDownload size={16}/>
            {t.restore_backup}
          </button>
        </div>
      </Card>

      {/* MANAGEMENT */}
      <SectionLabel>{t.management}</SectionLabel>
      <Card style={{ margin: '0 16px', overflow: 'hidden' }}>
        <SettingRow
          icon={<IconVehicle size={20}/>}
          iconBg="oklch(0.72 0.14 235 / 0.15)"
          title={t.vehicles}
          subtitle={`${MOCK_VEHICLES.length} · Volvo XC60 (${t.primary.toLowerCase()})`}
          right={<IconChevron size={18} color="var(--fg-dimmer)"/>}
          onClick={() => setSheet('vehicles')}
        />
        <SettingRow
          icon={<IconLocation size={20}/>}
          iconBg="oklch(0.72 0.14 235 / 0.15)"
          title={t.workplaces}
          subtitle={`${MOCK_WORKPLACES.length} ${lang === 'fi' ? 'paikkaa' : 'locations'}`}
          right={<IconChevron size={18} color="var(--fg-dimmer)"/>}
          onClick={() => setSheet('workplaces')}
        />
        <SettingRow
          icon={<IconOdometer size={20}/>}
          iconBg="oklch(0.72 0.14 235 / 0.15)"
          title={t.odometer_log}
          subtitle={
            <span className="mono">
              42 180 km · {lang === 'fi' ? 'eilen' : 'yesterday'}
            </span>
          }
          right={<IconChevron size={18} color="var(--fg-dimmer)"/>}
          divider={false}
        />
      </Card>

      {/* PREFERENCES */}
      <SectionLabel>{t.preferences}</SectionLabel>
      <Card style={{ margin: '0 16px', overflow: 'hidden' }}>
        <SettingRow
          icon={<IconMoney size={20}/>}
          iconBg="oklch(0.72 0.14 235 / 0.15)"
          title={t.mileage_rate}
          subtitle={t.rate_hint}
          right={
            <div style={{
              fontSize: 14, fontWeight: 600, color: 'var(--accent)',
              fontVariantNumeric: 'tabular-nums',
            }}>
              {fmtEur(rate, lang)}
            </div>
          }
          onClick={() => setSheet('rate')}
        />
        <SettingRow
          icon={<IconTheme size={20}/>}
          iconBg="oklch(0.72 0.14 235 / 0.15)"
          title={t.theme}
          subtitle={lang === 'fi' ? 'Tumma tila' : 'Dark mode'}
          right={
            <div style={{
              display: 'flex', alignItems: 'center', gap: 6,
              fontSize: 13, color: 'var(--fg-dim)', fontWeight: 500,
            }}>
              {theme === 'dark' ? t.theme_dark : t.theme_light}
              <IconChevron size={16} color="var(--fg-dimmer)"/>
            </div>
          }
          onClick={() => setSheet('theme')}
        />
        <SettingRow
          icon={<div style={{
            fontSize: 14, fontWeight: 600, fontFamily: "'JetBrains Mono', monospace",
          }}>{lang === 'fi' ? 'FI' : 'EN'}</div>}
          iconBg="oklch(0.72 0.14 235 / 0.15)"
          title={t.language}
          subtitle={lang === 'fi' ? 'Suomi' : 'English'}
          right={<IconChevron size={18} color="var(--fg-dimmer)"/>}
          onClick={() => setSheet('language')}
          divider={false}
        />
      </Card>

      {/* PERMISSIONS STATUS */}
      <SectionLabel>{t.permissions}</SectionLabel>
      <Card style={{ margin: '0 16px', overflow: 'hidden' }}>
        <SettingRow
          icon={<IconLocation size={20}/>}
          iconBg="oklch(0.74 0.14 160 / 0.15)"
          title={t.loc_bg}
          subtitle={t.loc_bg_desc}
          right={<StatusChip tone="success">{t.granted}</StatusChip>}
        />
        <SettingRow
          icon={<IconBluetooth size={20}/>}
          iconBg="oklch(0.78 0.14 75 / 0.15)"
          title={t.bt_perm}
          subtitle={t.bt_perm_desc}
          right={<StatusChip tone="warning">{t.needs_review}</StatusChip>}
          divider={false}
        />
      </Card>

      {/* PROFILE / SIGN OUT */}
      <SectionLabel>{t.about}</SectionLabel>
      <Card style={{ margin: '0 16px', overflow: 'hidden' }}>
        <SettingRow
          icon={<IconProfile size={20}/>}
          iconBg="var(--bg-inset)"
          title="Mikko Virtanen"
          subtitle="mikko.virtanen@acme.fi"
          right={<IconChevron size={18} color="var(--fg-dimmer)"/>}
        />
        <SettingRow
          title={t.sign_out}
          danger
          divider={false}
          onClick={() => {}}
          icon={
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
              <path d="M15 3h4a2 2 0 012 2v14a2 2 0 01-2 2h-4M10 17l5-5-5-5M15 12H4" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/>
            </svg>
          }
          iconBg="oklch(0.68 0.19 25 / 0.12)"
        />
      </Card>

      {/* Build stamp — small monospace footer */}
      <div style={{
        marginTop: 28, textAlign: 'center',
        fontSize: 10, fontFamily: "'JetBrains Mono', monospace",
        color: 'var(--fg-ghost)', letterSpacing: '0.14em',
      }}>
        MILELOG · 2.4.1 · BUILD 20260418
      </div>

      {/* SHEETS */}
      <Sheet open={sheet === 'rate'} onClose={() => setSheet(null)} title={t.rate_title}>
        <RateEditor
          value={rate}
          onSave={(v) => { setRate(v); setSheet(null); }}
          onCancel={() => setSheet(null)}
          t={t}
          lang={lang}
        />
      </Sheet>

      <Sheet open={sheet === 'theme'} onClose={() => setSheet(null)} title={t.theme}>
        <RadioRow label={t.theme_light} selected={theme === 'light'} onClick={() => { onTheme('light'); setSheet(null); }}/>
        <div style={{ height: 1, background: 'var(--border)' }}/>
        <RadioRow label={t.theme_dark} selected={theme === 'dark'} onClick={() => { onTheme('dark'); setSheet(null); }}/>
        <div style={{ height: 1, background: 'var(--border)' }}/>
        <RadioRow label={t.theme_system} selected={false} onClick={() => {}}/>
      </Sheet>

      <Sheet open={sheet === 'language'} onClose={() => setSheet(null)} title={t.language}>
        <RadioRow label="English" selected={lang === 'en'} onClick={() => { onLang('en'); setSheet(null); }}
                  right={<span className="mono" style={{ fontSize: 11, color: 'var(--fg-dimmer)' }}>EN</span>}/>
        <div style={{ height: 1, background: 'var(--border)' }}/>
        <RadioRow label="Suomi" selected={lang === 'fi'} onClick={() => { onLang('fi'); setSheet(null); }}
                  right={<span className="mono" style={{ fontSize: 11, color: 'var(--fg-dimmer)' }}>FI</span>}/>
      </Sheet>

      <Sheet open={sheet === 'vehicles'} onClose={() => setSheet(null)} title={t.vehicles}>
        <VehicleList t={t} lang={lang}/>
      </Sheet>

      <Sheet open={sheet === 'workplaces'} onClose={() => setSheet(null)} title={t.workplaces}>
        <WorkplaceList t={t} lang={lang}/>
      </Sheet>
    </div>
  );
}

// Rate editor with keypad-style input
function RateEditor({ value, onSave, onCancel, t, lang }) {
  const [v, setV] = React.useState(value.toFixed(2));
  const display = lang === 'fi' ? v.replace('.', ',') : v;
  return (
    <div>
      <div style={{
        padding: '22px 16px 20px',
        background: 'var(--bg-inset)',
        borderRadius: 14,
        marginBottom: 16,
        textAlign: 'center',
        border: '1px solid var(--border)',
      }}>
        <div style={{
          fontSize: 52, fontWeight: 600, color: 'var(--accent)',
          fontVariantNumeric: 'tabular-nums', letterSpacing: '-0.02em',
          display: 'flex', alignItems: 'baseline', justifyContent: 'center', gap: 6,
        }}>
          <span>€</span>
          <span>{display}</span>
        </div>
        <div style={{
          fontSize: 11, fontFamily: "'JetBrains Mono', monospace",
          color: 'var(--fg-dim)', marginTop: 4, letterSpacing: '0.1em',
        }}>{t.per_km.toUpperCase()}</div>
      </div>

      {/* Quick presets */}
      <div style={{ display: 'flex', gap: 8, marginBottom: 18, flexWrap: 'wrap' }}>
        {['0.45', '0.50', '0.55', '0.60'].map(p => (
          <button key={p} onClick={() => setV(p)} style={{
            padding: '10px 14px', borderRadius: 10,
            background: v === p ? 'var(--accent-tint)' : 'var(--bg-inset)',
            color: v === p ? 'var(--accent)' : 'var(--fg-dim)',
            border: `1px solid ${v === p ? 'var(--accent)' : 'var(--border)'}`,
            fontSize: 13, fontWeight: 600,
            fontVariantNumeric: 'tabular-nums',
          }}>
            {lang === 'fi' ? p.replace('.', ',') : '€' + p}
          </button>
        ))}
      </div>

      <div style={{
        fontSize: 12, color: 'var(--fg-dim)', padding: '0 2px 18px',
        lineHeight: 1.5,
      }}>
        {t.rate_hint}
      </div>

      <div style={{ display: 'flex', gap: 10 }}>
        <button onClick={onCancel} style={{
          flex: 1, padding: '14px',
          background: 'var(--bg-inset)', color: 'var(--fg)',
          border: '1px solid var(--border)',
          borderRadius: 12, fontSize: 14, fontWeight: 500,
        }}>{t.cancel}</button>
        <button onClick={() => onSave(parseFloat(v))} style={{
          flex: 1, padding: '14px',
          background: 'var(--accent)', color: 'var(--accent-ink)',
          borderRadius: 12, fontSize: 14, fontWeight: 600,
        }}>{t.save}</button>
      </div>
    </div>
  );
}

function VehicleList({ t, lang }) {
  return (
    <div>
      {MOCK_VEHICLES.map((v, i) => (
        <div key={v.id} style={{
          display: 'flex', alignItems: 'center', gap: 14,
          padding: '16px 0',
          borderBottom: i < MOCK_VEHICLES.length - 1 ? '1px solid var(--border)' : 'none',
        }}>
          <div style={{
            width: 44, height: 44, borderRadius: 10,
            background: 'var(--accent-tint)',
            color: 'var(--accent)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <IconVehicle size={24}/>
          </div>
          <div style={{ flex: 1 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
              <div style={{ fontSize: 15, fontWeight: 600 }}>{v.name}</div>
              {v.primary && (
                <span style={{
                  fontSize: 9, padding: '2px 6px',
                  background: 'var(--accent-tint)', color: 'var(--accent)',
                  borderRadius: 4, fontFamily: "'JetBrains Mono', monospace",
                  letterSpacing: '0.08em', fontWeight: 600,
                }}>{t.primary.toUpperCase()}</span>
              )}
            </div>
            <div style={{
              fontSize: 11, color: 'var(--fg-dim)', marginTop: 3,
              fontFamily: "'JetBrains Mono', monospace", letterSpacing: '0.04em',
            }}>
              {v.plate} · {v.year} · {fmtInt(v.odo)} km
            </div>
          </div>
          {v.bt && <IconBluetooth size={16} color="var(--accent)"/>}
        </div>
      ))}
      <button style={{
        width: '100%', padding: '14px', marginTop: 10,
        background: 'transparent', color: 'var(--accent)',
        border: '1.5px dashed var(--border-strong)',
        borderRadius: 12, fontSize: 14, fontWeight: 600,
        display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
      }}>
        <IconPlus size={18}/>
        {t.add_vehicle}
      </button>
    </div>
  );
}

function WorkplaceList({ t, lang }) {
  return (
    <div>
      {MOCK_WORKPLACES.map((w, i) => (
        <div key={w.id} style={{
          display: 'flex', alignItems: 'center', gap: 14,
          padding: '14px 0',
          borderBottom: i < MOCK_WORKPLACES.length - 1 ? '1px solid var(--border)' : 'none',
        }}>
          <div style={{
            width: 44, height: 44, borderRadius: 10,
            background: 'var(--accent-tint)',
            color: 'var(--accent)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <IconLocation size={22}/>
          </div>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 15, fontWeight: 600 }}>{w.name}</div>
            <div style={{
              fontSize: 12, color: 'var(--fg-dim)', marginTop: 2,
            }}>{w.addr}</div>
          </div>
          <div style={{
            fontSize: 11, fontFamily: "'JetBrains Mono', monospace",
            color: 'var(--fg-dimmer)', letterSpacing: '0.04em',
          }}>{w.radius}m</div>
        </div>
      ))}
    </div>
  );
}

Object.assign(window, { Settings });
