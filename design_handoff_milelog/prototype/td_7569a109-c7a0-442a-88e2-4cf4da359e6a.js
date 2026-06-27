// MileLog — Trip details (read-only) + Edit trip (form), split into two screens.
// TripDetails shows the locked GPS evidence + an "Edit trip" button.
// Tapping Edit opens EditTrip (classify / odometer / company / notes).

// ── Screen 1: Trip details (read-only) ───────────────────────────────
function TripDetails({ lang, onEdit, onBack, type = 'business', company = 'Metso Oyj' }) {
  const t = STRINGS[lang];
  const L = (en, fi) => (lang === 'fi' ? fi : en);
  const isBiz = type === 'business';

  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', background: 'var(--bg)' }}>
      {/* App bar */}
      <div style={{
        display: 'flex', alignItems: 'center', gap: 4,
        padding: '6px 8px', borderBottom: '1px solid var(--border)',
      }}>
        <button onClick={onBack} style={{
          width: 40, height: 40, borderRadius: 20,
          display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--fg)',
        }}><IconBack size={22}/></button>
        <div style={{ flex: 1, fontSize: 18, fontWeight: 600, color: 'var(--fg)', paddingLeft: 4 }}>
          {L('Trip details', 'Matkan tiedot')}
        </div>
      </div>

      {/* Scroll body */}
      <div style={{ flex: 1, overflowY: 'auto', padding: '16px 16px 12px' }}>
        {/* Captured banner */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 14 }}>
          <StatusChip tone="success"><IconCheck size={10}/>{L('Captured', 'Tallennettu')}</StatusChip>
          <span style={{
            fontSize: 11, fontFamily: "'JetBrains Mono', monospace",
            color: 'var(--fg-dimmer)', letterSpacing: '0.06em',
          }}>18 APR · 09:00–11:08</span>
        </div>

        {/* Route map — GPS evidence, read-only */}
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
          {L('The recorded route is locked as audit evidence and cannot be edited.',
             'Tallennettu reitti on lukittu tositteeksi eikä sitä voi muokata.')}
        </div>

        {/* Timeline */}
        <div style={{ marginTop: 16 }}>
          <TripStopList lang={lang}/>
        </div>

        {/* Stats */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 8, marginTop: 16 }}>
          {[
            { v: fmtKm(182.0, lang), u: 'km', l: L('Distance', 'Matka') },
            { v: '2:08', u: 'h', l: L('Duration', 'Kesto') },
            { v: '86', u: 'km/h', l: L('Avg speed', 'Keskinop.') },
          ].map(s => (
            <div key={s.l} style={{ background: 'var(--bg-inset)', borderRadius: 10, padding: '10px 12px' }}>
              <div style={{ display: 'flex', alignItems: 'baseline', gap: 3 }}>
                <span className="tnum" style={{ fontSize: 19, fontWeight: 600, color: 'var(--fg)' }}>{s.v}</span>
                <span style={{ fontSize: 10, color: 'var(--fg-dimmer)' }}>{s.u}</span>
              </div>
              <div style={{
                fontSize: 9, fontFamily: "'JetBrains Mono', monospace",
                color: 'var(--fg-dimmer)', letterSpacing: '0.08em', textTransform: 'uppercase', marginTop: 3,
              }}>{s.l}</div>
            </div>
          ))}
        </div>

        {/* Classification summary (read-only display of current values) */}
        <div style={{
          marginTop: 18, padding: 4,
          fontSize: 10.5, fontFamily: "'JetBrains Mono', monospace",
          color: 'var(--fg-dimmer)', letterSpacing: '0.12em', textTransform: 'uppercase',
        }}>{L('Classification', 'Luokittelu')}</div>
        <div style={{
          background: 'var(--bg-elev)', border: '1px solid var(--border)', borderRadius: 14,
          overflow: 'hidden', marginTop: 6,
        }}>
          <DetailRow icon={isBiz ? <IconBriefcase size={18}/> : <IconPersonal size={18}/>}
            label={L('Type', 'Tyyppi')} value={isBiz ? t.business : t.personal} accent/>
          <DetailRow icon={<IconOdometer size={18}/>} label={L('Odometer', 'Matkamittari')} value="42,180 → 42,362 km"/>
          <DetailRow icon={<IconMoney size={18}/>} label={L('Company', 'Yritys')} value={company} last/>
        </div>
      </div>

      {/* Sticky Edit button */}
      <div style={{
        padding: 14, borderTop: '1px solid var(--border)', background: 'var(--bg-elev)',
        display: 'flex', gap: 10,
      }}>
        <button onClick={onEdit} style={{
          flex: 1, padding: '15px', borderRadius: 14,
          background: 'var(--accent)', color: 'var(--accent-ink)',
          display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
          fontSize: 15, fontWeight: 600,
        }}>
          <IconEdit size={18} color="var(--accent-ink)"/>
          {L('Edit trip', 'Muokkaa matkaa')}
        </button>
      </div>
    </div>
  );
}

function DetailRow({ icon, label, value, accent, last }) {
  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 12, padding: '13px 16px',
      borderBottom: last ? 'none' : '1px solid var(--border)',
    }}>
      <div style={{
        width: 34, height: 34, borderRadius: 9,
        background: 'var(--accent-tint)', color: 'var(--accent)',
        display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
      }}>{icon}</div>
      <div style={{
        flex: 1, fontSize: 11, fontFamily: "'JetBrains Mono', monospace",
        color: 'var(--fg-dimmer)', letterSpacing: '0.08em', textTransform: 'uppercase',
      }}>{label}</div>
      <div style={{
        fontSize: 14, fontWeight: 600, color: accent ? 'var(--accent)' : 'var(--fg)',
      }}>{value}</div>
    </div>
  );
}

// ── Screen 2: Edit trip (form) ───────────────────────────────────────
function EditTrip({ lang, onBack, onSave, lastReading = 42180 }) {
  const t = STRINGS[lang];
  const L = (en, fi) => (lang === 'fi' ? fi : en);
  const [type, setType] = React.useState('business');
  const [odoStart, setOdoStart] = React.useState(42180);
  const [odoEnd, setOdoEnd] = React.useState(42362);
  const [company, setCompany] = React.useState('Metso Oyj');
  const [notes, setNotes] = React.useState('');

  const startTooLow = odoStart < lastReading;
  const endTooLow = odoEnd < odoStart;
  const km = Math.max(0, odoEnd - odoStart);
  const gpsKm = 182;
  const mismatch = !startTooLow && !endTooLow && Math.abs(km - gpsKm) > 5;
  const valid = !startTooLow && !endTooLow;

  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', background: 'var(--bg)' }}>
      {/* App bar */}
      <div style={{
        display: 'flex', alignItems: 'center', gap: 4,
        padding: '6px 8px', borderBottom: '1px solid var(--border)',
      }}>
        <button onClick={onBack} style={{
          width: 40, height: 40, borderRadius: 20,
          display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--fg)',
        }}><IconBack size={22}/></button>
        <div style={{ flex: 1, fontSize: 18, fontWeight: 600, color: 'var(--fg)', paddingLeft: 4 }}>
          {L('Edit trip', 'Muokkaa matkaa')}
        </div>
      </div>

      {/* Scroll body */}
      <div style={{ flex: 1, overflowY: 'auto', padding: '16px 16px 8px' }}>
        {/* Locked-route reminder */}
        <div style={{
          display: 'flex', gap: 8, alignItems: 'center',
          padding: '10px 12px', borderRadius: 10, marginBottom: 18,
          background: 'var(--bg-inset)', border: '1px solid var(--border)',
        }}>
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" style={{ flexShrink: 0 }}><path d="M6 11V8a6 6 0 0112 0v3M5 11h14v9H5z" stroke="var(--fg-dim)" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/></svg>
          <span style={{ fontSize: 11.5, color: 'var(--fg-dim)', lineHeight: 1.4 }}>
            {L('The GPS route is locked. You can edit the classification below.',
               'GPS-reitti on lukittu. Voit muokata luokittelua alla.')}
          </span>
        </div>

        {/* Classify */}
        <div style={{
          fontSize: 10.5, fontFamily: "'JetBrains Mono', monospace",
          color: 'var(--fg-dimmer)', letterSpacing: '0.12em', textTransform: 'uppercase', marginBottom: 10,
        }}>{L('Classify this trip', 'Luokittele matka')}</div>
        <div style={{
          display: 'flex', background: 'var(--bg-inset)',
          border: '1px solid var(--border)', borderRadius: 12, padding: 4, gap: 2, marginBottom: 18,
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
            }}><I size={16}/>{l}</button>
          ))}
        </div>

        {/* Odometer */}
        <div style={{
          fontSize: 10.5, fontFamily: "'JetBrains Mono', monospace",
          color: 'var(--fg-dimmer)', letterSpacing: '0.12em', textTransform: 'uppercase', marginBottom: 8,
          display: 'flex', justifyContent: 'space-between',
        }}>
          <span>{L('Odometer', 'Matkamittari')}</span>
          <span style={{ color: 'var(--fg-dim)' }}>{L('Last', 'Viim.')}: {fmtInt(lastReading)} km</span>
        </div>
        <div style={{
          display: 'grid', gridTemplateColumns: '1fr auto 1fr', gap: 10,
          marginBottom: startTooLow || endTooLow ? 8 : 16,
        }}>
          <OdoField label={L('Start', 'Alku')} value={odoStart} onChange={setOdoStart} error={startTooLow}/>
          <div style={{ display: 'flex', alignItems: 'center', color: 'var(--fg-dimmer)', paddingTop: 16 }}>→</div>
          <OdoField label={L('End', 'Loppu')} value={odoEnd} onChange={setOdoEnd} error={endTooLow}/>
        </div>

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

        {/* Distance */}
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
          }}>{L('DISTANCE', 'MATKA')}</div>
          <div className="tnum" style={{
            fontSize: 26, fontWeight: 600, color: valid ? 'var(--accent)' : 'var(--fg-dim)',
          }}>{fmtKm(km, lang)} <span style={{ fontSize: 13, opacity: 0.7 }}>km</span></div>
        </div>

        {mismatch && (
          <ValidationMsg tone="warning">
            {L(`Entered distance (${fmtKm(km, lang)} km) differs from the GPS-measured ${gpsKm} km. Double-check the readings.`,
               `Syötetty matka (${fmtKm(km, lang)} km) poikkeaa GPS:n mittaamasta ${gpsKm} km:stä. Tarkista lukemat.`)}
          </ValidationMsg>
        )}

        <LabeledInput label={L('Company', 'Yritys')} value={company} onChange={setCompany}/>
        <LabeledInput label={L('Notes', 'Muistiinpanot')} value={notes} onChange={setNotes} multiline/>
      </div>

      {/* Sticky actions */}
      <div style={{
        padding: 14, borderTop: '1px solid var(--border)', background: 'var(--bg-elev)',
        display: 'flex', gap: 10,
      }}>
        <button onClick={onBack} style={{
          flex: 1, padding: '15px', borderRadius: 14,
          background: 'var(--bg-inset)', color: 'var(--fg)',
          border: '1px solid var(--border)', fontSize: 14, fontWeight: 500,
        }}>{t.cancel}</button>
        <button onClick={valid ? onSave : undefined} disabled={!valid} style={{
          flex: 2, padding: '15px', borderRadius: 14,
          background: valid ? 'var(--accent)' : 'var(--bg-inset)',
          color: valid ? 'var(--accent-ink)' : 'var(--fg-dimmer)',
          border: valid ? 'none' : '1px solid var(--border)',
          fontSize: 14, fontWeight: 600, cursor: valid ? 'pointer' : 'not-allowed',
        }}>{t.save}</button>
      </div>
    </div>
  );
}

Object.assign(window, { TripDetails, EditTrip, DetailRow });
