import { LogoGlyph, LogoTile, type LogoVariant } from '../components/Logo';

/* 00b · Brand board — the Familiar logo, how it is built, and two alternate concepts. */
const alternates: { variant: LogoVariant; name: string; idea: string }[] = [
  { variant: 'hello', name: 'Hello', idea: 'A soft speech bubble with a smile: friendly, but closer to a chat app.' },
  { variant: 'ripple', name: 'Ripple', idea: 'The wrist tap: a dot with two rings spreading out. Clear, but close to a Wi-Fi icon.' },
];

export function BrandScreen() {
  return (
    <div
      style={{
        width: 1440, height: 680, padding: '56px 64px', display: 'grid', gridTemplateColumns: '1.25fr 1fr', gap: 48,
        background: 'var(--bg-grad)', color: 'var(--ink)', fontFamily: 'var(--font)', borderRadius: 6,
      }}
    >
      {/* Primary */}
      <section style={{ display: 'flex', flexDirection: 'column' }}>
        <p className="eyebrow" style={{ padding: 0, fontSize: 14 }}>Primary mark · “The Overlap”</p>
        <div style={{ marginTop: 28, display: 'flex', alignItems: 'center', gap: 32 }}>
          <LogoTile size={168} />
          <div>
            <span className="wordmark" style={{ fontSize: 54 }}>Familiar</span>
            <p className="t-lead" style={{ marginTop: 20, fontSize: 20, lineHeight: '30px', maxWidth: 420 }}>
              Two people, drawn as two rings. The lens where they overlap is filled in: the moment you recognise someone, the part you both remember.
            </p>
          </div>
        </div>

        <div style={{ marginTop: 'auto', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 24 }}>
          <div className="card" style={{ padding: 24, display: 'flex', alignItems: 'center', gap: 24 }}>
            <svg width="128" height="128" viewBox="0 0 24 24" fill="none" aria-hidden="true" style={{ flexShrink: 0 }}>
              <circle cx="8.8" cy="12" r="6.2" stroke="var(--muted)" strokeWidth=".35" strokeDasharray=".7 .5" />
              <circle cx="15.2" cy="12" r="6.2" stroke="var(--muted)" strokeWidth=".35" strokeDasharray=".7 .5" />
              <line x1="12" y1="3" x2="12" y2="21" stroke="var(--outline)" strokeWidth=".2" />
              <circle cx="8.8" cy="12" r=".35" fill="var(--blue)" />
              <circle cx="15.2" cy="12" r=".35" fill="var(--blue)" />
              <path d="M12 6.69A6.2 6.2 0 0 1 12 17.31A6.2 6.2 0 0 1 12 6.69Z" fill="var(--accent)" opacity=".9" />
            </svg>
            <div>
              <p className="t-row">Construction</p>
              <p className="t-sub" style={{ marginTop: 6 }}>Two equal circles, offset by just over half a radius. Only the shared lens is filled, so it holds up at 16 px.</p>
            </div>
          </div>
          <div className="card" style={{ padding: 24 }}>
            <p className="t-row">Sizes</p>
            <div style={{ marginTop: 16, display: 'flex', alignItems: 'flex-end', gap: 18 }}>
              {[72, 52, 36, 24, 18].map((s) => <LogoTile key={s} size={s} />)}
              <span style={{ color: 'var(--ink)', marginLeft: 6 }}><LogoGlyph size={36} /></span>
            </div>
            <p className="t-sub" style={{ marginTop: 14 }}>App icon, notification, Dynamic Island, favicon. The glyph alone works in one colour.</p>
          </div>
        </div>
      </section>

      {/* Alternates */}
      <section style={{ display: 'flex', flexDirection: 'column' }}>
        <p className="eyebrow" style={{ padding: 0, fontSize: 14 }}>Alternate concepts</p>
        <div style={{ marginTop: 28, display: 'flex', flexDirection: 'column', gap: 20 }}>
          {alternates.map((a) => (
            <div key={a.variant} className="card" style={{ padding: 24, display: 'flex', alignItems: 'center', gap: 24 }}>
              <LogoTile size={96} variant={a.variant} />
              <div>
                <p className="t-row" style={{ fontSize: 20 }}>{a.name}</p>
                <p className="t-sub" style={{ marginTop: 6, fontSize: 16, lineHeight: '23px' }}>{a.idea}</p>
              </div>
            </div>
          ))}
          <div className="card" style={{ padding: 24, display: 'flex', alignItems: 'center', gap: 20, background: 'var(--navy-grad)', color: '#fff' }}>
            <LogoTile size={64} />
            <div>
              <span className="wordmark" style={{ fontSize: 22, color: '#fff' }}>Familiar</span>
              <p style={{ marginTop: 10, fontSize: 15, lineHeight: '21px', color: 'var(--sky-text)' }}>Lockup on the graphite Live Activity card.</p>
            </div>
          </div>
        </div>
      </section>
    </div>
  );
}
