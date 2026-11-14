import { useEffect, useState } from 'react';
import { selectors, useStore } from '../state/store';
import { clock } from '../data/demo';
import { Icon } from '../components/Icon';
import { Avatar, BackLink, ConfidenceChip, TalkingLabel, ToastView } from '../components/ui';
import { NowScreen } from './Event';

/* 08 · Recognized */
export function RecognizedScreen() {
  const { state, dispatch, go } = useStore();
  const person = selectors.matched(state) ?? selectors.person(state, 'maya');
  const [noting, setNoting] = useState(false);
  const [note, setNote] = useState('');
  if (!person) return <EmptyMatch />;
  const first = person.name.split(' ')[0];

  return (
    <div className="screen screen--pad stagger">
      <BackLink to="now" label="Now" />
      <section aria-label={`Recognized: ${person.name}`} className="match-card match-card--lg reveal stagger" style={{ marginTop: 12 }}>
        <div className="match-head">
          <TalkingLabel />
          <ConfidenceChip confidence="likely" />
        </div>
        <Avatar initials={person.initials} ring="navy" live style={{ marginTop: 26 }} />
        <div style={{ marginTop: 22, display: 'flex', alignItems: 'center', gap: 12 }}>
          <h1 className="t-title" style={{ flex: 1, minWidth: 0 }}>{person.name}</h1>
          <button type="button" className="btn-sm btn-sm--on-navy" onClick={() => { dispatch({ type: 'rejectMatch' }); go('now'); }}>
            Not {first}?
          </button>
        </div>
        {person.role && <p className="match-meta">{person.role}</p>}
        <div className="match-divider" />
        <h2 className="eyebrow" style={{ marginTop: 16, color: 'var(--sky-text)' }}>Where you left off</h2>
        {person.leftOff && (
          <>
            <p className="match-kicker" style={{ marginTop: 12 }}>{person.leftOff.when}</p>
            <p style={{ marginTop: 4, fontSize: 24, lineHeight: '30px', fontWeight: 600, letterSpacing: '-0.01em' }}>{person.leftOff.text}</p>
          </>
        )}
        {person.notes.slice(0, 2).map((n) => (
          <div key={n.when + n.text}>
            <p className="match-kicker" style={{ marginTop: 18 }}>{n.when}</p>
            <p style={{ marginTop: 4, fontSize: 17, lineHeight: '24px', fontWeight: 500 }}>{n.text}</p>
          </div>
        ))}
      </section>

      <div className="push">
        {noting ? (
          <div className="stack-10">
            <label htmlFor="note" className="sr-only">Note about {person.name}</label>
            <textarea id="note" className="input" autoFocus placeholder={`What do you want to remember about ${first}?`} value={note} onChange={(e) => setNote(e.target.value)} />
            <div className="grid-2">
              <button type="button" className="btn btn-secondary btn--48" onClick={() => { setNoting(false); setNote(''); }}>Cancel</button>
              <button
                type="button"
                className="btn btn-primary btn--48"
                disabled={!note.trim()}
                onClick={() => { dispatch({ type: 'addNote', personId: person.id, text: note.trim() }); setNoting(false); setNote(''); }}
              >
                Save note
              </button>
            </div>
          </div>
        ) : (
          <button type="button" className="btn btn-secondary" onClick={() => setNoting(true)}>
            <Icon name="pencil" size={20} stroke={1.75} />Add a note
          </button>
        )}
      </div>
      <ToastView bottom={120} />
    </div>
  );
}

function EmptyMatch() {
  return (
    <div className="screen screen--pad stagger">
      <BackLink to="now" label="Now" />
      <p className="t-lead" style={{ marginTop: 24 }}>No one is matched right now.</p>
    </div>
  );
}

/* 09 · Possible match */
export function PossibleMatchScreen() {
  const { state, dispatch, go } = useStore();
  const person = selectors.matched(state) ?? selectors.person(state, 'maya');
  const first = person?.name.split(' ')[0] ?? 'them';
  return (
    <div className="screen screen--pad stagger">
      <BackLink to="now" label="Now" />
      <Avatar unknown style={{ marginTop: 16 }} />
      <h1 className="t-title" style={{ marginTop: 12 }}>Possible match: {first}</h1>
      <span style={{ alignSelf: 'flex-start', marginTop: 10 }}><ConfidenceChip confidence="unsure" /></span>
      <p className="t-lead" style={{ marginTop: 12 }}>
        Familiar isn’t sure who’s talking. {first}’s details stay hidden, and nothing is added to {first === 'them' ? 'their' : 'her'} profile until you confirm.
      </p>

      <section aria-label="Context hidden until you confirm" className="card card--pad" style={{ marginTop: 20 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, color: 'var(--navy)' }}>
          <Icon name="lock" size={18} />
          <p style={{ fontSize: 15, lineHeight: '20px', fontWeight: 600, color: 'var(--ink)' }}>Context hidden until you confirm</p>
        </div>
        <div aria-hidden="true" style={{ marginTop: 14, display: 'flex', flexDirection: 'column', gap: 10 }}>
          <div className="skeleton" style={{ width: '86%' }} />
          <div className="skeleton" style={{ width: '58%' }} />
        </div>
      </section>

      <div className="push stack-10">
        <button type="button" className="btn btn-primary" onClick={() => { dispatch({ type: 'confirmMatch' }); go('recognized'); }}>
          Confirm it’s {first}
        </button>
        <button type="button" className="btn btn-secondary" onClick={() => go('people')}>Choose someone else</button>
        <button type="button" className="btn btn-text" onClick={() => { dispatch({ type: 'rejectMatch' }); go('now'); }}>Dismiss</button>
      </div>
    </div>
  );
}

/* 10 · New voice (sheet over Now) */
export function NewVoiceScreen() {
  const { state, dispatch, go } = useStore();
  const draft = selectors.activeDraft(state);
  const [name, setName] = useState(draft?.name ?? '');
  const [cue, setCue] = useState(draft?.cue ?? '');
  const [consent, setConsent] = useState(false);

  useEffect(() => {
    setName(draft?.name ?? '');
    setCue(draft?.cue ?? '');
    setConsent(false);
  }, [draft?.id]);

  const label = name.trim() || 'voice';
  const canSave = !!draft && !!name.trim() && consent;

  return (
    <div className="screen">
      <div className="inert" aria-hidden="true" style={{ position: 'absolute', inset: 0 }}><NowScreen /></div>
      <div className="scrim" onClick={() => go('now')} />
      <section role="dialog" aria-modal="true" aria-labelledby="nv-title" className="sheet">
        <div className="sheet-grabber" aria-hidden="true" />
        {!draft ? (
          <div style={{ padding: '24px 0' }}>
            <h2 id="nv-title" className="t-h3">No new voices</h2>
            <p className="t-sub" style={{ marginTop: 6 }}>Everyone you heard has been saved or discarded.</p>
            <button type="button" className="btn btn-primary" style={{ marginTop: 20 }} onClick={() => go('now')}>Back to Now</button>
          </div>
        ) : (
          <>
            <div style={{ marginTop: 14, display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12 }}>
              <h2 id="nv-title" className="t-h3">New voice</h2>
              <span className="chip chip--sm chip--dashed">Not saved</span>
            </div>

            <figure style={{ marginTop: 16, background: 'var(--bg)', border: '1px solid var(--line)', borderRadius: 14, padding: '14px 16px' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8, color: 'var(--navy)' }}>
                <Icon name="speaker" size={16} />
                <span style={{ fontSize: 13, lineHeight: '18px', fontWeight: 600 }}>Heard at {clock(draft.heardMin, true)}</span>
              </div>
              {draft.quote ? (
                <>
                  <blockquote style={{ marginTop: 6, fontSize: 17, lineHeight: '24px', fontWeight: 500 }}>{draft.quote}</blockquote>
                  <figcaption className="t-small" style={{ marginTop: 6 }}>Transcribed from speech. Not proof of who this is.</figcaption>
                </>
              ) : (
                <p className="t-sub" style={{ marginTop: 6 }}>No name was heard. Add one if you know who this is.</p>
              )}
            </figure>

            <label htmlFor="nv-name" className="field-label">Name</label>
            <input id="nv-name" className="input" type="text" value={name} placeholder="Their name" onChange={(e) => setName(e.target.value)} />
            <label htmlFor="nv-cue" className="field-label" style={{ marginTop: 14 }}>Cue</label>
            <input id="nv-cue" className="input" type="text" value={cue} placeholder="Something to remember them by" onChange={(e) => setCue(e.target.value)} />

            <label className="check">
              <input type="checkbox" checked={consent} onChange={(e) => setConsent(e.target.checked)} />
              <span style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                <span style={{ fontSize: 15, lineHeight: '20px', fontWeight: 600 }}>They’re OK with being saved</span>
                <span className="t-small">A voiceprint is biometric data. Recording rules vary by place, so ask first.</span>
              </span>
            </label>

            <button
              type="button"
              className="btn btn-primary"
              style={{ marginTop: 16 }}
              disabled={!canSave}
              onClick={() => { dispatch({ type: 'saveDraft', id: draft.id, name, cue }); go('now'); }}
            >
              Save {label}
            </button>
            <div className="grid-2" style={{ marginTop: 10 }}>
              <button type="button" className="btn btn-secondary btn--48" onClick={() => go('now')}>Review later</button>
              <button type="button" className="btn btn-danger btn--48" onClick={() => { dispatch({ type: 'discardDraft', id: draft.id }); go('now'); }}>Discard</button>
            </div>
            <p className="t-small t-center" style={{ marginTop: 12 }}>
              Voiceprints stay on this iPhone. Save or Discard deletes the audio; drafts expire in 7&nbsp;days.
            </p>
          </>
        )}
      </section>
    </div>
  );
}
