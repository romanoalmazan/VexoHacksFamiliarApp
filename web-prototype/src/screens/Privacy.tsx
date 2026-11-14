import { useState, type CSSProperties } from 'react';
import { type LockMode, useStore } from '../state/store';
import { Icon } from '../components/Icon';
import { LogoGlyph } from '../components/Logo';
import { Avatar, BandArt, SectionTitle, TabScreen, TitleRow } from '../components/ui';

/* 13 · Show someone what Familiar does — the screen the wearer hands to the other person */
const promises = [
  { icon: 'people', text: 'It only recognises people who agreed to it.' },
  { icon: 'eyeOff', text: 'If you’re not registered, your words are hidden and not kept.' },
  { icon: 'eye', text: 'Camera pictures are compared, then thrown away.' },
  { icon: 'trash', text: 'Ask, and you’ll be forgotten: your face data and notes are deleted.' },
];

export function ShowSomeoneScreen() {
  const { dispatch, back } = useStore();
  return (
    <div className="screen screen--pad screen--white stagger">
      <div style={{ display: 'flex', justifyContent: 'flex-end', marginRight: -10 }}>
        <button type="button" onClick={back} style={{ height: 44, padding: '0 10px', border: 0, background: 'none', color: 'var(--blue)', fontSize: 17, fontWeight: 600 }}>Done</button>
      </div>
      <BandArt height={110} rings={[32, 44, 54]} style={{ marginTop: 4 }} />
      <h1 style={{ marginTop: 18, fontSize: 30, lineHeight: '36px', fontWeight: 700, letterSpacing: '-0.02em' }}>Hi! Familiar helps me remember people.</h1>
      <p style={{ marginTop: 10, fontSize: 18, lineHeight: '25px', color: 'var(--muted)' }}>My memory isn’t what it was. Here’s how it works:</p>
      <ul style={{ marginTop: 18, padding: 0, listStyle: 'none', display: 'flex', flexDirection: 'column', gap: 14 }}>
        {promises.map((p) => (
          <li key={p.text} style={{ display: 'flex', alignItems: 'flex-start', gap: 14 }}>
            <span className="tile tile--36" aria-hidden="true"><Icon name={p.icon} size={20} stroke={1.75} /></span>
            <span style={{ paddingTop: 6, fontSize: 17, lineHeight: '24px', textWrap: 'pretty' } as CSSProperties}>{p.text}</span>
          </li>
        ))}
      </ul>
      <div className="push stack-10">
        <button type="button" className="btn btn-primary" onClick={back}>Got it</button>
        <button
          type="button"
          className="btn btn-secondary"
          onClick={() => { dispatch({ type: 'toast', toast: { title: 'Okay — they won’t be registered', sub: 'Their words stay hidden and aren’t kept.' } }); back(); }}
        >
          Please don’t register me
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

const keeps = [
  { icon: 'people', text: 'Each registered person’s name, relationship and numbers describing their face. No photos.' },
  { icon: 'mic', text: 'If you registered it, a description of how your own voice sounds. Never a recording.' },
  { icon: 'recap', text: 'Conversations with registered people, as text. No audio.' },
  { icon: 'eyeOff', text: 'Nothing about people who aren’t registered.' },
];

export function PrivacyTabScreen() {
  const { state, dispatch, go } = useStore();
  const [confirmAll, setConfirmAll] = useState(false);
  const i = lockOptions.findIndex((o) => o.id === state.lockMode);

  return (
    <TabScreen tab="privacy">
      <TitleRow title="Privacy" />

      <div className="card" style={{ marginTop: 16, display: 'flex', alignItems: 'center', gap: 14, padding: '10px 10px 10px 16px' }}>
        <span aria-hidden="true" style={{ width: 10, height: 10, flexShrink: 0, borderRadius: '50%', background: state.listening ? 'var(--green)' : 'var(--outline)', boxShadow: state.listening ? '0 0 0 4px var(--mint-tint)' : 'none' }} />
        <div className="row-body">
          <p className="t-row">{state.listening ? 'Listening' : 'Not listening'}</p>
          <p className="t-sub">{state.listening ? 'The band and camera are on' : 'Nothing is recorded until you tap Listen'}</p>
        </div>
        {state.listening && (
          <button type="button" className="btn-sm" onClick={() => { dispatch({ type: 'stopListening' }); go('recap'); }}>
            <Icon name="stop" size={15} />Stop
          </button>
        )}
      </div>

      <button type="button" className="callout" style={{ marginTop: 10 }} onClick={() => go('show-someone')}>
        <Icon name="people" size={22} stroke={1.75} />
        <span style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column', gap: 2 }}>
          <span className="callout-title">Show someone what Familiar does</span>
          <span className="callout-sub">Hand your phone to the other person.</span>
        </span>
        <Icon name="chevron" size={18} className="chev" />
      </button>

      <SectionTitle style={{ marginTop: 22 }}>Lock Screen shows</SectionTitle>
      <div role="group" aria-label="Lock Screen shows" className="segmented" style={{ marginTop: 8 }}>
        <span className="segmented-thumb" aria-hidden="true" style={{ transform: `translateX(calc(${i * 100}% + ${i * 4}px))` }} />
        {lockOptions.map((o) => (
          <button key={o.id} type="button" aria-pressed={state.lockMode === o.id} onClick={() => dispatch({ type: 'setLock', mode: o.id })}>{o.label}</button>
        ))}
      </div>
      <div className="lock" style={{ marginTop: 10, padding: 12, borderRadius: 22, position: 'relative' }}>
        <div key={state.lockMode} className="crossfade frost" aria-label="Lock Screen preview" style={{ minHeight: 72, display: 'flex', alignItems: 'center', gap: state.lockMode === 'private' ? 12 : 16, padding: state.lockMode === 'private' ? 14 : '14px 14px 14px 12px', borderRadius: 20 }}>
          {state.lockMode === 'private' ? (
            <>
              <span className="notif-app" aria-hidden="true"><LogoGlyph size={24} stroke={2} /></span>
              <span style={{ minWidth: 0, display: 'flex', flexDirection: 'column' }}>
                <span style={{ fontSize: 15, lineHeight: '20px', fontWeight: 600 }}>Someone you know is here</span>
                <span style={{ fontSize: 15, lineHeight: '20px', color: 'var(--sky-text)' }}>Open to view</span>
              </span>
            </>
          ) : (
            <>
              <Avatar initials="M" ring="navy" />
              <span style={{ minWidth: 0, display: 'flex', flexDirection: 'column' }}>
                <span style={{ fontSize: 17, lineHeight: '22px', fontWeight: 700 }}>This is Maria</span>
                {state.lockMode === 'name'
                  ? <span style={{ fontSize: 15, lineHeight: '20px', color: 'var(--sky-text)' }}>Your daughter</span>
                  : <span style={{ fontSize: 14, lineHeight: '20px', fontWeight: 600 }}>Last time, she told you about Leo’s graduation.</span>}
              </span>
            </>
          )}
        </div>
      </div>
      <p className="t-small" style={{ marginTop: 6, paddingLeft: 4 }}>
        {state.lockMode === 'private' ? 'Private is the default.' : 'Anyone who sees your Lock Screen sees this. Possible matches always stay private.'}
      </p>

      <SectionTitle style={{ marginTop: 20 }}>What your server keeps</SectionTitle>
      <div className="card card-list" style={{ marginTop: 8 }}>
        {keeps.map((r, k) => (
          <div key={r.text}>
            {k > 0 && <div className="divider divider--inset-48" />}
            <div style={{ display: 'flex', alignItems: 'flex-start', gap: 12, padding: '12px 16px', color: 'var(--blue)' }}>
              <Icon name={r.icon} size={20} stroke={1.75} />
              <p style={{ fontSize: 15, lineHeight: '20px', color: 'var(--ink)' }}>{r.text}</p>
            </div>
          </div>
        ))}
      </div>
      <p className="t-small" style={{ marginTop: 8, paddingLeft: 4 }}>While listening, the speech service hears the whole room to make the text. Tell people near you.</p>

      {confirmAll ? (
        <div className="card card--pad confirm-in" style={{ marginTop: 12, borderColor: 'var(--danger)' }}>
          <p className="t-row">Forget everyone?</p>
          <p className="t-sub" style={{ marginTop: 4 }}>Deletes all {state.people.length} people’s face data and profiles on the server. It can’t be undone.</p>
          <div className="grid-2" style={{ marginTop: 14 }}>
            <button type="button" className="btn btn-secondary btn--48" onClick={() => setConfirmAll(false)}>Cancel</button>
            <button type="button" className="btn btn--48 btn-danger-solid" onClick={() => { dispatch({ type: 'forgetAll' }); setConfirmAll(false); }}>Forget all</button>
          </div>
        </div>
      ) : (
        <button
          type="button"
          onClick={() => setConfirmAll(true)}
          style={{ marginTop: 8, alignSelf: 'flex-start', height: 44, marginLeft: -8, padding: '0 8px', display: 'inline-flex', alignItems: 'center', gap: 8, border: 0, background: 'transparent', color: 'var(--danger-ink)', fontSize: 17, fontWeight: 600 }}
        >
          <Icon name="trash" size={18} stroke={1.75} />Forget everyone…
        </button>
      )}
    </TabScreen>
  );
}
