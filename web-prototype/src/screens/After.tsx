import { useState } from 'react';
import { selectors, useStore } from '../state/store';
import { duration, initialsOf, introLine } from '../data/demo';
import { Icon } from '../components/Icon';
import { Avatar, BackLink, PersonRow, SectionTitle, TabScreen, TitleRow } from '../components/ui';

/* 11 · Conversation — what was kept when Listen was switched off (server.py save() + profiles.py) */
export function RecapScreen() {
  const { state, dispatch, go } = useStore();
  const c = state.lastConversation;

  if (!c) {
    return (
      <TabScreen tab="recaps">
        <TitleRow title="Conversations" />
        <div className="card card--pad" style={{ marginTop: 20 }}>
          <p className="t-row">Nothing yet</p>
          <p className="t-sub" style={{ marginTop: 4 }}>When you stop listening, who you talked with and what to remember shows up here.</p>
        </div>
      </TabScreen>
    );
  }

  const people = c.people.map((n) => selectors.person(state, n)).filter(Boolean) as NonNullable<ReturnType<typeof selectors.person>>[];

  return (
    <TabScreen tab="recaps">
      <TitleRow title="Conversation" />
      <p className="t-sub" style={{ marginTop: 2 }}>Today · {duration(c.minutes)}</p>

      {people.length === 0 ? (
        <div className="card card--pad" style={{ marginTop: 18, display: 'flex', gap: 12 }}>
          <span className="tile tile--36" aria-hidden="true"><Icon name="eyeOff" size={18} /></span>
          <div>
            <p className="t-row">Nothing was kept</p>
            <p className="t-sub" style={{ marginTop: 4 }}>Nobody registered took part, so the conversation left nothing behind.</p>
          </div>
        </div>
      ) : (
        <>
          <SectionTitle style={{ marginTop: 20 }}>What to remember</SectionTitle>
          <div className="stack-10" style={{ marginTop: 8 }}>
            {people.map((p) => (
              <button key={p.name} type="button" className="card list-link" style={{ alignItems: 'flex-start', borderRadius: 'var(--r-lg)', padding: 16 }} onClick={() => { dispatch({ type: 'openPerson', name: p.name }); go('profile'); }}>
                <Avatar initials={initialsOf(p.name)} saved />
                <span style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column', gap: 4 }}>
                  <span className="t-row">{p.name} <span className="t-sub" style={{ fontWeight: 400, textTransform: 'capitalize' }}>· {p.relationship}</span></span>
                  <span style={{ fontSize: 16, lineHeight: '22px' }}>{p.recall}</span>
                </span>
                <Icon name="chevron" size={16} className="chev" style={{ marginTop: 4 }} />
              </button>
            ))}
          </div>

          {people.some((p) => p.followUps.length) && (
            <>
              <SectionTitle style={{ marginTop: 20 }}>Next time, you could ask</SectionTitle>
              <div className="card card-list" style={{ marginTop: 8 }}>
                {people.flatMap((p) => p.followUps.map((f) => ({ p, f }))).map(({ p, f }, i) => (
                  <div key={f}>
                    {i > 0 && <div className="divider divider--inset-16" />}
                    <div style={{ display: 'flex', gap: 12, padding: '13px 16px', alignItems: 'center' }}>
                      <Icon name="checkCircle" size={18} style={{ color: 'var(--blue)' }} />
                      <span style={{ flex: 1, fontSize: 16, lineHeight: '22px' }}>{f}</span>
                      <span className="t-small">{p.name}</span>
                    </div>
                  </div>
                ))}
              </div>
            </>
          )}
        </>
      )}

      <SectionTitle style={{ marginTop: 20 }}>What was kept</SectionTitle>
      <div className="card card-list" style={{ marginTop: 8 }}>
        <div style={{ display: 'flex', gap: 12, padding: '12px 16px', alignItems: 'center' }}>
          <Icon name="recap" size={18} style={{ color: 'var(--blue)' }} />
          <span style={{ flex: 1, fontSize: 15 }}>{c.kept} line{c.kept === 1 ? '' : 's'} of text, on your server</span>
        </div>
        <div className="divider divider--inset-48" />
        <div style={{ display: 'flex', gap: 12, padding: '12px 16px', alignItems: 'center' }}>
          <Icon name="eyeOff" size={18} style={{ color: 'var(--subtle)' }} />
          <span style={{ flex: 1, fontSize: 15 }}>{c.hidden} line{c.hidden === 1 ? '' : 's'} from people not registered: not kept</span>
        </div>
        <div className="divider divider--inset-48" />
        <div style={{ display: 'flex', gap: 12, padding: '12px 16px', alignItems: 'center' }}>
          <Icon name="mic" size={18} style={{ color: 'var(--subtle)' }} />
          <span style={{ flex: 1, fontSize: 15 }}>No audio stored</span>
        </div>
      </div>
    </TabScreen>
  );
}

/* 12a · People & faces — the server's registered people */
export function PeopleScreen() {
  const { state, dispatch, go } = useStore();
  const [q, setQ] = useState('');
  const query = q.trim().toLowerCase();
  const people = selectors.recentPeople(state).filter((p) =>
    !query || [p.name, p.relationship, p.recall, ...p.facts].some((s) => s.toLowerCase().includes(query)),
  );

  return (
    <TabScreen tab="people">
      <TitleRow title="People" />
      <label className="search">
        <Icon name="search" size={20} />
        <span className="sr-only">Search people</span>
        <input type="search" placeholder="Search names, relationships" value={q} onChange={(e) => setQ(e.target.value)} />
      </label>

      <button type="button" className="callout" style={{ marginTop: 14 }} onClick={() => go('register')}>
        <Icon name="people" size={22} stroke={1.75} />
        <span style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column', gap: 2 }}>
          <span className="callout-title">Register a person</span>
          <span className="callout-sub">Name, who they are, their OK, and a few photos.</span>
        </span>
        <Icon name="chevron" size={18} className="chev" />
      </button>

      <SectionTitle style={{ marginTop: 20 }}>Registered · {state.people.length}</SectionTitle>
      <div className="card card-list" style={{ marginTop: 8 }}>
        {people.length === 0 && <p className="t-sub" style={{ padding: 16 }}>{query ? `No one matches “${q}”.` : 'Nobody yet. Register someone to be recognised.'}</p>}
        {people.map((p, i) => (
          <div key={p.name}>
            {i > 0 && <div className="divider divider--inset-70" />}
            <PersonRow
              person={p}
              sub={`${p.relationship.charAt(0).toUpperCase() + p.relationship.slice(1)} · ${p.lastSeen ? `seen ${p.lastSeen}` : 'not seen yet'}`}
              onClick={() => { dispatch({ type: 'openPerson', name: p.name }); go('profile'); }}
            />
          </div>
        ))}
      </div>
      <p className="t-small" style={{ marginTop: 8, paddingLeft: 4 }}>Only registered people are recognised, and only their words are kept.</p>
    </TabScreen>
  );
}

/* 12b · Profile — recall, facts, follow-ups and visits from the server's profile */
export function ProfileScreen() {
  const { state, dispatch, go } = useStore();
  const person = selectors.person(state, state.activePerson);
  const [confirming, setConfirming] = useState(false);

  if (!person) {
    return (
      <TabScreen tab="people">
        <BackLink to="people" label="People" />
        <p className="t-lead" style={{ marginTop: 16 }}>This person was forgotten.</p>
      </TabScreen>
    );
  }

  return (
    <TabScreen tab="people">
      <BackLink to="people" label="People" />
      <div style={{ marginTop: 8, display: 'flex', alignItems: 'center', gap: 12 }}>
        <Avatar initials={initialsOf(person.name)} />
        <div style={{ minWidth: 0 }}>
          <h1 className="t-title">{person.name}</h1>
          <p className="t-sub">Your {person.relationship} · {person.photos} photo{person.photos === 1 ? '' : 's'}</p>
        </div>
      </div>

      <div className="card card--pad" style={{ marginTop: 16, display: 'flex', gap: 12, alignItems: 'center' }}>
        <span className="tile tile--36" aria-hidden="true"><Icon name="speaker" size={18} /></span>
        <p style={{ fontSize: 16, lineHeight: '22px', fontWeight: 500 }}>“{introLine(person)}”</p>
      </div>

      {person.recall ? (
        <>
          <SectionTitle style={{ marginTop: 20 }}>Last time{person.lastSeen ? ` · ${person.lastSeen}` : ''}</SectionTitle>
          <div className="card card--pad" style={{ marginTop: 8 }}>
            <p style={{ fontSize: 17, lineHeight: '24px' }}>{person.recall}</p>
          </div>
        </>
      ) : (
        <div className="card card--pad" style={{ marginTop: 20 }}>
          <p className="t-row">Nothing remembered yet</p>
          <p className="t-sub" style={{ marginTop: 4 }}>After your next conversation with {person.name}, Familiar notes what to remember.</p>
        </div>
      )}

      {person.facts.length > 0 && (
        <>
          <SectionTitle style={{ marginTop: 20 }}>Good to know</SectionTitle>
          <div className="card card-list" style={{ marginTop: 8 }}>
            {person.facts.map((f, i) => (
              <div key={f}>
                {i > 0 && <div className="divider divider--inset-16" />}
                <p style={{ padding: '12px 16px', fontSize: 16, lineHeight: '22px' }}>{f}</p>
              </div>
            ))}
          </div>
        </>
      )}

      {person.followUps.length > 0 && (
        <>
          <SectionTitle style={{ marginTop: 20 }}>You could ask</SectionTitle>
          <div className="card card-list" style={{ marginTop: 8 }}>
            {person.followUps.map((f, i) => (
              <div key={f}>
                {i > 0 && <div className="divider divider--inset-16" />}
                <p style={{ padding: '12px 16px', fontSize: 16, lineHeight: '22px' }}>{f}</p>
              </div>
            ))}
          </div>
        </>
      )}

      {person.visits.length > 1 && (
        <>
          <SectionTitle style={{ marginTop: 20 }}>Earlier visits</SectionTitle>
          <div className="card card-list" style={{ marginTop: 8 }}>
            {person.visits.slice(1).map((v, i) => (
              <div key={v.at + v.recall}>
                {i > 0 && <div className="divider divider--inset-16" />}
                <div style={{ padding: '12px 16px' }}>
                  <p className="t-small" style={{ fontWeight: 500 }}>{v.at}</p>
                  <p style={{ marginTop: 4, fontSize: 16, lineHeight: '22px' }}>{v.recall}</p>
                </div>
              </div>
            ))}
          </div>
        </>
      )}

      {confirming ? (
        <div className="card card--pad confirm-in" style={{ marginTop: 20, borderColor: 'var(--danger)' }}>
          <p className="t-row">Forget {person.name}?</p>
          <p className="t-sub" style={{ marginTop: 4 }}>Deletes {person.name}’s face data and profile on the server. It can’t be undone.</p>
          <div className="grid-2" style={{ marginTop: 14 }}>
            <button type="button" className="btn btn-secondary btn--48" onClick={() => setConfirming(false)}>Cancel</button>
            <button type="button" className="btn btn--48 btn-danger-solid" onClick={() => { dispatch({ type: 'forget', name: person.name }); go('people'); }}>Forget</button>
          </div>
        </div>
      ) : (
        <button type="button" className="btn btn-danger" style={{ marginTop: 20 }} onClick={() => setConfirming(true)}>
          <Icon name="trash" size={20} stroke={1.75} />Forget {person.name}
        </button>
      )}
      <p className="t-small" style={{ marginTop: 8, paddingLeft: 4 }}>Saved conversation text stays in the server’s conversations folder until someone removes it.</p>
    </TabScreen>
  );
}
