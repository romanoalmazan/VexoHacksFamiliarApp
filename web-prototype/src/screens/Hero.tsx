import type { ReactNode } from 'react';
import { StoreProvider, useStore } from '../state/store';
import { Icon } from '../components/Icon';
import { LockScreen } from './Event';
import { RecognizedScreen } from './Recognition';
import { LogoGlyph } from '../components/Logo';

/* 00 · Pitch hero (1920 × 1080) */
function MiniPhone({ children, label }: { children: ReactNode; label: string }) {
  return (
    <div role="img" aria-label={label} style={{ width: 328, height: 682, padding: 12, borderRadius: 58, background: '#14171D', boxShadow: '0 30px 60px rgba(11,27,63,.16), 0 8px 18px rgba(11,27,63,.10)' }}>
      <div style={{ width: 304, height: 658, borderRadius: 46, overflow: 'hidden', position: 'relative' }}>
        <div className="inert" style={{ width: 390, height: 844, transform: 'scale(0.7795)', transformOrigin: '0 0' }}>{children}</div>
        <div aria-hidden="true" style={{ position: 'absolute', top: 9, left: 103, width: 98, height: 29, borderRadius: 15, background: '#000' }} />
      </div>
    </div>
  );
}

function Step({ n, label }: { n: number; label: string }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
      <span aria-hidden="true" style={{ width: 34, height: 34, borderRadius: '50%', background: 'var(--accent-grad)', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 17, fontWeight: 700 }}>{n}</span>
      <span style={{ fontSize: 24, lineHeight: '32px', fontWeight: 600, whiteSpace: 'nowrap' }}>{label}</span>
    </div>
  );
}

export function HeroScreen() {
  const { state } = useStore();
  return (
    <div style={{ width: 1920, height: 1080, position: 'relative', overflow: 'hidden', display: 'flex', alignItems: 'center', gap: 80, padding: '0 120px', background: 'var(--bg)', color: 'var(--ink)', fontFamily: 'var(--font)' }}>
      <div style={{ width: 640, flexShrink: 0, display: 'flex', flexDirection: 'column' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 16 }}>
          <div aria-hidden="true" style={{ width: 56, height: 56, borderRadius: 15, background: 'var(--accent-grad)', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <LogoGlyph size={34} stroke={1.9} />
          </div>
          <span className="wordmark" style={{ fontSize: 34, lineHeight: '48px' }}>Familiar</span>
        </div>
        <h1 style={{ marginTop: 56, fontSize: 72, lineHeight: '80px', fontWeight: 700, letterSpacing: '-0.025em' }}>Remember names<br />and where you<br />left off.</h1>
        <p style={{ marginTop: 28, fontSize: 28, lineHeight: '40px', color: 'var(--muted)' }}>Your band taps your wrist when it hears someone you’ve met. One glance shows who it is and what you talked about.</p>
        <div style={{ marginTop: 48, display: 'flex', alignItems: 'flex-start', gap: 14, color: 'var(--navy)' }}>
          <Icon name="shield" size={30} stroke={1.75} style={{ marginTop: 1 }} />
          <span style={{ display: 'flex', flexDirection: 'column', fontSize: 24, lineHeight: '32px' }}>
            <span style={{ fontWeight: 700 }}>Private by default.</span>
            <span style={{ fontWeight: 500 }}>Voiceprints stay on your iPhone.</span>
          </span>
        </div>
      </div>

      <div style={{ flex: 1, minWidth: 0, display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between' }}>
        <div style={{ width: 200, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 28 }}>
          <div style={{ width: 200, height: 682, position: 'relative' }}>
            <svg role="img" aria-label="Familiar band on its strap, sending tap rings" width="400" height="520" viewBox="0 0 400 520" fill="none" style={{ position: 'absolute', left: -100, top: 81 }}>
              <circle cx="200" cy="260" r="96" stroke="var(--sky)" strokeWidth="2.5" />
              <circle cx="200" cy="260" r="132" stroke="var(--ring-1)" strokeWidth="2.5" />
              <circle cx="200" cy="260" r="168" stroke="var(--ring-2)" strokeWidth="2.5" />
              <rect x="164" y="0" width="72" height="520" rx="26" fill="var(--band-strap)" />
              <rect x="155" y="176" width="90" height="168" rx="28" fill="var(--band-body)" />
              <rect x="163" y="184" width="74" height="152" rx="22" fill="var(--band-face)" />
              <circle cx="200" cy="214" r="5" fill="var(--sky)" />
            </svg>
          </div>
          <Step n={1} label="Wrist tap" />
        </div>
        <div style={{ width: 328, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 28 }}>
          <MiniPhone label="Lock Screen: You know this voice, open to view">
            <StoreProvider initial={state} interactive={false}><LockScreen /></StoreProvider>
          </MiniPhone>
          <Step n={2} label="Glance" />
        </div>
        <div style={{ width: 328, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 28 }}>
          <MiniPhone label="Familiar app: Maya Chen, voice match likely.">
            <StoreProvider initial={state} interactive={false}><RecognizedScreen /></StoreProvider>
          </MiniPhone>
          <Step n={3} label="Where you left off" />
        </div>
      </div>
    </div>
  );
}
