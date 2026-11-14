import { selectors, useStore } from '../state/store';
import { CALENDAR_EVENT, DEMO_DATE, clock } from '../data/demo';
import { Icon } from '../components/Icon';
import { Avatar, ConfidenceChip, TabScreen, TalkingLabel, TitleRow } from '../components/ui';
import { LogoGlyph } from '../components/Logo';

/* 05 / 06 / 10b · Now — ready, live, and after saving someone */
export function NowScreen() {
  const { state } = useStore();
  const live = state.session === 'live' || state.session === 'paused';
  return <TabScreen tab="now">{live ? <NowLive /> : <NowReady />}</TabScreen>;
}

function NowReady() {
  const { state, dispatch, go } = useStore();
  const named = state.sessionName === CALENDAR_EVENT.name;
  return (
    <>
      <TitleRow title="Now">
        <span className="chip" style={{ gap: 6 }}><Icon name="band" size={16} />Connected</span>
      </TitleRow>

      <section aria-labelledby="ready-title" className="card" style={{ marginTop: 20, borderRadius: 20, padding: '32px 20px 20px', display: 'flex', flexDirection: 'column' }}>
        <div
          aria-hidden="true"
          className="breathe"
          style={{
            marginLeft: 16, width: 56, height: 56, borderRadius: '50%', background: 'var(--tint)', color: 'var(--blue)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            boxShadow: '0 0 0 7px var(--surface), 0 0 0 8.5px var(--ring-1), 0 0 0 15px var(--surface), 0 0 0 16.5px var(--line)',
          }}
        >
          <Icon name="bars" size={26} />
        </div>
        <h2 id="ready-title" className="t-h3" style={{ marginTop: 30 }}>Ready when you are</h2>
        <p className="t-sub" style={{ marginTop: 6 }}>Listening never starts on its own. Start a session when you arrive, and pause or end it any time.</p>
        <button
          type="button"
          className="btn btn-primary"
          style={{ marginTop: 20 }}
          onClick={() => { dispatch({ type: 'startSession' }); go('lock'); }}
        >
          Start session{named ? ` · ${CALENDAR_EVENT.name}` : ''}
        </button>
      </section>

      <h2 className="eyebrow" style={{ marginTop: 28 }}>Suggested from your calendar</h2>
      <div className="card row" style={{ marginTop: 8 }}>
        <div className="tile"><Icon name="calendar" size={22} stroke={1.75} /></div>
        <div className="row-body">
          <p className="t-row">{CALENDAR_EVENT.name}</p>
          <p className="t-sub" style={{ marginTop: 2 }}>{CALENDAR_EVENT.when}</p>
        </div>
        <button
          type="button"
          className={`btn-sm ${named ? 'btn-sm--done' : ''}`}
          aria-label={`Name this session ${CALENDAR_EVENT.name}`}
          aria-pressed={named}
          onClick={() => dispatch({ type: 'nameSession' })}
        >
          {named ? <><Icon name="check" size={16} stroke={2.5} />Named</> : 'Name session'}
        </button>
      </div>
      <p className="t-small" style={{ marginTop: 8 }}>Naming the session makes its recap easy to find.</p>
    </>
  );
}

function NowLive() {
  const { state, dispatch, go, interactive } = useStore();
  const person = selectors.matched(state);
  const unsure = state.match?.confidence === 'unsure';
  const paused = state.session === 'paused';
  const drafts = state.drafts.length;

  return (
    <>
      <TitleRow title="Now">
        {paused
          ? <span className="chip chip--paused"><Icon name="pause" size={14} stroke={2.5} />Paused</span>
          : <span className="chip chip--live"><span className={`dot dot--mint-ink ${interactive ? 'dot--live' : ''}`} />Listening</span>}
      </TitleRow>

      {person && !unsure ? (
        <section aria-label={`Talking now: ${person.name}`} className="match-card reveal" style={{ marginTop: 20 }}>
          <div className="match-head">
            <TalkingLabel />
            <button type="button" className="btn-sm btn-sm--on-navy" onClick={() => dispatch({ type: 'rejectMatch' })}>
              Not {person.name.split(' ')[0]}?
            </button>
          </div>
          <button
            type="button"
            onClick={() => go('recognized')}
            style={{ all: 'unset', cursor: 'pointer', display: 'block' }}
            aria-label={`Open ${person.name}`}
          >
            <div className="match-person">
              <Avatar initials={person.initials} ring="navy" live />
              <div style={{ minWidth: 0, flex: 1 }}>
                <p className="match-name">{person.name}</p>
                <p className="match-meta">Met at {person.firstMet.event} · {person.firstMet.date}</p>
              </div>
            </div>
          </button>
          <div style={{ marginTop: 14 }}><ConfidenceChip confidence="likely" /></div>
          <div className="match-divider" style={{ marginTop: 14 }} />
          {person.leftOff && (
            <>
              <p className="match-kicker">Where you left off</p>
              <p className="match-leftoff">{person.leftOff.text}</p>
            </>
          )}
        </section>
      ) : unsure ? (
        <button type="button" className="card row" style={{ marginTop: 20, textAlign: 'left', width: '100%' }} onClick={() => go('possible-match')}>
          <Avatar unknown />
          <div className="row-body">
            <p className="t-row">Possible match</p>
            <p className="t-sub" style={{ marginTop: 2 }}>Familiar isn’t sure who’s talking. Tap to confirm.</p>
          </div>
          <Icon name="chevron" size={18} style={{ color: 'var(--outline)' }} />
        </button>
      ) : (
        <section className="card card--pad" style={{ marginTop: 20, display: 'flex', alignItems: 'center', gap: 12 }}>
          <div className="tile"><Icon name="now" size={22} stroke={1.75} /></div>
          <div className="row-body">
            <p className="t-row">{paused ? 'Listening is paused' : 'Listening for familiar voices'}</p>
            <p className="t-sub" style={{ marginTop: 2 }}>{paused ? 'Nothing is captured while paused.' : 'Your band taps when it hears someone you’ve saved.'}</p>
          </div>
        </section>
      )}

      <section aria-label="Session" className="card card--pad" style={{ marginTop: 12 }}>
        <p className="t-row">{state.sessionName ?? 'Session'}</p>
        <p className="t-sub" style={{ marginTop: 2 }}>{paused ? 'Paused' : 'Listening'} · {state.minutes} min · since {clock(0, true)}</p>
        <div className="grid-2" style={{ marginTop: 14 }}>
          <button type="button" className="btn btn-secondary btn--48" onClick={() => dispatch({ type: 'togglePause' })}>
            <Icon name={paused ? 'play' : 'pause'} size={18} stroke={2.25} />{paused ? 'Resume' : 'Pause'}
          </button>
          <button type="button" className="btn btn-danger btn--48" onClick={() => { dispatch({ type: 'endSession' }); go('recap'); }}>
            <Icon name="stop" size={18} />End session
          </button>
        </div>
      </section>

      {drafts > 0 && (
        <div className="card row" style={{ marginTop: 12 }}>
          <Avatar unknown />
          <div className="row-body">
            <p className="t-row">{drafts} new voice{drafts > 1 ? 's' : ''}</p>
            <p className="t-sub" style={{ marginTop: 2 }}>Not saved</p>
            <p className="t-sub">Expires in 7 days</p>
          </div>
          <button type="button" className="btn-sm" aria-label="Review new voices" onClick={() => { dispatch({ type: 'openDraft', id: null }); go('new-voice'); }}>
            Review
          </button>
        </div>
      )}
    </>
  );
}

/* 07a / 07b · Lock Screen */
function LockRings() {
  return (
    <svg className="lock-rings" aria-hidden="true" width="390" height="844" viewBox="0 0 390 844" fill="none">
      {[130, 220, 310, 400].map((r) => <circle key={r} cx="195" cy="600" r={r} stroke="var(--ring-2)" strokeWidth="1.5" />)}
    </svg>
  );
}

export function LockScreen() {
  const { state, go } = useStore();
  const person = selectors.matched(state);
  const unsure = state.match?.confidence === 'unsure';
  // An unsure match never reveals a name, whatever the Lock Screen setting is.
  const mode = unsure || !person ? 'private' : state.lockMode;
  const open = () => go(unsure ? 'possible-match' : 'recognized');
  const time = clock(state.minutes || 26);

  return (
    <div className={`screen lock ${person ? 'buzz' : ''}`}>
      <LockRings />
      {person && <div className="tap-ripples" aria-hidden="true"><span /><span /><span /></div>}
      <div className="lock-clock">
        <p className="lock-date">{DEMO_DATE}</p>
        <p className="lock-time">{time}</p>
      </div>

      {!person ? null : mode === 'private' ? (
        <button type="button" className="notif" onClick={open} aria-label="Familiar: you know this voice. Open to view.">
          <span className="notif-app" aria-hidden="true"><LogoGlyph size={24} stroke={2} /></span>
          <span style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column' }}>
            <span style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', gap: 8 }}>
              <span style={{ fontSize: 15, lineHeight: '20px', fontWeight: 600 }}>You know this voice</span>
              <span style={{ flexShrink: 0, fontSize: 13, lineHeight: '18px', color: 'var(--sky-text)' }}>now</span>
            </span>
            <span style={{ marginTop: 2, fontSize: 15, lineHeight: '20px', color: 'var(--sky-text)' }}>Open to view</span>
          </span>
        </button>
      ) : (
        <button type="button" className="notif notif--detail" onClick={open} aria-label={`Familiar: ${person.name}, likely match.`}>
          <span style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <span className="notif-app notif-app--sm" aria-hidden="true"><LogoGlyph size={15} stroke={2.4} /></span>
            <span style={{ fontSize: 13, lineHeight: '18px', fontWeight: 600, color: 'var(--sky)' }}>Familiar · Voice match: likely</span>
            <span style={{ marginLeft: 'auto', fontSize: 13, lineHeight: '18px', color: 'var(--sky-text)' }}>now</span>
          </span>
          <span style={{ marginTop: 12, display: 'flex', alignItems: 'center', gap: 20, paddingLeft: 2 }}>
            <Avatar initials={person.initials} ring="navy" />
            <span style={{ minWidth: 0, display: 'flex', flexDirection: 'column' }}>
              <span style={{ fontSize: 20, lineHeight: '24px', fontWeight: 700, letterSpacing: '-0.01em' }}>{person.name}</span>
              <span style={{ marginTop: 2, fontSize: 15, lineHeight: '20px', color: 'var(--sky-text)' }}>
                {mode === 'details' ? `${person.firstMet.event} · ${person.firstMet.date}` : 'Someone you know'}
              </span>
            </span>
          </span>
          {mode === 'details' && person.leftOff && (
            <span style={{ marginTop: 12, fontSize: 15, lineHeight: '20px', fontWeight: 600 }}>{person.leftOff.text}</span>
          )}
        </button>
      )}
    </div>
  );
}

/* 07c · Dynamic Island — compact and expanded */
function IslandStage({ height, children }: { height: number; children: React.ReactNode }) {
  return (
    <div style={{ marginTop: 10, height, overflow: 'hidden', display: 'flex', flexDirection: 'column', alignItems: 'center', paddingTop: 11, background: 'var(--surface)', border: '1px solid var(--line)', borderRadius: '52px 52px 0 0' }}>
      {children}
      <div aria-hidden="true" style={{ alignSelf: 'stretch', marginTop: 24, padding: '0 20px', display: 'flex', flexDirection: 'column', gap: 10 }}>
        <div style={{ width: 140, height: 14, borderRadius: 7, background: 'var(--line)' }} />
        <div style={{ height: 10, borderRadius: 5, background: 'var(--skeleton)' }} />
        <div style={{ width: '70%', height: 10, borderRadius: 5, background: 'var(--skeleton)' }} />
      </div>
    </div>
  );
}

export function DynamicIslandScreen() {
  const pill: React.CSSProperties = {
    width: 236, height: 37, flexShrink: 0, borderRadius: 19, background: '#000', color: 'var(--sky)',
    display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '0 14px 0 13px',
  };
  return (
    <div className="screen" style={{ height: 680, padding: '24px 0 22px' }}>
      <h2 className="eyebrow" style={{ padding: '0 20px' }}>Compact · default</h2>
      <IslandStage height={132}>
        <div role="img" aria-label="Dynamic Island, compact: Familiar heard someone you know" style={pill}>
          <LogoGlyph size={20} stroke={2.1} />
          <Icon name="person" size={18} />
        </div>
      </IslandStage>

      <h2 className="eyebrow" style={{ marginTop: 26, padding: '0 20px' }}>Compact · name on (opt-in)</h2>
      <IslandStage height={132}>
        <div role="img" aria-label="Dynamic Island, compact: Maya" style={pill}>
          <LogoGlyph size={20} stroke={2.1} />
          <span style={{ fontSize: 15, lineHeight: '20px', fontWeight: 600, color: '#fff' }}>Maya</span>
        </div>
      </IslandStage>

      <h2 className="eyebrow" style={{ marginTop: 26, padding: '0 20px' }}>Expanded · press and hold</h2>
      <div style={{ marginTop: 10, height: 232, overflow: 'hidden', display: 'flex', flexDirection: 'column', alignItems: 'center', paddingTop: 11, background: 'var(--surface)', border: '1px solid var(--line)', borderRadius: '52px 52px 0 0' }}>
        <section aria-label="Dynamic Island, expanded: Maya Chen" style={{ width: 370, flexShrink: 0, borderRadius: 44, background: '#000', color: '#fff', padding: '12px 20px 18px', display: 'flex', flexDirection: 'column' }}>
          <div style={{ height: 26, display: 'flex', alignItems: 'center', gap: 6, color: 'var(--sky)' }}>
            <LogoGlyph size={17} stroke={2.2} />
            <span style={{ fontSize: 13, lineHeight: '18px', fontWeight: 600 }}>Talking now · Voice match: likely</span>
          </div>
          <div style={{ marginTop: 12, display: 'flex', alignItems: 'center', gap: 14 }}>
            <Avatar initials="MC" ring="black" />
            <div style={{ flex: 1, minWidth: 0 }}>
              <p style={{ fontSize: 20, lineHeight: '24px', fontWeight: 700, letterSpacing: '-0.01em' }}>Maya Chen</p>
              <p style={{ marginTop: 2, fontSize: 13, lineHeight: '18px', color: '#AEB8CC' }}>Hardware Meetup · Oct 9</p>
            </div>
            <button type="button" className="btn-sm btn-sm--on-navy" style={{ padding: '0 10px' }}>Not Maya?</button>
          </div>
          <p style={{ marginTop: 10, fontSize: 15, lineHeight: '20px', fontWeight: 600 }}>You offered to send your portfolio.</p>
        </section>
      </div>
    </div>
  );
}
