import { useEffect, useRef, useState } from 'react';
import { type State, StoreProvider, useStore } from '../state/store';
import { clock } from '../data/demo';
import { switchThemeSmoothly, useResolvedTheme } from '../state/theme';
import { type Board, boards, routes, rows } from '../screens/registry';

function StatusBar({ hideTime }: { hideTime?: boolean }) {
  const { state } = useStore();
  const time = state.session === 'idle' ? '6:24' : clock(state.minutes);
  return (
    <div className="status-bar" aria-hidden="true">
      <span>{hideTime ? '' : time}</span>
      <span className="status-icons">
        <svg width="18" height="12" viewBox="0 0 18 12"><rect x="0" y="8" width="3" height="4" rx="1" /><rect x="5" y="5.5" width="3" height="6.5" rx="1" /><rect x="10" y="3" width="3" height="9" rx="1" /><rect x="15" y="0" width="3" height="12" rx="1" /></svg>
        <svg width="16" height="12" viewBox="0 0 16 12" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round"><path d="M1.5 4.5a9.5 9.5 0 0 1 13 0M4 7.2a6 6 0 0 1 8 0M6.6 9.8a2.3 2.3 0 0 1 2.8 0" /></svg>
        <svg width="26" height="12" viewBox="0 0 26 12"><rect x="0.5" y="0.5" width="22" height="11" rx="3.5" fill="none" stroke="currentColor" opacity=".4" /><rect x="2" y="2" width="16" height="8" rx="2" /><rect x="23.5" y="4" width="2" height="4" rx="1" opacity=".4" /></svg>
      </span>
    </div>
  );
}

/* ---------- Screen transitions ---------- */
type TxKind = 'push' | 'pop' | 'fade' | 'up' | 'down' | 'zoom' | 'none';
const TABS = new Set(['now', 'people', 'recap', 'privacy']);
const DEPTH: Record<string, number> = {
  welcome: 0, signup: 0.4, verify: 0.7, pair: 1, 'setup-privacy': 2, voice: 3,
  now: 4, people: 4, recap: 4, privacy: 4, island: 4,
  recognized: 5, 'possible-match': 5, profile: 5, settings: 5,
};

function kindFor(from: string, to: string): TxKind {
  if (to === 'lock' || from === 'lock') return 'zoom';
  if (to === 'show-someone') return 'up';
  if (from === 'show-someone') return 'down';
  if (to === 'new-voice') return 'none';        // the sheet animates itself
  if (from === 'new-voice') return 'fade';
  if (TABS.has(from) && TABS.has(to)) return 'fade';
  const a = DEPTH[from] ?? 4;
  const b = DEPTH[to] ?? 4;
  return b > a ? 'push' : b < a ? 'pop' : 'fade';
}

interface Layer { route: string; key: number; cls: string }

function ScreenTransition({ route }: { route: string }) {
  const [layers, setLayers] = useState<Layer[]>([{ route, key: 0, cls: '' }]);
  const prev = useRef(route);
  const counter = useRef(0);

  useEffect(() => {
    if (route === prev.current) return;
    const from = prev.current;
    const kind = kindFor(from, route);
    prev.current = route;
    const key = ++counter.current;
    if (kind === 'none') { setLayers([{ route, key, cls: '' }]); return; }
    setLayers((ls) => [
      { route: from, key: ls[ls.length - 1].key, cls: `tx-${kind}-exit inert` },
      { route, key, cls: `tx-${kind}-enter` },
    ]);
    const t = setTimeout(() => setLayers([{ route, key, cls: '' }]), 560);
    return () => clearTimeout(t);
  }, [route]);

  return (
    <>
      {layers.map((l) => {
        const Screen = routes[l.route] ?? routes.welcome;
        return <div key={l.key} className={`tx-layer ${l.cls}`}><Screen /></div>;
      })}
    </>
  );
}

function Phone({ route }: { route: string }) {
  const { state } = useStore();
  const theme = useResolvedTheme(state.appearance);
  const Screen = routes[route] ?? routes.welcome;
  const isBoard = route === 'island';
  const wrap = useRef<HTMLDivElement>(null);
  const [scale, setScale] = useState(1);

  useEffect(() => {
    const el = wrap.current;
    if (!el) return;
    const ro = new ResizeObserver(([e]) => {
      const { width, height } = e.contentRect;
      setScale(Math.min(1, (width - 16) / 414, (height - 16) / 868));
    });
    ro.observe(el);
    return () => ro.disconnect();
  }, []);

  if (route === 'hero') {
    return (
      <div ref={wrap} className="stage">
        <div style={{ width: 1920 * scale * 0.42, height: 1080 * scale * 0.42 }}>
          <div style={{ transform: `scale(${scale * 0.42})`, transformOrigin: '0 0' }}><Screen /></div>
        </div>
      </div>
    );
  }

  return (
    <div ref={wrap} className="stage">
      <div style={{ width: 414 * scale, height: (isBoard ? 704 : 868) * scale }}>
        <div className={isBoard ? 'board-solo' : 'phone'} style={{ transform: `scale(${scale})`, transformOrigin: '0 0' }}>
          <div className="phone-screen" data-theme={theme} style={isBoard ? { height: 680 } : undefined}>
            {isBoard ? <Screen /> : <ScreenTransition route={route} />}
            {!isBoard && <StatusBar hideTime={route === 'lock'} />}
            {!isBoard && <div className="phone-island" aria-hidden="true" />}
            {!isBoard && <div className="phone-home" aria-hidden="true" />}
          </div>
        </div>
      </div>
    </div>
  );
}

function SimulatePanel({ route, onReset }: { route: string; onReset: () => void }) {
  const { state, dispatch, go } = useStore();
  return (
    <aside className="panel">
      <h3>Simulate</h3>
      <p className="panel-hint">Pretend the band heard something.</p>
      <div className="panel-buttons">
        <button type="button" onClick={() => { dispatch({ type: 'simMatch', personId: 'maya', confidence: 'likely' }); go('lock'); }}>Familiar voice · Maya (likely)</button>
        <button type="button" onClick={() => { dispatch({ type: 'simMatch', personId: 'maya', confidence: 'unsure' }); go('lock'); }}>Unsure voice · maybe Maya</button>
        <button type="button" onClick={() => { dispatch({ type: 'simNewVoice' }); go('now'); }}>New, unknown voice</button>
      </div>

      <h3>Appearance</h3>
      <div className="panel-seg">
        {(['light', 'dark', 'system'] as const).map((m) => (
          <button key={m} type="button" aria-pressed={state.appearance === m} onClick={(e) => switchThemeSmoothly(() => dispatch({ type: 'setAppearance', appearance: m }), { x: e.clientX, y: e.clientY })}>{m}</button>
        ))}
      </div>

      <h3>Lock Screen shows</h3>
      <div className="panel-seg">
        {(['private', 'name', 'details'] as const).map((m) => (
          <button key={m} type="button" aria-pressed={state.lockMode === m} onClick={() => dispatch({ type: 'setLock', mode: m })}>{m}</button>
        ))}
      </div>

      <h3>State</h3>
      <dl className="panel-state">
        <dt>Route</dt><dd>{route}</dd>
        <dt>Session</dt><dd>{state.session}{state.sessionName ? ` · ${state.sessionName}` : ''}</dd>
        <dt>Demo clock</dt><dd>{state.session === 'idle' ? '—' : `${clock(state.minutes, true)} (${state.minutes} min in)`}</dd>
        <dt>Match</dt><dd>{state.match ? `${state.match.personId} · ${state.match.confidence}` : '—'}</dd>
        <dt>Unsaved voices</dt><dd>{state.drafts.length}</dd>
        <dt>People saved</dt><dd>{state.people.length}</dd>
        <dt>Tasks</dt><dd>{state.tasks.length}</dd>
      </dl>
      <button type="button" className="panel-reset" onClick={onReset}>Reset demo to start</button>
    </aside>
  );
}

export function Prototype({ route, preset, go, back, onJump, onReset }: {
  route: string;
  preset: State;
  go: (r: string) => void;
  back: () => void;
  onJump: (b: Board) => void;
  onReset: () => void;
}) {
  // Jumping from the screen list loads a new preset: remount the phone so screens start fresh.
  const epoch = useRef(0);
  const lastPreset = useRef(preset);
  if (lastPreset.current !== preset) { epoch.current += 1; lastPreset.current = preset; }

  return (
    <StoreProvider initial={preset} go={go} back={back}>
      <div className="proto">
        <nav className="screen-list" aria-label="Screens">
          {rows.filter((row) => row.boards.some((b) => b.kind !== 'brand')).map((row) => (
            <div key={row.title}>
              <h3>{row.title}</h3>
              {row.boards.filter((b) => b.kind !== 'brand').map((b) => (
                <button key={b.id} type="button" aria-current={b.route === route ? 'true' : undefined} onClick={() => onJump(b)}>
                  <span className="board-num">{b.num}</span>{b.title}
                </button>
              ))}
            </div>
          ))}
          <p className="panel-hint" style={{ marginTop: 12 }}>Picking a screen here loads its demo state. Tapping inside the phone keeps your state.</p>
        </nav>
        <Phone key={epoch.current} route={route} />
        <SimulatePanel route={route} onReset={onReset} />
      </div>
    </StoreProvider>
  );
}

export const firstBoardFor = (route: string) => boards.find((b) => b.route === route);
