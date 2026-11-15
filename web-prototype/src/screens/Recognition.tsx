import { useState } from 'react';
import { selectors, useStore } from '../state/store';
import { initialsOf, introLine } from '../data/demo';
import { Icon } from '../components/Icon';
import { Avatar, BackLink, ConfidenceChip, SectionTitle, TalkingLabel, ToastView } from '../components/ui';
import { say, useIntroduceWhenSeen } from './Event';

/* 08 · Recognized — the server matched a registered face ("sure") */
export function RecognizedScreen() {
  const { state, dispatch, go } = useStore();
  useIntroduceWhenSeen();
  const person = selectors.inViewPerson(state) ?? selectors.person(state, 'Maria');
  if (!person) {
    return (
      <div className="screen screen--pad">
        <BackLink to="now" label="Now" />
        <p className="t-lead" style={{ marginTop: 24 }}>Nobody is in view right now.</p>
      </div>
    );
  }

  return (
    <div className="screen screen--pad stagger">
      <BackLink to="now" label="Now" />
      <section aria-label={`In view: ${person.name}`} className="match-card match-card--lg reveal stagger" style={{ marginTop: 12 }}>
        <div className="match-head">
          <TalkingLabel text="In view" />
          <ConfidenceChip match="sure" />
        </div>
        <Avatar initials={initialsOf(person.name)} ring="navy" live style={{ marginTop: 26 }} />
        <div style={{ marginTop: 22, display: 'flex', alignItems: 'center', gap: 12 }}>
          <h1 className="t-title" style={{ flex: 1, minWidth: 0 }}>This is {person.name}</h1>
          <button type="button" className="btn-sm btn-sm--on-navy" onClick={() => { dispatch({ type: 'rejectFace' }); go('now'); }}>
            Not {person.name}?
          </button>
        </div>
        <p className="match-meta">Your {person.relationship}</p>
        {person.recall && (
          <>
            <div className="match-divider" />
            <h2 className="eyebrow" style={{ marginTop: 16, padding: 0, color: 'var(--sky-text)' }}>Last time</h2>
            <p style={{ marginTop: 8, fontSize: 22, lineHeight: '29px', fontWeight: 600, letterSpacing: '-0.01em' }}>{person.recall.replace(/^Last time, /, '')}</p>
          </>
        )}
        {person.followUps.length > 0 && (
          <>
            <p className="match-kicker" style={{ marginTop: 18 }}>You could ask</p>
            {person.followUps.map((f) => <p key={f} style={{ marginTop: 4, fontSize: 16, lineHeight: '22px', fontWeight: 500 }}>{f}</p>)}
          </>
        )}
      </section>

      <div className="push stack-10">
        <button type="button" className="btn btn-primary" onClick={() => say(`${introLine(person)} ${person.recall}`)}>
          <Icon name="speaker" size={20} />Say it again
        </button>
        <button type="button" className="btn btn-secondary" onClick={() => { dispatch({ type: 'openPerson', name: person.name }); go('profile'); }}>
          About {person.name}
        </button>
      </div>
      <ToastView bottom={130} />
    </div>
  );
}

/* 09 · Possible match — the server answered "possible": no name is said or shown until confirmed */
export function PossibleMatchScreen() {
  const { state, dispatch, go } = useStore();
  const person = selectors.inViewPerson(state) ?? selectors.person(state, 'Maria');
  const name = person?.name ?? 'them';
  return (
    <div className="screen screen--pad stagger">
      <BackLink to="now" label="Now" />
      <Avatar unknown style={{ marginTop: 16 }} />
      <h1 className="t-title" style={{ marginTop: 12 }}>Might be {name}</h1>
      <span style={{ alignSelf: 'flex-start', marginTop: 10 }}><ConfidenceChip match="possible" onNavy={false} /></span>
      <p className="t-lead" style={{ marginTop: 12 }}>
        Familiar isn’t sure who this is, so it didn’t say a name. Details stay hidden, and their words aren’t kept until you confirm.
      </p>

      <section aria-label="Details hidden until you confirm" className="card card--pad" style={{ marginTop: 20 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, color: 'var(--blue)' }}>
          <Icon name="lock" size={18} />
          <p style={{ fontSize: 15, lineHeight: '20px', fontWeight: 600, color: 'var(--ink)' }}>Details hidden until you confirm</p>
        </div>
        <div aria-hidden="true" style={{ marginTop: 14, display: 'flex', flexDirection: 'column', gap: 10 }}>
          <div className="skeleton" style={{ width: '86%' }} />
          <div className="skeleton" style={{ width: '58%' }} />
        </div>
      </section>

      <div className="push stack-10">
        <button type="button" className="btn btn-primary" onClick={() => { dispatch({ type: 'confirmFace' }); go('recognized'); }}>
          Yes, it’s {name}
        </button>
        <button type="button" className="btn btn-secondary" onClick={() => { dispatch({ type: 'rejectFace' }); go('now'); }}>It’s someone else</button>
      </div>
    </div>
  );
}

/* 10 · Register a person — what the server needs to enrol someone: name, relationship, consent, face photos */
const relationships = ['daughter', 'son', 'grandson', 'granddaughter', 'friend', 'neighbour', 'carer', 'doctor'];

export function RegisterScreen() {
  const { state, dispatch, go } = useStore();
  const [name, setName] = useState('');
  const [relationship, setRelationship] = useState('');
  const [agreed, setAgreed] = useState(false);
  const [photos, setPhotos] = useState(0);
  const taken = state.people.some((p) => p.name.toLowerCase() === name.trim().toLowerCase());
  const canSave = !!name.trim() && !!relationship.trim() && agreed && photos > 0 && !taken;
  const shownName = name.trim() || 'Maria';
  const shownRel = relationship.trim() || 'daughter';

  return (
    <div className="screen">
      <main className="screen-main stagger">
        <BackLink to="people" label="People" />
        <h1 className="t-large" style={{ marginTop: 4 }}>Register a person</h1>

        <div className="card card--pad" style={{ marginTop: 14, display: 'flex', gap: 12, alignItems: 'center' }}>
          <span className="tile tile--36" aria-hidden="true"><Icon name="speaker" size={18} /></span>
          <p className="t-sub" style={{ color: 'var(--ink-2)' }}>You will hear: <strong style={{ color: 'var(--ink)' }}>“This is {shownName}, your {shownRel}.”</strong></p>
        </div>

        <label htmlFor="reg-name" className="field-label">Name</label>
        <input id="reg-name" className="input" placeholder="Their name" value={name} onChange={(e) => setName(e.target.value)} />
        {taken && <p className="t-small" style={{ marginTop: 6, paddingLeft: 4, color: 'var(--danger-ink)' }}>{name.trim()} is already registered.</p>}

        <label htmlFor="reg-rel" className="field-label" style={{ marginTop: 14 }}>Who they are to you</label>
        <input id="reg-rel" className="input" placeholder="Daughter, neighbour, carer…" value={relationship} onChange={(e) => setRelationship(e.target.value)} />
        <div style={{ marginTop: 8, display: 'flex', flexWrap: 'wrap', gap: 6 }}>
          {relationships.map((r) => (
            <button key={r} type="button" className={`chip ${relationship === r ? 'chip--live' : ''}`} style={{ border: 0, cursor: 'pointer', textTransform: 'capitalize' }} onClick={() => setRelationship(r)}>
              {r}
            </button>
          ))}
        </div>

        <SectionTitle style={{ marginTop: 20 }}>Photos of their face</SectionTitle>
        <div className="card card--pad" style={{ marginTop: 8 }}>
          <div className="grid-2">
            <button type="button" className="btn btn-secondary btn--48" onClick={() => setPhotos((n) => n + 1)}><Icon name="eye" size={18} />Take photo</button>
            <button type="button" className="btn btn-secondary btn--48" onClick={() => setPhotos((n) => n + 1)}><Icon name="recap" size={18} />From library</button>
          </div>
          <div className="progress" style={{ marginTop: 14 }} aria-label={`${photos} photo${photos === 1 ? '' : 's'}`}>
            {[1, 2, 3].map((n) => <div key={n}><div className="progress-fill" style={{ width: photos >= n ? '100%' : '0%' }} /></div>)}
          </div>
          <p className="t-small" style={{ marginTop: 8 }}>
            {photos === 0 ? 'Three or more works best: straight on, a little left, a little right. One face per photo.' : `${photos} photo${photos === 1 ? '' : 's'} of ${shownName} so far.${photos < 3 ? ' A couple more helps.' : ''}`}
          </p>
        </div>

        <label className="check">
          <input type="checkbox" checked={agreed} onChange={(e) => setAgreed(e.target.checked)} />
          <span style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
            <span style={{ fontSize: 15, lineHeight: '20px', fontWeight: 600 }}>They agreed to this</span>
            <span className="t-small">Familiar will recognise their face and keep what they say to you as text. Ask them, or their family, first.</span>
          </span>
        </label>

        <button
          type="button"
          className="btn btn-primary"
          style={{ marginTop: 18 }}
          disabled={!canSave}
          onClick={() => { dispatch({ type: 'register', name, relationship, photos }); go('profile'); }}
        >
          Register {name.trim() || 'person'}
        </button>
        <p className="t-small t-center" style={{ marginTop: 10 }}>The server keeps their name, relationship and numbers describing their face. Not the photos.</p>
      </main>
      <ToastView bottom={28} />
    </div>
  );
}
