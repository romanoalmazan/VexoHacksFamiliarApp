import { useEffect, useState } from 'react';
import { type Camera, useStore } from '../state/store';
import { Icon } from '../components/Icon';
import { Avatar, BandArt, Brand, SetupHeader, TalkingLabel } from '../components/ui';

/* 01 · Welcome */
export function WelcomeScreen() {
  const { go, state } = useStore();
  return (
    <div className="screen screen--pad stagger">
      <div style={{ marginTop: 12 }}><Brand /></div>
      <h1 className="t-display" style={{ marginTop: 36 }}>Know who’s with you, and what you last talked about.</h1>
      <p className="t-lead" style={{ marginTop: 12 }}>Your glasses see who you’re looking at. Your band hears the conversation. Familiar tells you who it is.</p>

      <BandArt style={{ marginTop: 20 }} />

      <section aria-label="Example of what you see and hear" className="match-card reveal" style={{ marginTop: 16, padding: '16px 20px 18px' }}>
        <div className="match-head">
          <TalkingLabel text="In view · just now" />
          <span className="chip chip--sm chip--navy" style={{ height: 22, fontSize: 12, padding: '0 9px' }}>Example</span>
        </div>
        <div className="match-person" style={{ marginTop: 16 }}>
          <Avatar initials="M" ring="navy" />
          <div style={{ minWidth: 0 }}>
            <p className="match-name" style={{ fontSize: 20, lineHeight: '26px' }}>This is Maria</p>
            <p className="match-meta">Your daughter</p>
          </div>
        </div>
        <div className="match-divider" />
        <p className="match-kicker">Last time</p>
        <p className="match-leftoff" style={{ fontSize: 17, lineHeight: '24px' }}>She told you about Leo’s graduation.</p>
      </section>

      <div className="push stack-14">
        <button type="button" className="btn btn-primary" onClick={() => go(state.server ? 'pair' : 'connect')}>Get started</button>
        <p className="t-small t-center">Only people who agreed are recognised. Nothing is recorded until you tap Listen.</p>
      </div>
    </div>
  );
}

/* 02 · Pair band — the app connects to the team's Vexo Open band over Bluetooth, or a pretend band */
const bands = ['64', '17'];
export function PairScreen() {
  const { go, dispatch, state } = useStore();
  const [pretend, setPretend] = useState(state.band?.pretend ?? false);
  const [blinked, setBlinked] = useState<string | null>(null);
  return (
    <div className="screen screen--pad stagger">
      <SetupHeader step={1} backTo="connect" />
      <h1 className="t-title" style={{ marginTop: 20 }}>Pair your band</h1>
      <p className="t-lead" style={{ marginTop: 8 }}>The band is Familiar’s ears. Its microphone streams to this iPhone over Bluetooth.</p>

      <div style={{ marginTop: 18, display: 'flex', justifyContent: 'center' }}>
        <BandArt width={220} height={120} rings={[34, 46, 58]} strokeWidth={2} />
      </div>

      <h2 className="eyebrow" style={{ marginTop: 20 }}>{pretend ? 'Pretend band' : 'Nearby'}</h2>
      <div className="stack-10" style={{ marginTop: 8 }}>
        {(pretend ? ['Demo'] : bands).map((id) => (
          <div key={id} className="card row">
            <div className="tile"><Icon name="band" size={22} stroke={1.75} /></div>
            <div className="row-body">
              <p className="t-row">{pretend ? 'Pretend band' : `Band ${id}`}</p>
              <p className="t-sub" style={{ marginTop: 2 }}>
                {pretend ? 'Plays a sample conversation' : id === '64' ? 'Your team’s band' : 'Another team’s band'}
              </p>
            </div>
            {!pretend && (
              <button type="button" className="btn-sm" aria-label={`Blink band ${id}'s light`} onClick={() => setBlinked(id)}>
                {blinked === id ? 'Blinking…' : 'Blink'}
              </button>
            )}
            <button
              type="button"
              className="btn-sm btn-sm--primary"
              aria-label={`Connect ${pretend ? 'the pretend band' : `band ${id}`}`}
              onClick={() => { dispatch({ type: 'pair', id: pretend ? 'pretend' : id, pretend }); go('setup-privacy'); }}
            >
              Connect
            </button>
          </div>
        ))}
      </div>

      <label className="check" style={{ marginTop: 14 }}>
        <input type="checkbox" checked={pretend} onChange={(e) => setPretend(e.target.checked)} />
        <span style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
          <span style={{ fontSize: 15, lineHeight: '20px', fontWeight: 600 }}>Use a pretend band</span>
          <span className="t-small">For trying Familiar without the hardware.</span>
        </span>
      </label>

      <div className="push" style={{ display: 'flex', alignItems: 'flex-start', gap: 8, color: 'var(--muted)' }}>
        <Icon name="info" size={16} style={{ marginTop: 1 }} />
        <p className="t-small">Not sure which is yours? Tap Blink and watch for the light.</p>
      </div>
    </div>
  );
}

/* 03 · How Familiar listens — the server's recording rules, in plain words */
export const privacyPoints = [
  { icon: 'people', title: 'Only people who agreed', body: 'Someone is recognised only after they, or their family, agree and you register them.' },
  { icon: 'eye', title: 'Strangers stay hidden', body: 'Words from anyone not registered are hidden, never saved, and dropped when the conversation ends.' },
  { icon: 'clock', title: 'Pictures are thrown away', body: 'Camera pictures are compared and discarded. Only numbers describing each face are kept.' },
  { icon: 'recap', title: 'Text only, no audio', body: 'Conversations are kept as text, on your server. No sound is stored.' },
] as const;

export function SetupPrivacyScreen() {
  const { go } = useStore();
  return (
    <div className="screen screen--pad stagger">
      <SetupHeader step={2} backTo="pair" />
      <h1 className="t-title" style={{ marginTop: 20 }}>How Familiar listens</h1>
      <p className="t-lead" style={{ marginTop: 8 }}>Read this with the people around you.</p>

      <div className="card card-list" style={{ marginTop: 18 }}>
        {privacyPoints.map((p, i) => (
          <div key={p.title}>
            {i > 0 && <div className="divider divider--inset-60" />}
            <div style={{ display: 'flex', gap: 12, padding: '13px 16px' }}>
              <div className="tile tile--32"><Icon name={p.icon} size={18} stroke={1.75} /></div>
              <div className="row-body">
                <h2 style={{ fontSize: 16, lineHeight: '21px', fontWeight: 600 }}>{p.title}</h2>
                <p className="t-sub" style={{ marginTop: 3 }}>{p.body}</p>
              </div>
            </div>
          </div>
        ))}
      </div>

      <div className="card card--pad" style={{ marginTop: 12, display: 'flex', gap: 12, background: 'var(--amber-tint)', boxShadow: 'none' }}>
        <Icon name="info" size={20} style={{ color: 'var(--amber-ink)', marginTop: 1 }} />
        <p className="t-sub" style={{ color: 'var(--ink-2)' }}>
          While Listen is on, the speech service hears the whole room to make the text. Tell people near you.
        </p>
      </div>

      <button type="button" className="callout" style={{ marginTop: 12 }} onClick={() => go('show-someone')}>
        <Icon name="people" size={22} stroke={1.75} />
        <span style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column', gap: 2 }}>
          <span className="callout-title">Show someone what Familiar does</span>
          <span className="callout-sub">Hand your phone to the other person.</span>
        </span>
        <Icon name="chevron" size={18} className="chev" />
      </button>

      <div className="push">
        <button type="button" className="btn btn-primary" onClick={() => go('camera')}>I understand</button>
      </div>
    </div>
  );
}

/* 04 · Choose a camera — Meta glasses (Wearables Device Access Toolkit) or the iPhone camera */
const cameras: { id: Camera; title: string; sub: string; icon: string }[] = [
  { id: 'glasses', title: 'Meta glasses', sub: 'Sees who you’re looking at, hands-free.', icon: 'eye' },
  { id: 'iphone', title: 'iPhone camera', sub: 'Hold up your phone, or prop it on a table.', icon: 'phone' },
];

export function CameraScreen() {
  const { go, dispatch, state } = useStore();
  const camera = state.camera ?? 'glasses';
  const needsLink = camera === 'glasses' && !state.glassesLinked;
  return (
    <div className="screen screen--pad stagger">
      <SetupHeader step={3} backTo="setup-privacy" />
      <h1 className="t-title" style={{ marginTop: 20 }}>Choose a camera</h1>
      <p className="t-lead" style={{ marginTop: 8 }}>The camera is Familiar’s eyes. About one picture a second goes to your server, is compared and thrown away.</p>

      <div role="radiogroup" aria-label="Camera" className="stack-10" style={{ marginTop: 20 }}>
        {cameras.map((c) => {
          const on = camera === c.id;
          return (
            <button
              key={c.id}
              type="button"
              role="radio"
              aria-checked={on}
              className="card row"
              style={{ width: '100%', textAlign: 'left', border: 0, boxShadow: on ? '0 0 0 2px var(--accent), var(--shadow-raised)' : undefined, transition: 'box-shadow var(--dur) var(--ease-out)' }}
              onClick={() => dispatch({ type: 'setCamera', camera: c.id })}
            >
              <div className="tile"><Icon name={c.icon} size={22} stroke={1.75} /></div>
              <div className="row-body">
                <p className="t-row">{c.title}</p>
                <p className="t-sub" style={{ marginTop: 2 }}>{c.sub}</p>
              </div>
              <span className={`appearance-radio ${on ? 'appearance-radio--on' : ''}`} aria-hidden="true">
                {on && <Icon name="check" size={13} stroke={3} />}
              </span>
            </button>
          );
        })}
      </div>

      {camera === 'glasses' && (
        <div className="card card--pad confirm-in" style={{ marginTop: 14 }}>
          <p className="t-row">{state.glassesLinked ? 'Glasses linked' : 'Link your glasses'}</p>
          <p className="t-sub" style={{ marginTop: 4 }}>
            {state.glassesLinked
              ? 'Meta AI approved Familiar. The first time you look for faces, it asks to allow the camera.'
              : 'In Meta AI, turn on Developer Mode (Settings → Your glasses). Then link: Meta AI opens, asks, and comes back here.'}
          </p>
          {!state.glassesLinked && (
            <button type="button" className="btn btn-secondary btn--48" style={{ marginTop: 12 }} onClick={() => dispatch({ type: 'linkGlasses' })}>
              Link Meta glasses
            </button>
          )}
        </div>
      )}

      <label className="check">
        <input type="checkbox" checked={state.speak} onChange={(e) => dispatch({ type: 'setSpeak', on: e.target.checked })} />
        <span style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
          <span style={{ fontSize: 15, lineHeight: '20px', fontWeight: 600 }}>Say who it is out loud</span>
          <span className="t-small">“This is Maria, your daughter.”</span>
        </span>
      </label>

      <div className="push">
        <button
          type="button"
          className="btn btn-primary"
          disabled={needsLink}
          onClick={() => { if (!state.camera) dispatch({ type: 'setCamera', camera }); go('voice'); }}
        >
          {needsLink ? 'Link the glasses first' : 'Continue'}
        </button>
      </div>
    </div>
  );
}

/* 04b · Register my voice — the server's /voice connection (server/voice.py).
   The wearer reads for 12 seconds through the band; the server keeps a description of how
   their voice sounds (me.json), never sound. Then "Me" is whoever sounds like the wearer.
   Without it, the first voice heard after Listen is taken to be the wearer. */
const READ_SECONDS = 12;
const wave = [6, 10, 16, 24, 18, 30, 38, 26, 14, 20, 34, 40, 28, 18, 12, 22, 32, 26, 16, 10, 18, 28, 36, 24, 14, 8, 12, 20, 14, 8, 6];

export function VoiceScreen() {
  const { state, dispatch, go, interactive } = useStore();
  const [phase, setPhase] = useState<'idle' | 'reading' | 'learning'>('idle');
  const [left, setLeft] = useState(READ_SECONDS);
  const inSetup = !state.lastConversation && !state.listening;

  useEffect(() => {
    if (phase !== 'reading' || !interactive) return;
    if (left <= 0) { setPhase('learning'); return; }
    const t = setTimeout(() => setLeft((n) => n - 1), 1000);
    return () => clearTimeout(t);
  }, [phase, left, interactive]);

  useEffect(() => {
    if (phase !== 'learning') return;
    const t = setTimeout(() => { dispatch({ type: 'registerVoice', seconds: 10.8 }); setPhase('idle'); setLeft(READ_SECONDS); }, 900);
    return () => clearTimeout(t);
  }, [phase]); // eslint-disable-line react-hooks/exhaustive-deps

  const blocked = !state.band ? 'Connect the band first.' : state.listening ? 'Switch Listen off first.' : null;
  const registered = !!state.voice;

  return (
    <div className="screen screen--pad stagger">
      <SetupHeader step={4} backTo="camera" />
      <h1 className="t-title" style={{ marginTop: 20 }}>Register my voice</h1>
      <p className="t-lead" style={{ marginTop: 8 }}>
        For the person wearing the band. Familiar keeps a description of how your voice sounds, not a recording, so it knows which voice is yours.
      </p>

      <section aria-label="Sentence to read aloud" className="card" style={{ marginTop: 20, borderRadius: 20, padding: '18px 20px 16px', display: 'flex', flexDirection: 'column' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 8 }}>
          <span className="t-small" style={{ fontWeight: 500 }}>Read this in your normal voice</span>
          {registered && phase === 'idle'
            ? <span className="chip chip--sm chip--live"><Icon name="check" size={13} stroke={3} />Registered</span>
            : phase === 'reading' && <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 13, fontWeight: 600, color: 'var(--blue)' }}><span className="dot dot--blue dot--live" />Listening</span>}
        </div>
        <p style={{ marginTop: 10, fontSize: 20, lineHeight: '28px', fontWeight: 600, letterSpacing: '-0.01em' }}>
          “When the sunlight strikes raindrops in the air, they act as a prism and form a rainbow.”
        </p>
        <svg role="img" aria-label="Your voice level" width="308" height="40" viewBox="0 0 308 44" className={`waveform ${phase === 'reading' ? 'waveform--live' : ''}`} style={{ marginTop: 16, display: 'block', opacity: phase === 'reading' ? 1 : 0.35, transition: 'opacity var(--dur)' }}>
          {wave.map((h, i) => <rect key={i} x={6 + i * 9.8} y={22 - h / 2} width="3" height={h} rx="1.5" fill="var(--accent)" style={{ animationDelay: `${(i % 7) * 0.09}s` }} />)}
        </svg>
        <div className="progress" style={{ marginTop: 14, gridTemplateColumns: '1fr' }}>
          <div><div className="progress-fill" style={{ width: `${phase === 'idle' ? (registered ? 100 : 0) : ((READ_SECONDS - left) / READ_SECONDS) * 100}%`, transition: 'width 1s linear' }} /></div>
        </div>
        <p className="t-small" style={{ marginTop: 8 }} aria-live="polite">
          {phase === 'reading' ? `Keep reading for ${left} more second${left === 1 ? '' : 's'}…`
            : phase === 'learning' ? 'Learning your voice…'
            : registered ? `Your voice is registered (${state.voice!.seconds.toFixed(1)} s of reading).`
            : `Wear the band as usual and read for ${READ_SECONDS} seconds. Its light turns blue while it listens.`}
        </p>
      </section>

      {blocked && <p className="t-small" style={{ marginTop: 10, paddingLeft: 4, color: 'var(--danger-ink)' }}>{blocked}</p>}

      <div className="push stack-10">
        {phase === 'idle' && (
          <button type="button" className={`btn ${registered ? 'btn-secondary' : 'btn-primary'}`} disabled={!!blocked} onClick={() => setPhase('reading')}>
            <Icon name="mic" size={20} />{registered ? 'Read it again' : 'Start, then read it out loud'}
          </button>
        )}
        {registered && phase === 'idle' && (
          <button type="button" className="btn btn-primary" onClick={() => go(inSetup ? 'now' : 'settings')}>{inSetup ? 'Finish setup' : 'Done'}</button>
        )}
        {!registered && phase === 'idle' && (
          <button type="button" className="btn btn-text" onClick={() => go('now')}>Skip for now</button>
        )}
        {registered && phase === 'idle' && (
          <button type="button" className="btn btn-text" style={{ color: 'var(--danger-ink)' }} onClick={() => dispatch({ type: 'forgetVoice' })}>Forget my voice</button>
        )}
        <p className="t-small t-center">
          {registered ? 'In every conversation, the voice that sounds like yours is shown as “Me”.' : 'Without a registered voice, the first voice heard after Listen is taken to be yours.'}
        </p>
      </div>
    </div>
  );
}
