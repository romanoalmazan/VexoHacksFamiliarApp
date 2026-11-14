import { useState } from 'react';
import { type LockMode, useStore } from '../state/store';
import { Icon } from '../components/Icon';
import { Avatar, BandArt, SectionTitle, TabScreen, TitleRow } from '../components/ui';
import { LogoGlyph } from '../components/Logo';

/* 13 · Show someone what Familiar does — the screen you hand to the other person */
const promises = [
  { icon: 'mic', text: 'It only listens during my sessions.' },
  { icon: 'person', text: 'Nothing about you is saved unless I tap Save.' },
  { icon: 'clock', text: 'Either way, the audio is deleted once I decide.' },
  { icon: 'phone', text: 'Voiceprints stay on my phone. Ask, and I’ll forget you.' },
];

export function ShowSomeoneScreen() {
  const { dispatch, back } = useStore();
  return (
    <div className="screen screen--pad screen--white stagger">
      <div style={{ display: 'flex', justifyContent: 'flex-end', marginRight: -10 }}>
        <button type="button" onClick={back} style={{ height: 44, padding: '0 10px', border: 0, background: 'none', color: 'var(--blue)', fontSize: 17, fontWeight: 600 }}>Done</button>
      </div>
      <BandArt height={120} rings={[34, 46, 58]} style={{ marginTop: 4 }} />
      <h1 style={{ marginTop: 20, fontSize: 30, lineHeight: '36px', fontWeight: 700, letterSpacing: '-0.02em' }}>Hi! I use Familiar to remember names.</h1>
      <p style={{ marginTop: 10, fontSize: 18, lineHeight: '25px', color: 'var(--muted)' }}>Here’s how it treats your voice:</p>
      <ul style={{ marginTop: 20, padding: 0, listStyle: 'none', display: 'flex', flexDirection: 'column', gap: 16 }}>
        {promises.map((p) => (
          <li key={p.text} style={{ display: 'flex', alignItems: 'flex-start', gap: 14 }}>
            <span className="tile tile--36" aria-hidden="true"><Icon name={p.icon} size={20} stroke={1.75} /></span>
            <span style={{ paddingTop: 6, fontSize: 17, lineHeight: '24px', textWrap: 'pretty' } as React.CSSProperties}>{p.text}</span>
          </li>
        ))}
      </ul>
      <div className="push stack-10">
        <button type="button" className="btn btn-primary" onClick={back}>Got it</button>
        <button type="button" className="btn btn-secondary" onClick={() => { dispatch({ type: 'declineLatest' }); back(); }}>
          Please don’t save me
        </button>
      </div>
    </div>
  );
}

/* 14 · Privacy tab */
const lockOptions: { id: LockMode; label: string }[] = [
  { id: 'private', label: 'Private' },
  { id: 'name', label: 'Name' },
  { id: 'details', label: 'Details' },
];

export function PrivacyTabScreen() {
  const { state, dispatch, go } = useStore();
  const [confirmAll, setConfirmAll] = useState(false);
  const live = state.session === 'live' || state.session === 'paused';
  const paused = state.session === 'paused';

  return (
    <TabScreen tab="privacy">
      <TitleRow title="Privacy" />

      <div className="card" style={{ marginTop: 16, display: 'flex', alignItems: 'center', gap: 14, padding: '10px 10px 10px 16px' }}>
        <span aria-hidden="true" style={{ width: 10, height: 10, flexShrink: 0, borderRadius: '50%', background: live && !paused ? 'var(--green)' : 'var(--outline)', boxShadow: live && !paused ? '0 0 0 4px var(--mint-tint)' : 'none' }} />
        <div className="row-body">
          <p className="t-row">{live ? (paused ? 'Paused' : 'Listening') : 'Not listening'}</p>
          <p className="t-sub">{live ? state.sessionName : 'Start a session from Now'}</p>
        </div>
        {live && (
          <button type="button" className="btn-sm" onClick={() => dispatch({ type: 'togglePause' })}>
            <Icon name={paused ? 'play' : 'pause'} size={16} stroke={2.25} />{paused ? 'Resume' : 'Pause'}
          </button>
        )}
      </div>

      <button type="button" className="callout" style={{ marginTop: 10 }} onClick={() => go('show-someone')}>
        <Icon name="people" size={22} stroke={1.75} />
        <span style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column', gap: 2 }}>
          <span className="callout-title">Show someone what Familiar does</span>
          <span className="callout-sub">Hand your phone to the other person.</span>
        </span>
        <Icon name="chevron" size={18} />
      </button>

      <SectionTitle style={{ marginTop: 22 }}>Lock Screen shows</SectionTitle>
      <div role="group" aria-label="Lock Screen shows" className="segmented" style={{ marginTop: 8 }}>
        <span
          className="segmented-thumb"
          aria-hidden="true"
          style={{ transform: (() => { const i = lockOptions.findIndex((o) => o.id === state.lockMode); return `translateX(calc(${i * 100}% + ${i * 4}px))`; })() }}
        />
        {lockOptions.map((o) => (
          <button key={o.id} type="button" aria-pressed={state.lockMode === o.id} onClick={() => dispatch({ type: 'setLock', mode: o.id })}>
            {o.label}
          </button>
        ))}
      </div>

      <div className="lock" style={{ marginTop: 10, padding: 12, borderRadius: 22, position: 'relative' }}>
      <div key={state.lockMode} className="crossfade frost" aria-label="Lock Screen preview" style={{ minHeight: 72, display: 'flex', alignItems: 'center', gap: state.lockMode === 'private' ? 12 : 16, padding: state.lockMode === 'private' ? 14 : '14px 14px 14px 12px', borderRadius: 20 }}>
        {state.lockMode === 'private' ? (
          <>
            <span className="notif-app" aria-hidden="true"><LogoGlyph size={24} stroke={2} /></span>
            <span style={{ minWidth: 0, display: 'flex', flexDirection: 'column' }}>
              <span style={{ fontSize: 15, lineHeight: '20px', fontWeight: 600 }}>You know this voice</span>
              <span style={{ fontSize: 15, lineHeight: '20px', color: 'var(--sky-text)' }}>Open to view</span>
            </span>
          </>
        ) : (
          <>
            <Avatar initials="MC" ring="navy" />
            <span style={{ minWidth: 0, display: 'flex', flexDirection: 'column' }}>
              <span style={{ fontSize: 17, lineHeight: '22px', fontWeight: 700 }}>{state.lockMode === 'name' ? 'Maya Chen' : 'Maya Chen · Oct 9'}</span>
              {state.lockMode === 'name'
                ? <span style={{ fontSize: 15, lineHeight: '20px', color: 'var(--sky-text)' }}>Someone you know</span>
                : <span style={{ fontSize: 14, lineHeight: '20px', fontWeight: 600 }}>You offered to send your portfolio.</span>}
            </span>
          </>
        )}
      </div>
      </div>
      <p className="t-small" style={{ marginTop: 6, paddingLeft: 4 }}>
        {state.lockMode === 'private' ? 'Private is the default.' : 'Anyone who sees your Lock Screen sees this. Unsure matches always stay private.'}
      </p>

      <SectionTitle style={{ marginTop: 20 }}>What Familiar keeps</SectionTitle>
      <div className="card card-list" style={{ marginTop: 8 }}>
        {[
          { icon: 'phone', text: 'Voiceprints stay on this iPhone' },
          { icon: 'mic', text: 'Audio is deleted once you save or discard someone' },
          { icon: 'clock', text: 'Unsaved drafts expire after 7 days' },
        ].map((r, i) => (
          <div key={r.text}>
            {i > 0 && <div className="divider divider--inset-48" />}
            <div style={{ display: 'flex', alignItems: 'flex-start', gap: 12, padding: '12px 16px', color: 'var(--navy)' }}>
              <Icon name={r.icon} size={20} stroke={1.75} />
              <p style={{ fontSize: 15, lineHeight: '20px', color: 'var(--ink)' }}>{r.text}</p>
            </div>
          </div>
        ))}
      </div>

      {confirmAll ? (
        <div className="card card--pad confirm-in" style={{ marginTop: 12, borderColor: 'var(--danger)' }}>
          <p className="t-row">Forget everyone?</p>
          <p className="t-sub" style={{ marginTop: 4 }}>Deletes all {state.people.length} people, their notes and voiceprints, and any unsaved voices. It can’t be undone.</p>
          <div className="grid-2" style={{ marginTop: 14 }}>
            <button type="button" className="btn btn-secondary btn--48" onClick={() => setConfirmAll(false)}>Cancel</button>
            <button type="button" className="btn btn--48 btn-danger-solid" onClick={() => { dispatch({ type: 'forgetAll' }); setConfirmAll(false); }}>
              Forget all
            </button>
          </div>
        </div>
      ) : (
        <button
          type="button"
          onClick={() => setConfirmAll(true)}
          style={{ marginTop: 8, alignSelf: 'flex-start', height: 44, marginLeft: -8, padding: '0 8px', display: 'inline-flex', alignItems: 'center', gap: 8, border: 0, background: 'transparent', color: 'var(--danger)', fontSize: 17, fontWeight: 600 }}
        >
          <Icon name="trash" size={18} stroke={1.75} />Forget everyone…
        </button>
      )}
      <p className="t-small">Exported Contacts or tasks need separate removal.</p>
    </TabScreen>
  );
}
