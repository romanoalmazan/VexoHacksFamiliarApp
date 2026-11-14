import { useEffect, useRef, type CSSProperties, type ReactNode } from 'react';
import { selectors, useStore } from '../state/store';
import { DEMO_DATE, type Line, clock, initialsOf, introLine } from '../data/demo';
import { Icon } from '../components/Icon';
import { LogoGlyph } from '../components/Logo';
import { Avatar, ConfidenceChip, TabScreen, TalkingLabel, TitleRow } from '../components/ui';

/** Speaks a line through the device voice, like the app's "Say who it is out loud". */
export function say(text: string) {
  try {
    if (!('speechSynthesis' in window)) return;
    window.speechSynthesis.cancel();
    const u = new SpeechSynthesisUtterance(text);
    u.rate = 0.95;
    window.speechSynthesis.speak(u);
  } catch { /* speech not available */ }
}

/** Says "This is Maria, your daughter. Last time…" once, each time a new person is surely in view. */
export function useIntroduceWhenSeen() {
  const { state, interactive } = useStore();
  const said = useRef<string | null>(null);
  const person = selectors.inViewPerson(state);
  const sure = state.inView?.match === 'sure';
  useEffect(() => {
    if (!interactive || !state.speak || !sure || !person) { if (!state.inView) said.current = null; return; }
    if (said.current === person.name) return;
    said.current = person.name;
    say(`${introLine(person)} ${person.recall}`);
  }, [person?.name, sure, state.speak, interactive]); // eslint-disable-line react-hooks/exhaustive-deps
}

/* 05 / 06 · Now — ready, and listening */
export function NowScreen() {
  const { state } = useStore();
  return <TabScreen tab="now">{state.listening ? <NowLive /> : <NowReady />}</TabScreen>;
}

function StatusRow({ icon, title, value, ok, onClick }: { icon: string; title: string; value: string; ok: boolean; onClick: () => void }) {
  return (
    <button type="button" className="list-link" style={{ minHeight: 52 }} onClick={onClick}>
      <span className="tile tile--32" aria-hidden="true"><Icon name={icon} size={17} stroke={2} /></span>
      <span className="t-row" style={{ flex: 1, fontWeight: 500 }}>{title}</span>
      <span className="t-sub" style={{ color: ok ? 'var(--green-ink)' : 'var(--danger-ink)' }}>{value}</span>
      <Icon name="chevron" size={16} className="chev" />
    </button>
  );
}

function NowReady() {
  const { state, dispatch, go } = useStore();
  const ready = selectors.ready(state);
  const cameraLabel = state.camera === 'glasses' ? 'Meta glasses' : state.camera === 'iphone' ? 'iPhone' : 'Not chosen';
  return (
    <>
      <TitleRow title="Now">
        <span className="chip" style={{ gap: 6 }}><Icon name="band" size={16} />{state.band ? (state.band.pretend ? 'Pretend' : `Band ${state.band.id}`) : 'No band'}</span>
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
          <Icon name="mic" size={26} />
        </div>
        <h2 id="ready-title" className="t-h3" style={{ marginTop: 30 }}>{ready ? 'Ready when you are' : 'A few things first'}</h2>
        <p className="t-sub" style={{ marginTop: 6 }}>
          {ready
            ? 'Tap Listen when someone arrives. Familiar looks for faces and follows the conversation until you stop.'
            : 'Connect the server, the band and a camera to start.'}
        </p>
        <button
          type="button"
          className="btn btn-primary"
          style={{ marginTop: 20 }}
          onClick={() => { if (!ready) { go(!state.server ? 'connect' : !state.band ? 'pair' : 'camera'); return; } dispatch({ type: 'startListening' }); go('lock'); }}
        >
          {ready ? <><Icon name="mic" size={20} />Listen</> : 'Finish setup'}
        </button>
      </section>

      <h2 className="eyebrow" style={{ marginTop: 26 }}>Connections</h2>
      <div className="card card-list" style={{ marginTop: 8 }}>
        <StatusRow icon="now" title="Server" value={state.server ? 'Connected' : 'Not connected'} ok={!!state.server} onClick={() => go('connect')} />
        <div className="divider" style={{ marginLeft: 58 }} />
        <StatusRow icon="band" title="Band" value={state.band ? (state.band.pretend ? 'Pretend band' : `Band ${state.band.id}`) : 'Not paired'} ok={!!state.band} onClick={() => go('pair')} />
        <div className="divider" style={{ marginLeft: 58 }} />
        <StatusRow icon="eye" title="Camera" value={cameraLabel} ok={!!state.camera} onClick={() => go('camera')} />
      </div>
      {state.lastConversation && (
        <button type="button" className="callout" style={{ marginTop: 14 }} onClick={() => go('recap')}>
          <Icon name="recap" size={22} stroke={1.75} />
          <span style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column', gap: 2 }}>
            <span className="callout-title">Last conversation</span>
            <span className="callout-sub">{state.lastConversation.people.length ? state.lastConversation.people.join(', ') : 'Nothing was kept'}</span>
          </span>
          <Icon name="chevron" size={18} className="chev" />
        </button>
      )}
    </>
  );
}

const speakerLabel = (l: Line) => (l.speaker === 'me' ? 'Me' : l.speaker ?? '');

export function Transcript({ lines, style }: { lines: Line[]; style?: CSSProperties }) {
  const end = useRef<HTMLDivElement>(null);
  useEffect(() => { end.current?.scrollIntoView({ block: 'nearest' }); }, [lines.length]);
  return (
    <div className="transcript" style={style} aria-live="polite">
      {lines.length === 0 && <p className="t-sub">Words appear here as people talk.</p>}
      {lines.map((l, i) => (
        l.hidden ? (
          <p key={i} className="transcript-line transcript-line--hidden">
            <Icon name="eyeOff" size={15} stroke={1.9} />Someone who is not registered spoke. Not kept.
          </p>
        ) : (
          <p key={i} className="transcript-line">
            <span className={`transcript-who ${l.speaker === 'me' ? 'transcript-who--me' : ''}`}>{speakerLabel(l)}</span>
            {l.text}
          </p>
        )
      ))}
      <div ref={end} />
    </div>
  );
}

function NowLive() {
  const { state, dispatch, go, interactive } = useStore();
  useIntroduceWhenSeen();
  const person = selectors.inViewPerson(state);
  const possible = state.inView?.match === 'possible';

  let inView: ReactNode;
  if (person && !possible) {
    inView = (
      <section aria-label={`In view: ${person.name}`} className="match-card reveal" style={{ marginTop: 20 }}>
        <div className="match-head">
          <TalkingLabel text="In view" />
          <button type="button" className="btn-sm btn-sm--on-navy" onClick={() => dispatch({ type: 'rejectFace' })}>Not {person.name}?</button>
        </div>
        <button type="button" onClick={() => go('recognized')} style={{ all: 'unset', cursor: 'pointer', display: 'block' }} aria-label={`Open ${person.name}`}>
          <div className="match-person">
            <Avatar initials={initialsOf(person.name)} ring="navy" live />
            <div style={{ minWidth: 0, flex: 1 }}>
              <p className="match-name">This is {person.name}</p>
              <p className="match-meta">Your {person.relationship}</p>
            </div>
          </div>
        </button>
        <div style={{ marginTop: 14 }}><ConfidenceChip match="sure" /></div>
        {person.recall && (
          <>
            <div className="match-divider" style={{ marginTop: 14 }} />
            <p className="match-kicker">Last time</p>
            <p className="match-leftoff">{person.recall.replace(/^Last time, /, '')}</p>
          </>
        )}
      </section>
    );
  } else if (person && possible) {
    inView = (
      <button type="button" className="card row" style={{ marginTop: 20, textAlign: 'left', width: '100%', border: 0 }} onClick={() => go('possible-match')}>
        <Avatar unknown />
        <div className="row-body">
          <p className="t-row">Might be {person.name}</p>
          <p className="t-sub" style={{ marginTop: 2 }}>Not sure enough to say. Tap to confirm.</p>
        </div>
        <Icon name="chevron" size={18} className="chev" />
      </button>
    );
  } else {
    inView = (
      <section className="card card--pad" style={{ marginTop: 20, display: 'flex', alignItems: 'center', gap: 12 }}>
        <div className="tile"><Icon name="eye" size={22} stroke={1.75} /></div>
        <div className="row-body">
          <p className="t-row">Looking for faces</p>
          <p className="t-sub" style={{ marginTop: 2 }}>Using the {state.camera === 'iphone' ? 'iPhone camera' : 'Meta glasses'}. Only registered people get a name.</p>
        </div>
      </section>
    );
  }

  return (
    <>
      <TitleRow title="Now">
        <span className="chip chip--live"><span className={`dot dot--mint-ink ${interactive ? 'dot--live' : ''}`} />Listening</span>
      </TitleRow>
      {inView}
      <section aria-label="Live transcript" className="card card--pad" style={{ marginTop: 12 }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <p className="t-row">Live transcript</p>
          <span className="t-small num">since {clock(0, true)}</span>
        </div>
        <Transcript lines={state.transcript} style={{ marginTop: 10, maxHeight: 210 }} />
      </section>
      <button type="button" className="btn btn-danger" style={{ marginTop: 12 }} onClick={() => { dispatch({ type: 'stopListening' }); go('recap'); }}>
        <Icon name="stop" size={18} />Stop listening
      </button>
    </>
  );
}

/* 07a / 07b · Lock Screen — what the iPhone shows when someone you know is in view */
function LockRings() {
  return (
    <svg className="lock-rings" aria-hidden="true" width="390" height="844" viewBox="0 0 390 844" fill="none">
      {[130, 220, 310, 400].map((r) => <circle key={r} cx="195" cy="600" r={r} stroke="var(--ring-2)" strokeWidth="1.5" />)}
    </svg>
  );
}

export function LockScreen() {
  const { state, go } = useStore();
  const person = selectors.inViewPerson(state);
  const possible = state.inView?.match === 'possible';
  // A "possible" match never shows a name, whatever the Lock Screen setting is.
  const mode = possible || !person ? 'private' : state.lockMode;
  const open = () => go(possible ? 'possible-match' : 'recognized');

  return (
    <div className={`screen lock ${person ? 'buzz' : ''}`}>
      <LockRings />
      {person && <div className="tap-ripples" aria-hidden="true"><span /><span /><span /></div>}
      <div className="lock-clock">
        <p className="lock-date">{DEMO_DATE}</p>
        <p className="lock-time">{clock(state.minutes || 14)}</p>
      </div>

      {!person ? null : mode === 'private' ? (
        <button type="button" className="notif" onClick={open} aria-label="Familiar: someone you know is here. Open to view.">
          <span className="notif-app" aria-hidden="true"><LogoGlyph size={24} stroke={2} /></span>
          <span style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column' }}>
            <span style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', gap: 8 }}>
              <span style={{ fontSize: 15, lineHeight: '20px', fontWeight: 600 }}>Someone you know is here</span>
              <span style={{ flexShrink: 0, fontSize: 13, lineHeight: '18px', color: 'var(--sky-text)' }}>now</span>
            </span>
            <span style={{ marginTop: 2, fontSize: 15, lineHeight: '20px', color: 'var(--sky-text)' }}>Open to view</span>
          </span>
        </button>
      ) : (
        <button type="button" className="notif notif--detail" onClick={open} aria-label={`Familiar: ${introLine(person)}`}>
          <span style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <span className="notif-app notif-app--sm" aria-hidden="true"><LogoGlyph size={15} stroke={2.4} /></span>
            <span style={{ fontSize: 13, lineHeight: '18px', fontWeight: 600, color: 'var(--sky)' }}>Familiar · In view</span>
            <span style={{ marginLeft: 'auto', fontSize: 13, lineHeight: '18px', color: 'var(--sky-text)' }}>now</span>
          </span>
          <span style={{ marginTop: 12, display: 'flex', alignItems: 'center', gap: 16, paddingLeft: 2 }}>
            <Avatar initials={initialsOf(person.name)} ring="navy" />
            <span style={{ minWidth: 0, display: 'flex', flexDirection: 'column' }}>
              <span style={{ fontSize: 20, lineHeight: '24px', fontWeight: 700, letterSpacing: '-0.01em' }}>This is {person.name}</span>
              <span style={{ marginTop: 2, fontSize: 15, lineHeight: '20px', color: 'var(--sky-text)' }}>Your {person.relationship}</span>
            </span>
          </span>
          {mode === 'details' && person.recall && (
            <span style={{ marginTop: 12, fontSize: 15, lineHeight: '20px', fontWeight: 600 }}>{person.recall}</span>
          )}
        </button>
      )}
    </div>
  );
}

/* 07c · Dynamic Island — compact and expanded */
function IslandStage({ height, children }: { height: number; children: ReactNode }) {
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
  const pill: CSSProperties = {
    width: 236, height: 37, flexShrink: 0, borderRadius: 19, background: '#000', color: 'var(--sky)',
    display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '0 14px 0 13px',
  };
  return (
    <div className="screen" style={{ height: 680, padding: '24px 0 22px' }}>
      <h2 className="eyebrow" style={{ padding: '0 20px' }}>Compact · listening</h2>
      <IslandStage height={132}>
        <div role="img" aria-label="Dynamic Island, compact: Familiar is listening" style={pill}>
          <LogoGlyph size={20} stroke={2.1} />
          <Icon name="mic" size={18} />
        </div>
      </IslandStage>

      <h2 className="eyebrow" style={{ marginTop: 26, padding: '0 20px' }}>Compact · someone in view (name on)</h2>
      <IslandStage height={132}>
        <div role="img" aria-label="Dynamic Island, compact: Maria" style={pill}>
          <LogoGlyph size={20} stroke={2.1} />
          <span style={{ fontSize: 15, lineHeight: '20px', fontWeight: 600, color: '#fff' }}>Maria · daughter</span>
        </div>
      </IslandStage>

      <h2 className="eyebrow" style={{ marginTop: 26, padding: '0 20px' }}>Expanded · press and hold</h2>
      <div style={{ marginTop: 10, height: 232, overflow: 'hidden', display: 'flex', flexDirection: 'column', alignItems: 'center', paddingTop: 11, background: 'var(--surface)', border: '1px solid var(--line)', borderRadius: '52px 52px 0 0' }}>
        <section aria-label="Dynamic Island, expanded: Maria" style={{ width: 370, flexShrink: 0, borderRadius: 44, background: '#000', color: '#fff', padding: '12px 20px 18px', display: 'flex', flexDirection: 'column' }}>
          <div style={{ height: 26, display: 'flex', alignItems: 'center', gap: 6, color: 'var(--sky)' }}>
            <LogoGlyph size={17} stroke={2.2} />
            <span style={{ fontSize: 13, lineHeight: '18px', fontWeight: 600 }}>In view · Face match: sure</span>
          </div>
          <div style={{ marginTop: 12, display: 'flex', alignItems: 'center', gap: 14 }}>
            <Avatar initials="M" ring="black" />
            <div style={{ flex: 1, minWidth: 0 }}>
              <p style={{ fontSize: 20, lineHeight: '24px', fontWeight: 700, letterSpacing: '-0.01em' }}>This is Maria</p>
              <p style={{ marginTop: 2, fontSize: 13, lineHeight: '18px', color: '#AEB8CC' }}>Your daughter</p>
            </div>
            <button type="button" className="btn-sm btn-sm--on-navy" style={{ padding: '0 10px' }}>Not Maria?</button>
          </div>
          <p style={{ marginTop: 10, fontSize: 15, lineHeight: '20px', fontWeight: 600 }}>Last time, she told you about Leo’s graduation.</p>
        </section>
      </div>
    </div>
  );
}
