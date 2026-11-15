import { useEffect, useRef, useState } from 'react';
import { useStore } from '../state/store';
import { Icon } from '../components/Icon';
import { LogoGlyph } from '../components/Logo';
import { SetupHeader } from '../components/ui';

// 01b · Connect to your server.
// The real app has no accounts: server.py prints its address and a 6-digit pairing code, and the
// app sends that code as "Authorization: Bearer <code>" on every WebSocket. All API keys stay on the server.

const DEMO_ADDRESS = 'ws://familiar-laptop.local:8765';

export function ConnectScreen() {
  const { state, dispatch, go, interactive } = useStore();
  const [address, setAddress] = useState(state.server?.address ?? DEMO_ADDRESS);
  const [code, setCode] = useState(state.server?.code ?? '');
  const [status, setStatus] = useState<'idle' | 'checking' | 'done'>(state.server ? 'done' : 'idle');
  const inputRef = useRef<HTMLInputElement>(null);
  const addressOk = /^wss?:\/\/[^\s/]+(:\d+)?\/?$/.test(address.trim());

  // A full code with a valid address "connects" (demo), then moves on to pairing the band.
  useEffect(() => {
    if (code.length !== 6 || !addressOk || status !== 'idle') return;
    setStatus('checking');
    const t = setTimeout(() => { setStatus('done'); dispatch({ type: 'connect', address, code }); }, interactive ? 700 : 0);
    return () => clearTimeout(t);
  }, [code]); // eslint-disable-line react-hooks/exhaustive-deps

  useEffect(() => {
    if (status !== 'done' || !interactive) return;
    const t = setTimeout(() => go('pair'), 900);
    return () => clearTimeout(t);
  }, [status]); // eslint-disable-line react-hooks/exhaustive-deps

  const done = status === 'done';
  return (
    <div className="screen screen--pad stagger">
      <SetupHeader step={0} backTo="welcome" />

      {done ? (
        <div className="success-badge pop-in" style={{ marginTop: 20 }} aria-hidden="true">
          <Icon name="check" size={36} stroke={3} className="check-draw" />
        </div>
      ) : (
        <div className="hero-mark pop-in" style={{ marginTop: 20 }} aria-hidden="true"><LogoGlyph size={38} stroke={1.9} /></div>
      )}

      <h1 className="t-title" style={{ marginTop: 20 }}>{done ? 'Connected' : 'Connect to your server'}</h1>
      <p className="t-lead" style={{ marginTop: 6 }}>
        {done
          ? 'Your iPhone and the server can talk. Next, pair the band.'
          : 'Start Familiar’s server on a laptop on this Wi-Fi. It shows an address and a 6-digit pairing code.'}
      </p>

      <div className="field-group" style={{ marginTop: 20 }}>
        <label className="field-row">
          <Icon name="now" size={20} stroke={1.75} />
          <span className="sr-only">Server address</span>
          <input inputMode="url" autoCapitalize="off" autoCorrect="off" spellCheck={false} value={address} disabled={done} onChange={(e) => setAddress(e.target.value)} />
          {addressOk && <Icon name="checkCircle" size={18} className="valid" />}
        </label>
      </div>

      <p className="field-label" style={{ marginTop: 18 }}>Pairing code</p>
      <label className={`otp ${done ? 'otp--done' : ''}`} style={{ marginTop: 8 }} onClick={() => inputRef.current?.focus()}>
        <span className="sr-only">Pairing code</span>
        <input
          ref={inputRef}
          inputMode="numeric"
          autoComplete="one-time-code"
          maxLength={6}
          value={code}
          disabled={done || status === 'checking'}
          onChange={(e) => setCode(e.target.value.replace(/\D/g, '').slice(0, 6))}
        />
        {Array.from({ length: 6 }, (_, i) => {
          const ch = code[i];
          const active = !done && i === Math.min(code.length, 5) && code.length < 6;
          return (
            <span key={i} className={`otp-box ${active ? 'otp-box--active' : ''} ${ch ? 'otp-box--filled' : ''}`} aria-hidden="true">
              {ch ?? (active ? <span className="caret" /> : '')}
            </span>
          );
        })}
      </label>
      <p className="t-small" style={{ marginTop: 10, paddingLeft: 4 }}>
        {status === 'checking' ? 'Checking the code…' : !addressOk ? 'The address starts with ws:// and ends with :8765.' : 'Demo: any 6 digits work.'}
      </p>

      <div className="push" style={{ display: 'flex', alignItems: 'flex-start', gap: 8, color: 'var(--muted)' }}>
        <Icon name="lock" size={16} style={{ marginTop: 1 }} />
        <p className="t-small">Speech and face services are reached by the server. Their keys stay there, never in this app.</p>
      </div>
    </div>
  );
}
