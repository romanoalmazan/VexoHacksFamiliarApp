import { useStore } from '../state/store';
import { Icon } from '../components/Icon';
import { Avatar, BandArt, Brand, SetupHeader, TalkingLabel } from '../components/ui';

/* 01 · Welcome */
export function WelcomeScreen() {
  const { go, state } = useStore();
  return (
    <div className="screen screen--pad stagger">
      <div style={{ marginTop: 12 }}><Brand /></div>
      <h1 className="t-display" style={{ marginTop: 36 }}>Remember names and where you left off.</h1>
      <p className="t-lead" style={{ marginTop: 12 }}>Your band taps your wrist when it hears someone you’ve met. Your phone shows who it is.</p>

      <BandArt style={{ marginTop: 20 }} />

      <section aria-label="Example of what you see after a wrist tap" className="match-card reveal" style={{ marginTop: 16, padding: '16px 20px 18px' }}>
        <div className="match-head">
          <TalkingLabel text="Wrist tap · just now" />
          <span className="chip chip--sm chip--navy" style={{ height: 22, fontSize: 12, padding: '0 9px' }}>Example</span>
        </div>
        <div className="match-person" style={{ marginTop: 16 }}>
          <Avatar initials="MC" ring="navy" />
          <div style={{ minWidth: 0 }}>
            <p className="match-name" style={{ fontSize: 20, lineHeight: '26px' }}>Maya Chen</p>
            <p className="match-meta">Met at Hardware Meetup · Oct 9</p>
          </div>
        </div>
        <div className="match-divider" />
        <p className="match-kicker">Where you left off</p>
        <p className="match-leftoff" style={{ fontSize: 17, lineHeight: '24px' }}>You offered to send your portfolio.</p>
      </section>

      <div className="push stack-14">
        <button type="button" className="btn btn-primary" onClick={() => go(state.account ? 'pair' : 'signup')}>Get started</button>
        <p className="t-small t-center">Nothing is recorded until you start a session.</p>
      </div>
    </div>
  );
}

/* 02 · Pair band */
const bands = ['4F2A', '91C7'];
export function PairScreen() {
  const { go, dispatch } = useStore();
  return (
    <div className="screen screen--pad stagger">
      <SetupHeader step={0} backTo="welcome" />
      <h1 className="t-title" style={{ marginTop: 20 }}>Pair your band</h1>
      <p className="t-lead" style={{ marginTop: 8 }}>Hold the button on your band until its light pulses.</p>

      <div style={{ marginTop: 20, display: 'flex', justifyContent: 'center' }}>
        <BandArt width={220} height={128} rings={[36, 50, 62]} strokeWidth={2} />
      </div>

      <h2 className="eyebrow" style={{ marginTop: 24 }}>Nearby</h2>
      <div className="stack-10" style={{ marginTop: 10 }}>
        {bands.map((id) => (
          <div key={id} className="card row">
            <div className="tile"><Icon name="band" size={22} stroke={1.75} /></div>
            <div className="row-body">
              <p className="t-row">Familiar Band · {id}</p>
              <p className="t-sub" style={{ marginTop: 2 }}>Available to pair</p>
            </div>
            <button
              type="button"
              className="btn-sm btn-sm--primary"
              aria-label={`Pair Familiar Band ${id}`}
              onClick={() => { dispatch({ type: 'pair', band: id }); go('setup-privacy'); }}
            >
              Pair
            </button>
          </div>
        ))}
      </div>
      <p className="t-sub" style={{ marginTop: 14 }}>Not sure which is yours? Match the 4 characters on the back of your band.</p>

      <div className="push" style={{ display: 'flex', alignItems: 'flex-start', gap: 8, color: 'var(--muted)' }}>
        <Icon name="info" size={16} style={{ marginTop: 1 }} />
        <p className="t-small">iOS will ask permission to connect your band.</p>
      </div>
    </div>
  );
}

/* 03 · Privacy (setup) */
export const privacyPoints = [
  { icon: 'mic', title: 'Only during sessions you start', body: 'Speech becomes short notes. Nothing is captured outside a session.' },
  { icon: 'voiceprint', title: 'Voiceprints stay on this iPhone', body: 'Made only for people you save. Nobody gets one until you tap Save.' },
  { icon: 'clock', title: 'Audio is deleted when you decide', body: 'Raw audio is deleted once you save or discard each person. Drafts expire after 7 days.' },
  { icon: 'trash', title: 'Forget anyone, any time', body: 'Deletes their notes and voiceprint. Exported Contacts or tasks need separate removal.' },
] as const;

export function SetupPrivacyScreen() {
  const { go } = useStore();
  return (
    <div className="screen screen--pad stagger">
      <SetupHeader step={1} backTo="pair" />
      <h1 className="t-title" style={{ marginTop: 20 }}>How Familiar listens</h1>
      <p className="t-lead" style={{ marginTop: 8 }}>Read this before your band listens.</p>

      <div className="card card-list" style={{ marginTop: 20 }}>
        {privacyPoints.map((p, i) => (
          <div key={p.title}>
            {i > 0 && <div className="divider divider--inset-60" />}
            <div style={{ display: 'flex', gap: 12, padding: '14px 16px' }}>
              <div className="tile tile--32"><Icon name={p.icon} size={18} stroke={1.75} /></div>
              <div className="row-body">
                <h2 style={{ fontSize: 16, lineHeight: '21px', fontWeight: 600 }}>{p.title}</h2>
                <p className="t-sub" style={{ marginTop: 3 }}>{p.body}</p>
              </div>
            </div>
          </div>
        ))}
      </div>

      <button type="button" className="callout" style={{ marginTop: 16 }} onClick={() => go('show-someone')}>
        <Icon name="people" size={22} stroke={1.75} />
        <span style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column', gap: 2 }}>
          <span className="callout-title">Show someone what Familiar does</span>
          <span className="callout-sub">Recording rules vary by place. Ask before you save someone.</span>
        </span>
        <Icon name="chevron" size={18} />
      </button>

      <div className="push">
        <button type="button" className="btn btn-primary" onClick={() => go('voice')}>Continue</button>
      </div>
    </div>
  );
}

/* 04 · Teach your voice */
const wave = [6, 10, 16, 24, 18, 30, 38, 26, 14, 20, 34, 40, 28, 18, 12, 22, 32, 26, 16, 10, 18, 28, 36, 24, 14, 8, 12, 20, 14, 8, 6];
const sentences = [
  '“Hi, I’m glad we finally get to meet. What are you working on?”',
  '“That sounds great. How did you get started with it?”',
  '“Let’s stay in touch. I’ll follow up next week.”',
];

export function VoiceScreen() {
  const { go, dispatch, state, interactive } = useStore();
  const { sample } = state;
  const isLast = sample === 3;
  return (
    <div className="screen screen--pad stagger">
      <SetupHeader step={2} backTo="setup-privacy" />
      <h1 className="t-title" style={{ marginTop: 20 }}>Teach Familiar your voice</h1>
      <p className="t-lead" style={{ marginTop: 8 }}>Read this aloud in your normal voice. It helps Familiar tell you apart from others.</p>

      <section aria-label="Sentence to read aloud" className="card" style={{ marginTop: 24, borderRadius: 20, padding: '18px 20px 16px', display: 'flex', flexDirection: 'column' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 8 }}>
          <span className="t-small" style={{ fontWeight: 500 }}>Read aloud</span>
          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 13, lineHeight: '18px', fontWeight: 600, color: 'var(--blue)' }}>
            <span className={`dot dot--blue ${interactive ? 'dot--live' : ''}`} />Listening
          </span>
        </div>
        <p key={sample} className="sentence-swap" style={{ marginTop: 10, fontSize: 24, lineHeight: '32px', fontWeight: 600, letterSpacing: '-0.01em' }}>{sentences[sample - 1]}</p>

        <svg role="img" aria-label="Your voice level" width="308" height="44" viewBox="0 0 308 44" className={`waveform ${interactive ? 'waveform--live' : ''}`} style={{ marginTop: 20, display: 'block' }}>
          {wave.map((h, i) => (
            <rect key={i} x={6 + i * 9.8} y={22 - h / 2} width="3" height={h} rx="1.5" fill="var(--blue)" style={{ animationDelay: `${(i % 7) * 0.09}s` }} />
          ))}
        </svg>

        <div className="divider" style={{ marginTop: 18 }} />
        <div style={{ marginTop: 12, display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12 }}>
          <span className="t-sub">Background noise</span>
          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 10 }}>
            <svg role="img" aria-label="Noise level 1 of 5" width="32" height="18" viewBox="0 0 32 18">
              {[0, 1, 2, 3, 4].map((i) => (
                <rect key={i} x={i * 7} y={12 - i * 3} width="4" height={6 + i * 3} rx="1" fill={i === 0 ? 'var(--accent)' : 'var(--track)'} />
              ))}
            </svg>
            <span style={{ fontSize: 15, lineHeight: '20px', fontWeight: 600, color: 'var(--navy)' }}>Low · good</span>
          </span>
        </div>
      </section>

      <div style={{ marginTop: 24 }}>
        <p style={{ fontSize: 15, lineHeight: '20px', fontWeight: 600 }}>Sample {sample} of 3</p>
        <div role="img" aria-label={`Sample ${sample} of 3 in progress`} className="progress" style={{ marginTop: 10 }}>
          {[1, 2, 3].map((n) => (
            <div key={n}><div className="progress-fill" style={{ width: n < sample ? '100%' : n === sample ? '60%' : '0%' }} /></div>
          ))}
        </div>
      </div>

      <div className="push">
        <button
          type="button"
          className="btn btn-primary"
          onClick={() => { if (isLast) go('now'); else dispatch({ type: 'nextSample' }); }}
        >
          {isLast ? 'Finish setup' : 'Next sample'}
        </button>
      </div>
    </div>
  );
}
