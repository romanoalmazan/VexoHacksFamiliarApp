import { useState } from 'react';
import { selectors, useStore } from '../state/store';
import { duration } from '../data/demo';
import { Icon } from '../components/Icon';
import { Avatar, BackLink, DraftRow, PersonRow, SectionTitle, TabScreen, TitleRow } from '../components/ui';

/* 11 · Recap */
export function RecapScreen() {
  const { state, dispatch, go } = useStore();
  const mins = state.lastSessionMinutes;
  const followUps = selectors.visibleFollowUps(state);
  const metToday = state.people.filter((p) => p.lastSeen.date === 'Today' || p.savedTonight || p.conversations.some((c) => c.when === 'Today'));

  if (mins == null) {
    return (
      <TabScreen tab="recaps">
        <TitleRow title="Recaps" />
        <div className="card card--pad" style={{ marginTop: 20 }}>
          <p className="t-row">No recaps yet</p>
          <p className="t-sub" style={{ marginTop: 4 }}>When you end a session, who you met and what to follow up on shows up here.</p>
        </div>
      </TabScreen>
    );
  }

  return (
    <TabScreen tab="recaps">
      <TitleRow title="Recap" />
      <p className="t-sub" style={{ marginTop: 2 }}>{state.sessionName ?? 'Session'} · Today · {duration(mins)}</p>

      {state.drafts.length > 0 && (
        <>
          <SectionTitle style={{ marginTop: 20 }}>Needs review</SectionTitle>
          <div className="stack-10" style={{ marginTop: 8 }}>
            {state.drafts.map((d) => (
              <DraftRow
                key={d.id}
                title={d.name ? `${d.name} (draft)` : 'Unnamed voice'}
                lines={['Not saved', 'Expires in 7 days']}
                primary
                onReview={() => { dispatch({ type: 'openDraft', id: d.id }); go('new-voice'); }}
              />
            ))}
          </div>
        </>
      )}

      <SectionTitle style={{ marginTop: 20 }}>Follow-ups</SectionTitle>
      <div className="card card-list" style={{ marginTop: 8 }}>
        {followUps.map((f, i) => {
          const added = state.tasks.includes(f.id);
          return (
            <div key={f.id}>
              {i > 0 && <div className="divider divider--inset-16" />}
              <div style={{ padding: '14px 14px 12px 16px' }}>
                <p className="t-row">{f.text}</p>
                <div style={{ marginTop: 6, display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 8 }}>
                  <span className="t-small">From your talk tonight</span>
                  <button
                    type="button"
                    className={`btn-sm ${added ? 'btn-sm--done' : ''}`}
                    style={{ padding: '0 12px' }}
                    aria-pressed={added}
                    aria-label={`Add ${f.text} to Familiar tasks`}
                    onClick={() => dispatch({ type: 'addTask', id: f.id })}
                  >
                    {added ? <><Icon name="check" size={16} stroke={2.5} />In Familiar tasks</> : 'Add to Familiar tasks'}
                  </button>
                </div>
              </div>
            </div>
          );
        })}
      </div>

      <SectionTitle style={{ marginTop: 20 }}>People you met</SectionTitle>
      <div className="card card-list" style={{ marginTop: 8 }}>
        {metToday.length === 0 && <p className="t-sub" style={{ padding: 16 }}>No one saved from this session.</p>}
        {metToday.map((p, i) => (
          <div key={p.id}>
            {i > 0 && <div className="divider divider--inset-70" />}
            <PersonRow
              person={p}
              sub={p.savedTonight ? 'Saved tonight' : `Saved · first met ${p.firstMet.date}`}
              onClick={() => { dispatch({ type: 'openPerson', id: p.id }); go('profile'); }}
            />
          </div>
        ))}
      </div>
    </TabScreen>
  );
}

/* 12a · People */
export function PeopleScreen() {
  const { state, dispatch, go } = useStore();
  const [q, setQ] = useState('');
  const query = q.trim().toLowerCase();
  const people = selectors.recentPeople(state).filter((p) =>
    !query || [p.name, p.role, p.lastSeen.event, p.firstMet.event, p.leftOff?.text, ...p.notes.map((n) => n.text)]
      .filter(Boolean).some((s) => s!.toLowerCase().includes(query)),
  );

  return (
    <TabScreen tab="people">
      <TitleRow title="People" />
      <label className="search">
        <Icon name="search" size={20} />
        <span className="sr-only">Search people</span>
        <input type="search" placeholder="Search names, events, topics" value={q} onChange={(e) => setQ(e.target.value)} />
      </label>

      {state.drafts.length > 0 && !query && (
        <>
          <SectionTitle style={{ marginTop: 24 }}>Drafts · not saved</SectionTitle>
          <div className="stack-10" style={{ marginTop: 8 }}>
            {state.drafts.map((d) => (
              <DraftRow
                key={d.id}
                title={d.name ? `${d.name} (draft)` : 'Unnamed voice'}
                lines={[`${state.sessionName ?? 'Session'} · Today`, 'Expires in 7 days']}
                onReview={() => { dispatch({ type: 'openDraft', id: d.id }); go('new-voice'); }}
              />
            ))}
          </div>
        </>
      )}

      <div style={{ marginTop: 16, height: 44, display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12 }}>
        <SectionTitle>Saved</SectionTitle>
        <button type="button" aria-label="Sort: recently met" style={{ height: 44, marginRight: -8, padding: '0 8px', display: 'inline-flex', alignItems: 'center', gap: 6, border: 0, background: 'transparent', color: 'var(--blue)', fontSize: 15, fontWeight: 600 }}>
          <Icon name="sort" size={16} />Recently met
        </button>
      </div>
      <div className="card card-list" style={{ marginTop: 4 }}>
        {people.length === 0 && <p className="t-sub" style={{ padding: 16 }}>{query ? `No one matches “${q}”.` : 'No one saved yet.'}</p>}
        {people.map((p, i) => (
          <div key={p.id}>
            {i > 0 && <div className="divider divider--inset-70" />}
            <PersonRow
              person={p}
              sub={`${p.lastSeen.event} · ${p.lastSeen.date}`}
              onClick={() => { dispatch({ type: 'openPerson', id: p.id }); go('profile'); }}
            />
          </div>
        ))}
      </div>
    </TabScreen>
  );
}

/* 12b · Profile */
export function ProfileScreen() {
  const { state, dispatch, go } = useStore();
  const person = selectors.person(state, state.activePersonId);
  const [confirming, setConfirming] = useState(false);

  if (!person) {
    return (
      <TabScreen tab="people">
        <BackLink to="people" label="People" />
        <p className="t-lead" style={{ marginTop: 16 }}>This person was forgotten.</p>
      </TabScreen>
    );
  }
  const first = person.name.split(' ')[0];
  const hasPortfolioTask = person.id === 'maya' && state.tasks.includes('f-portfolio');
  const summary = [person.leftOff, ...person.notes].filter(Boolean) as { when: string; text: string }[];

  return (
    <TabScreen tab="people">
      <BackLink to="people" label="People" />
      <div style={{ marginTop: 8, display: 'flex', alignItems: 'center', gap: 12 }}>
        <Avatar initials={person.initials} />
        <div style={{ minWidth: 0 }}>
          <h1 className="t-title">{person.name}</h1>
          {person.role && <p className="t-sub">{person.role}</p>}
        </div>
      </div>

      {hasPortfolioTask && (
        <div style={{ marginTop: 16, display: 'flex', alignItems: 'center', gap: 12, padding: '14px 16px', background: 'var(--tint)', borderRadius: 16 }}>
          <div className="tile tile--36 tile--white"><Icon name="clock" size={20} stroke={1.75} /></div>
          <div style={{ minWidth: 0 }}>
            <p className="t-row">Portfolio task is still open</p>
            <p className="t-small" style={{ marginTop: 2 }}>In Familiar tasks · added today</p>
          </div>
        </div>
      )}

      {summary.length > 0 && (
        <>
          <SectionTitle style={{ marginTop: 20 }}>Summary · updated {summary[0].when.startsWith('Today') ? 'today' : summary[0].when.split(' · ')[0]}</SectionTitle>
          <div className="card card-list" style={{ marginTop: 8 }}>
            {summary.map((n, i) => (
              <div key={n.when + n.text}>
                {i > 0 && <div className="divider divider--inset-16" />}
                <div style={{ padding: '12px 16px' }}>
                  <p className="t-small" style={{ fontWeight: 500 }}>{n.when}</p>
                  <p style={{ marginTop: 4, fontSize: 16, lineHeight: '22px' }}>{n.text}</p>
                </div>
              </div>
            ))}
          </div>
        </>
      )}

      <SectionTitle style={{ marginTop: 20 }}>Conversations</SectionTitle>
      <div className="card card-list" style={{ marginTop: 8 }}>
        {person.conversations.length === 0 && <p className="t-sub" style={{ padding: 16 }}>No conversations kept.</p>}
        {person.conversations.map((c, i) => (
          <div key={c.id}>
            {i > 0 && <div className="divider divider--inset-16" />}
            <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '10px 8px 10px 16px' }}>
              <div className="row-body">
                <p className="t-row">{c.event}</p>
                <p className="t-sub" style={{ marginTop: 2 }}>{c.when} · {c.mins} min</p>
              </div>
              <button
                type="button"
                className="btn-sm btn-sm--ghost-danger"
                aria-label={`Delete the ${c.event} conversation`}
                onClick={() => dispatch({ type: 'deleteConversation', personId: person.id, conversationId: c.id })}
              >
                <Icon name="trash" size={16} />Delete
              </button>
            </div>
          </div>
        ))}
      </div>

      {confirming ? (
        <div className="card card--pad confirm-in" style={{ marginTop: 20, borderColor: 'var(--danger)' }}>
          <p className="t-row">Forget {first}?</p>
          <p className="t-sub" style={{ marginTop: 4 }}>This deletes {first}’s notes and voiceprint. It can’t be undone.</p>
          <div className="grid-2" style={{ marginTop: 14 }}>
            <button type="button" className="btn btn-secondary btn--48" onClick={() => setConfirming(false)}>Cancel</button>
            <button
              type="button"
              className="btn btn--48 btn-danger-solid"
              onClick={() => { dispatch({ type: 'forget', personId: person.id }); go('people'); }}
            >
              Forget
            </button>
          </div>
        </div>
      ) : (
        <button type="button" className="btn btn-danger" style={{ marginTop: 20 }} onClick={() => setConfirming(true)}>
          <Icon name="trash" size={20} stroke={1.75} />Forget {first}
        </button>
      )}
      <p className="t-small" style={{ marginTop: 8 }}>Deletes {first}’s notes and voiceprint. Contacts or tasks you exported need separate removal.</p>
    </TabScreen>
  );
}
