import type { CSSProperties, ReactNode } from 'react';
import { Icon, type IconName } from './Icon';
import { useStore } from '../state/store';
import type { Person } from '../data/demo';
import { LogoGlyph } from './Logo';

/* ---------- Avatars ---------- */
export function Avatar({
  initials, ring, size = 44, unknown, live, saved, style,
}: {
  initials?: string;
  ring?: 'navy' | 'black';
  size?: 44 | 36;
  unknown?: boolean;
  live?: boolean;      // pulsing rings while this person is talking
  saved?: boolean;     // mint tint for people saved tonight
  style?: CSSProperties;
}) {
  const cls = [
    'avatar',
    size === 36 && 'avatar--36',
    ring === 'navy' && 'avatar--ring',
    ring === 'black' && 'avatar--ring-black',
    live && 'avatar--live',
    saved && 'avatar--saved',
    unknown && 'avatar--unknown',
  ].filter(Boolean).join(' ');
  return (
    <div className={cls} aria-hidden="true" style={style}>
      {unknown ? <Icon name="person" size={20} stroke={1.75} /> : initials}
    </div>
  );
}

/* ---------- Brand ---------- */
export function Brand() {
  return (
    <div className="brand">
      <div className="brand-mark" aria-hidden="true"><LogoGlyph size={23} stroke={2} /></div>
      <span className="brand-name wordmark">Familiar</span>
    </div>
  );
}

/* ---------- Header profile button → Settings ---------- */
export function ProfileButton() {
  const { state, go } = useStore();
  const name = state.account?.name;
  const initials = name ? name.trim().split(/\s+/).map((p) => p[0]).slice(0, 2).join('').toUpperCase() : null;
  return (
    <button type="button" className={`profile-btn ${initials ? 'profile-btn--account' : ''}`} aria-label="Settings" onClick={() => go('settings')}>
      {initials ?? <Icon name="person" size={19} stroke={1.9} />}
    </button>
  );
}

/** Large title with the profile button on the right, used on every tab. */
export function TitleRow({ title, children }: { title: string; children?: ReactNode }) {
  return (
    <div className="title-row">
      <h1 className="t-large">{title}</h1>
      <div className="header-actions">{children}<ProfileButton /></div>
    </div>
  );
}

/* ---------- "Talking now" label with animated speaking bars ---------- */
export function TalkingLabel({ text = 'Talking now' }: { text?: string }) {
  return (
    <span className="match-label">
      <span className="speaking" aria-hidden="true"><i /><i /><i /></span>{text}
    </span>
  );
}

/* ---------- Band illustration (strap + tap rings) ---------- */
export function BandArt({ width = 350, height = 136, rings = [38, 52, 66], strokeWidth = 1.5, style }: {
  width?: number; height?: number; rings?: number[]; strokeWidth?: number; style?: CSSProperties;
}) {
  const cx = width / 2;
  const cy = height / 2;
  const ringColors = ['var(--sky)', 'var(--ring-1)', 'var(--ring-2)'];
  return (
    <svg aria-hidden="true" width={width} height={height} viewBox={`0 0 ${width} ${height}`} fill="none" style={{ display: 'block', flexShrink: 0, ...style }}>
      <g className="band-rings">
        {rings.map((r, i) => <circle key={r} cx={cx} cy={cy} r={r} stroke={ringColors[i]} strokeWidth={strokeWidth} />)}
      </g>
      <rect x={cx - 14} y={0} width={28} height={height} rx={10} fill="var(--band-strap)" />
      <rect x={cx - 17} y={cy - 28} width={34} height={56} rx={11} fill="var(--band-body)" />
      <rect x={cx - 14} y={cy - 25} width={28} height={50} rx={8} fill="var(--band-face)" />
      <circle className="band-led" cx={cx} cy={cy - 14} r={2.5} fill="var(--blue)" />
    </svg>
  );
}

/* ---------- Navigation ---------- */
export function BackLink({ to, label }: { to?: string; label: string }) {
  const { go, back } = useStore();
  return (
    <button type="button" className="link-back" onClick={() => (to ? go(to) : back())}>
      <Icon name="back" />{label}
    </button>
  );
}

const tabs: { id: string; route: string; label: string; icon: IconName }[] = [
  { id: 'now', route: 'now', label: 'Now', icon: 'now' },
  { id: 'people', route: 'people', label: 'People', icon: 'people' },
  { id: 'recaps', route: 'recap', label: 'Recaps', icon: 'recap' },
  { id: 'privacy', route: 'privacy', label: 'Privacy', icon: 'shield' },
];

export function TabBar({ active }: { active: 'now' | 'people' | 'recaps' | 'privacy' }) {
  const { go } = useStore();
  return (
    <nav className="tabbar" aria-label="Tabs">
      {tabs.map((t) => (
        <button key={t.id} type="button" className="tab" aria-current={active === t.id ? 'page' : undefined} onClick={() => go(t.route)}>
          <Icon name={t.icon} stroke={1.75} />
          <span>{t.label}</span>
        </button>
      ))}
    </nav>
  );
}

const setupSteps = ['Pair', 'Privacy', 'Voice'];
export function SetupHeader({ step, backTo }: { step: 0 | 1 | 2; backTo: string }) {
  const { go } = useStore();
  return (
    <div className="setup-head">
      <button type="button" className="icon-back" aria-label="Back" onClick={() => go(backTo)}>
        <Icon name="back" />
      </button>
      <ol className="setup-steps" aria-label="Setup progress">
        {setupSteps.map((label, i) => (
          <li key={label} aria-current={i === step ? 'step' : undefined}>
            <div className={`setup-bar ${i <= step ? 'setup-bar--done' : ''}`} />
            <span className={`setup-label ${i === step ? 'setup-label--current' : ''}`}>{label}</span>
          </li>
        ))}
      </ol>
    </div>
  );
}

/* ---------- Layouts ---------- */
export function TabScreen({ tab, children, toastBottom = 100 }: {
  tab: 'now' | 'people' | 'recaps' | 'privacy'; children: ReactNode; toastBottom?: number;
}) {
  return (
    <div className="screen">
      <main className="screen-main stagger">{children}</main>
      <ToastView bottom={toastBottom} />
      <TabBar active={tab} />
    </div>
  );
}

export function ToastView({ bottom = 24 }: { bottom?: number }) {
  const { state } = useStore();
  const t = state.toast;
  if (!t) return null;
  return (
    <div className="toast" role="status" style={{ bottom }} key={t.title + (t.sub ?? '')}>
      <span className="toast-icon" aria-hidden="true">
        {t.initials ?? <Icon name="check" size={18} stroke={2.75} className="check-draw" />}
      </span>
      <span style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column' }}>
        <span className="toast-title">{t.title}</span>
        {t.sub && <span className="toast-sub">{t.sub}</span>}
      </span>
    </div>
  );
}

/* ---------- Chips ---------- */
export function ConfidenceChip({ confidence, onNavy = true }: { confidence: 'likely' | 'unsure'; onNavy?: boolean }) {
  const cls = confidence === 'likely' ? (onNavy ? 'chip chip--sm chip--navy' : 'chip chip--sm') : 'chip chip--sm chip--dashed';
  return (
    <span className={cls}>
      <Icon name="bars" size={14} stroke={2.5} />Voice match: {confidence}
    </span>
  );
}

/* ---------- Rows ---------- */
export function PersonRow({ person, sub, onClick }: { person: Person; sub: string; onClick: () => void }) {
  return (
    <button type="button" className="list-link" onClick={onClick}>
      <Avatar initials={person.initials} saved={person.savedTonight} />
      <span style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column' }}>
        <span className="t-row">{person.name}</span>
        <span className="t-sub">{sub}</span>
      </span>
      <Icon name="chevron" size={18} className="chev" />
    </button>
  );
}

export function DraftRow({ title, lines, onReview, primary }: {
  title: string; lines: string[]; onReview: () => void; primary?: boolean;
}) {
  return (
    <div className="card row">
      <Avatar unknown />
      <div className="row-body">
        <p className="t-row">{title}</p>
        {lines.map((l, i) => <p key={l} className="t-sub" style={i === 0 ? { marginTop: 2 } : undefined}>{l}</p>)}
      </div>
      <button type="button" className={`btn-sm ${primary ? 'btn-sm--primary' : ''}`} style={primary ? { padding: '0 14px' } : undefined} onClick={onReview} aria-label={`Review ${title.toLowerCase()}`}>
        Review
      </button>
    </div>
  );
}

export function SectionTitle({ children, style }: { children: ReactNode; style?: CSSProperties }) {
  return <h2 className="eyebrow" style={style}>{children}</h2>;
}
