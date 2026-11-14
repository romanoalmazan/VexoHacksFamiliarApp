import type { MouseEvent } from 'react';
import { type Appearance, useStore } from '../state/store';
import { switchThemeSmoothly, useSystemTheme } from '../state/theme';
import { initialsOf } from '../data/demo';
import { Icon } from '../components/Icon';
import { Avatar, BackLink, SectionTitle, ToastView } from '../components/ui';

/* Mini phone drawn in each theme for the Appearance picker */
function ThemePreview({ theme }: { theme: 'light' | 'dark' | 'split' }) {
  const light = { bg: '#EEF0F5', card: '#F8F8FF', ink: '#1E2330', line: 'rgba(76,84,104,.16)' };
  const dark = { bg: '#15181F', card: '#242936', ink: '#F8F8FF', line: 'rgba(248,248,255,.16)' };
  const Half = ({ c, clip }: { c: typeof light; clip?: string }) => (
    <g clipPath={clip}>
      <rect width="72" height="112" rx="14" fill={c.bg} />
      <rect x="10" y="16" width="30" height="6" rx="3" fill={c.ink} />
      <rect x="8" y="30" width="56" height="30" rx="8" fill="#2C3242" />
      <rect x="14" y="38" width="10" height="10" rx="5" fill="#8FDFFF" />
      <rect x="28" y="40" width="28" height="4" rx="2" fill="#F8F8FF" opacity=".85" />
      <rect x="8" y="66" width="56" height="16" rx="6" fill={c.card} />
      <rect x="14" y="72" width="26" height="4" rx="2" fill={c.line} />
      <rect x="8" y="86" width="56" height="12" rx="6" fill="#2799E8" />
    </g>
  );
  return (
    <svg width="72" height="112" viewBox="0 0 72 112" aria-hidden="true" style={{ display: 'block', borderRadius: 14, boxShadow: '0 0 0 1px var(--line), var(--shadow-card)' }}>
      <defs><clipPath id="half-right"><rect x="36" width="36" height="112" /></clipPath></defs>
      <Half c={theme === 'dark' ? dark : light} />
      {theme === 'split' && <Half c={dark} clip="url(#half-right)" />}
    </svg>
  );
}

const options: { id: Appearance; label: string; preview: 'light' | 'dark' | 'split' }[] = [
  { id: 'light', label: 'Light', preview: 'light' },
  { id: 'dark', label: 'Dark', preview: 'dark' },
  { id: 'system', label: 'Automatic', preview: 'split' },
];

function Row({ icon, title, value, onClick, danger }: { icon: string; title: string; value?: string; onClick?: () => void; danger?: boolean }) {
  return (
    <button type="button" className="list-link" style={{ minHeight: 52, color: danger ? 'var(--danger-ink)' : undefined }} onClick={onClick}>
      <span className="tile tile--32" aria-hidden="true" style={danger ? { background: 'var(--danger)' } : undefined}><Icon name={icon} size={17} stroke={2} /></span>
      <span className="t-row" style={{ flex: 1, fontWeight: 500, color: danger ? 'var(--danger-ink)' : undefined }}>{title}</span>
      {value && <span className="t-sub">{value}</span>}
      {!danger && <Icon name="chevron" size={16} className="chev" />}
    </button>
  );
}

/* 15 · Settings */
export function SettingsScreen() {
  const { state, dispatch, go } = useStore();
  const system = useSystemTheme();
  const acct = state.account;

  const pick = (id: Appearance, e: MouseEvent<HTMLButtonElement>) => {
    if (id === state.appearance) return;
    switchThemeSmoothly(() => dispatch({ type: 'setAppearance', appearance: id }), { x: e.clientX, y: e.clientY });
  };

  const lockLabel = { private: 'Private', name: 'Name', details: 'Details' }[state.lockMode];

  return (
    <div className="screen">
      <main className="screen-main stagger">
        <BackLink label="Back" />
        <h1 className="t-large" style={{ marginTop: 4 }}>Settings</h1>

        <button type="button" className="card list-link" style={{ marginTop: 16, minHeight: 76, borderRadius: 'var(--r-lg)' }} onClick={() => go(acct ? 'settings' : 'signup')}>
          <Avatar initials={acct ? initialsOf(acct.name) : undefined} unknown={!acct} />
          <span style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column' }}>
            <span className="t-row">{acct ? acct.name : 'Sign in to Familiar'}</span>
            <span className="t-sub" style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
              {acct ? `${acct.method === 'apple' ? 'Signed in with Apple' : acct.email}${acct.verified ? '' : ' · not verified'}` : 'Back up settings and pair new bands'}
            </span>
          </span>
          <Icon name="chevron" size={16} className="chev" />
        </button>

        <SectionTitle style={{ marginTop: 24 }}>Appearance</SectionTitle>
        <div className="card" style={{ marginTop: 8, padding: '18px 12px 14px' }}>
          <div role="radiogroup" aria-label="Appearance" style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 8 }}>
            {options.map((o) => {
              const on = state.appearance === o.id;
              return (
                <button
                  key={o.id}
                  type="button"
                  role="radio"
                  aria-checked={on}
                  className="appearance-option"
                  onClick={(e) => pick(o.id, e)}
                >
                  <ThemePreview theme={o.preview} />
                  <span className="appearance-label">{o.label}</span>
                  <span className={`appearance-radio ${on ? 'appearance-radio--on' : ''}`} aria-hidden="true">
                    {on && <Icon name="check" size={13} stroke={3} />}
                  </span>
                </button>
              );
            })}
          </div>
        </div>
        <p className="t-small" style={{ marginTop: 8, paddingLeft: 4 }}>
          {state.appearance === 'system' ? `Automatic follows your iPhone — it’s ${system} right now.` : `Familiar always uses the ${state.appearance} theme.`}
        </p>

        <SectionTitle style={{ marginTop: 24 }}>Familiar</SectionTitle>
        <div className="card card-list" style={{ marginTop: 8 }}>
          <Row icon="band" title="Band" value={state.pairedBand ? `Familiar Band · ${state.pairedBand}` : 'Not paired'} onClick={() => go('pair')} />
          <div className="divider" style={{ marginLeft: 58 }} />
          <Row icon="lock" title="Lock Screen shows" value={lockLabel} onClick={() => go('privacy')} />
          <div className="divider" style={{ marginLeft: 58 }} />
          <Row icon="shield" title="Privacy" onClick={() => go('privacy')} />
        </div>

        {acct && (
          <div className="card card-list" style={{ marginTop: 16 }}>
            <button type="button" className="list-link" style={{ minHeight: 52, justifyContent: 'center', color: 'var(--danger-ink)', fontSize: 17, fontWeight: 500 }} onClick={() => dispatch({ type: 'signOut' })}>
              Sign out
            </button>
          </div>
        )}

        <p className="t-small t-center" style={{ marginTop: 24, color: 'var(--subtle)' }}>Familiar 1.0 · Voiceprints never leave this iPhone</p>
      </main>
      <ToastView bottom={28} />
    </div>
  );
}
