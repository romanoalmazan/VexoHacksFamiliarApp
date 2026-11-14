import { useEffect, useRef, useState } from 'react';
import { useStore } from '../state/store';
import { Icon } from '../components/Icon';
import { LogoGlyph } from '../components/Logo';

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;

function AppleGlyph() {
  return (
    <svg width="18" height="20" viewBox="0 0 17 20" fill="currentColor" aria-hidden="true" style={{ marginTop: -2 }}>
      <path d="M14.1 10.6c0-2.6 2.1-3.8 2.2-3.9-1.2-1.8-3.1-2-3.7-2-1.6-.2-3.1.9-3.9.9-.8 0-2-.9-3.4-.9-1.7 0-3.3 1-4.2 2.6-1.8 3.1-.5 7.7 1.3 10.2.9 1.2 1.9 2.6 3.2 2.6 1.3-.1 1.8-.8 3.3-.8 1.6 0 2 .8 3.4.8 1.4 0 2.3-1.3 3.1-2.5 1-1.4 1.4-2.8 1.4-2.9 0 0-2.7-1-2.7-4.1zM11.6 3c.7-.9 1.2-2 1-3.2-1 0-2.3.7-3 1.5-.7.8-1.2 2-1.1 3.1 1.2.1 2.3-.6 3.1-1.4z" />
    </svg>
  );
}

function strengthOf(pw: string): { score: number; label: string; color: string } {
  let score = 0;
  if (pw.length >= 8) score++;
  if (/[a-z]/.test(pw) && /[A-Z]/.test(pw)) score++;
  if (/\d/.test(pw)) score++;
  if (/[^A-Za-z0-9]/.test(pw) || pw.length >= 14) score++;
  if (pw.length < 8) score = Math.min(score, 1);
  const map = [
    { label: 'Use at least 8 characters', color: 'var(--track)' },
    { label: 'Weak — add numbers or symbols', color: 'var(--red)' },
    { label: 'Fair — mix upper and lower case', color: 'var(--orange)' },
    { label: 'Good', color: 'var(--accent)' },
    { label: 'Strong password', color: 'var(--green)' },
  ];
  return { score, ...map[score] };
}

/* 01b · Sign up (and sign in) */
export function SignUpScreen() {
  const { dispatch, go } = useStore();
  const [mode, setMode] = useState<'signup' | 'signin'>('signup');
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [pw, setPw] = useState('');
  const [show, setShow] = useState(false);
  const [touched, setTouched] = useState(false);

  const isSignup = mode === 'signup';
  const emailOk = EMAIL_RE.test(email.trim());
  const strength = strengthOf(pw);
  const valid = emailOk && pw.length >= 8 && (!isSignup || name.trim().length > 0);

  const submit = () => {
    setTouched(true);
    if (!valid) return;
    dispatch({ type: 'signUp', name: isSignup ? name : email.split('@')[0], email, method: 'email' });
    if (!isSignup) dispatch({ type: 'verifyEmail' }); // returning users are already verified
    go(isSignup ? 'verify' : 'pair');
  };

  return (
    <div className="screen screen--pad stagger">
      <div style={{ display: 'flex', marginLeft: -12 }}>
        <button type="button" className="icon-back" aria-label="Back" onClick={() => go('welcome')}><Icon name="back" /></button>
      </div>

      <div className="hero-mark pop-in" style={{ marginTop: 8 }} aria-hidden="true"><LogoGlyph size={38} stroke={1.9} /></div>
      <h1 className="t-title" style={{ marginTop: 20 }}>
        {isSignup ? <>Create your <span className="gradient-text">Familiar</span> account</> : <>Welcome back</>}
      </h1>
      <p className="t-lead" style={{ marginTop: 6 }}>
        {isSignup ? 'Your people and notes stay on this iPhone. The account only syncs settings.' : 'Sign in to pick up where you left off.'}
      </p>

      <button
        type="button"
        className="btn btn-apple"
        style={{ marginTop: 22 }}
        onClick={() => { dispatch({ type: 'signUp', name: 'Alex Rivera', email: 'private@privaterelay.appleid.com', method: 'apple' }); go('pair'); }}
      >
        <AppleGlyph />{isSignup ? 'Sign up with Apple' : 'Sign in with Apple'}
      </button>

      <div className="or-divider">or use email</div>

      <form onSubmit={(e) => { e.preventDefault(); submit(); }} noValidate>
        <div className="field-group">
          {isSignup && (
            <label className="field-row">
              <Icon name="person" size={20} stroke={1.75} />
              <span className="sr-only">Full name</span>
              <input autoComplete="name" placeholder="Full name" value={name} onChange={(e) => setName(e.target.value)} />
              {name.trim() && <Icon name="checkCircle" size={18} className="valid" />}
            </label>
          )}
          <label className="field-row">
            <Icon name="mail" size={20} stroke={1.75} />
            <span className="sr-only">Email</span>
            <input type="email" inputMode="email" autoComplete="email" placeholder="Email" value={email} onChange={(e) => setEmail(e.target.value)} />
            {emailOk && <Icon name="checkCircle" size={18} className="valid" />}
          </label>
          <label className="field-row">
            <Icon name="lock" size={20} stroke={1.75} />
            <span className="sr-only">Password</span>
            <input
              type={show ? 'text' : 'password'}
              autoComplete={isSignup ? 'new-password' : 'current-password'}
              placeholder={isSignup ? 'Create a password' : 'Password'}
              value={pw}
              onChange={(e) => setPw(e.target.value)}
            />
            <button type="button" className="icon-btn" aria-label={show ? 'Hide password' : 'Show password'} onClick={() => setShow((v) => !v)}>
              <Icon name={show ? 'eyeOff' : 'eye'} size={19} stroke={1.75} />
            </button>
          </label>
        </div>

        {isSignup && (
          <>
            <div className="strength" aria-hidden="true">
              {[1, 2, 3, 4].map((n) => <i key={n} style={{ background: pw && n <= strength.score ? strength.color : undefined }} />)}
            </div>
            <p className="strength-label" aria-live="polite">{pw ? strength.label : 'Use at least 8 characters'}</p>
          </>
        )}
        {touched && !valid && (
          <p className="t-small" role="alert" style={{ marginTop: 8, paddingLeft: 4, color: 'var(--danger-ink)' }}>
            {!emailOk ? 'Enter a valid email address.' : pw.length < 8 ? 'Password needs at least 8 characters.' : 'Enter your name.'}
          </p>
        )}

        <button type="submit" className="btn btn-primary" style={{ marginTop: 18 }} disabled={touched && !valid}>
          {isSignup ? 'Create account' : 'Sign in'}
        </button>
      </form>

      <p className="mode-switch">
        {isSignup ? 'Already have an account? ' : 'New to Familiar? '}
        <button type="button" className="text-link" onClick={() => { setMode(isSignup ? 'signin' : 'signup'); setTouched(false); }}>
          {isSignup ? 'Sign in' : 'Create an account'}
        </button>
      </p>

      <p className="fine-print push">
        By continuing you agree to Familiar’s <a href="#terms" onClick={(e) => e.preventDefault()}>Terms</a> and{' '}
        <a href="#privacy" onClick={(e) => e.preventDefault()}>Privacy Policy</a>.
      </p>
    </div>
  );
}

/* 01c · Verify email */
export function VerifyScreen() {
  const { state, dispatch, go, interactive } = useStore();
  const [code, setCode] = useState('');
  const [done, setDone] = useState(false);
  const [wait, setWait] = useState(30);
  const inputRef = useRef<HTMLInputElement>(null);
  const email = state.account?.email ?? 'you@example.com';

  useEffect(() => {
    if (!interactive || wait <= 0) return;
    const t = setTimeout(() => setWait((w) => w - 1), 1000);
    return () => clearTimeout(t);
  }, [wait, interactive]);

  // A full code verifies the account…
  useEffect(() => {
    if (code.length !== 6 || done) return;
    setDone(true);
    dispatch({ type: 'verifyEmail' });
  }, [code]); // eslint-disable-line react-hooks/exhaustive-deps

  // …then, after the success check has played, move on to pairing.
  useEffect(() => {
    if (!done || !interactive) return;
    const t = setTimeout(() => go('pair'), 900);
    return () => clearTimeout(t);
  }, [done]); // eslint-disable-line react-hooks/exhaustive-deps

  return (
    <div className="screen screen--pad stagger">
      <div style={{ display: 'flex', marginLeft: -12 }}>
        <button type="button" className="icon-back" aria-label="Back" onClick={() => go('signup')}><Icon name="back" /></button>
      </div>

      {done ? (
        <div className="success-badge pop-in" style={{ marginTop: 16 }} aria-hidden="true">
          <Icon name="check" size={36} stroke={3} className="check-draw" />
        </div>
      ) : (
        <div className="hero-mark pop-in" style={{ marginTop: 16 }} aria-hidden="true"><Icon name="mail" size={30} stroke={2} /></div>
      )}

      <h1 className="t-title" style={{ marginTop: 20 }}>{done ? 'Email verified' : 'Check your email'}</h1>
      <p className="t-lead" style={{ marginTop: 6 }}>
        {done ? 'Nice — let’s pair your band.' : <>Enter the 6-digit code we sent to <strong style={{ color: 'var(--ink)', fontWeight: 600 }}>{email}</strong>.</>}
      </p>

      <label className={`otp ${done ? 'otp--done' : ''}`} onClick={() => inputRef.current?.focus()}>
        <span className="sr-only">Verification code</span>
        <input
          ref={inputRef}
          autoFocus={interactive}
          inputMode="numeric"
          autoComplete="one-time-code"
          maxLength={6}
          value={code}
          disabled={done}
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
      <p className="t-small" style={{ marginTop: 10, paddingLeft: 4 }}>Demo: any 6 digits work.</p>

      <div className="push stack-10">
        <button type="button" className="btn btn-secondary" disabled={wait > 0 || done} onClick={() => setWait(30)}>
          {wait > 0 ? <>Resend code in <span className="num">0:{String(wait).padStart(2, '0')}</span></> : 'Resend code'}
        </button>
        <button type="button" className="btn btn-text" onClick={() => go('signup')}>Use a different email</button>
      </div>
    </div>
  );
}
