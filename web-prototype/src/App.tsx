import { useCallback, useEffect, useState } from 'react';
import { type State, baseState } from './state/store';
import { type Board, routes } from './screens/registry';
import { Canvas } from './viewer/Canvas';
import { Prototype, firstBoardFor } from './viewer/Prototype';
import { LogoGlyph } from './components/Logo';

// Hash routes: "#/" = canvas of every screen, "#/p/<route>" = clickable prototype.
function parseHash(): { mode: 'canvas' | 'proto'; route: string } {
  const m = window.location.hash.match(/^#\/p\/([\w-]+)/);
  if (m && routes[m[1]]) return { mode: 'proto', route: m[1] };
  return { mode: 'canvas', route: 'welcome' };
}

export default function App() {
  const [loc, setLoc] = useState(parseHash);
  const [preset, setPreset] = useState<State>(() => firstBoardFor(parseHash().route)?.preset ?? baseState);

  useEffect(() => {
    const onHash = () => setLoc(parseHash());
    window.addEventListener('hashchange', onHash);
    return () => window.removeEventListener('hashchange', onHash);
  }, []);

  const go = useCallback((route: string) => { window.location.hash = `#/p/${route}`; }, []);
  const back = useCallback(() => window.history.back(), []);
  const open = useCallback((b: Board) => { setPreset({ ...b.preset }); go(b.route); }, [go]);
  const reset = useCallback(() => { setPreset({ ...baseState }); go('welcome'); }, [go]);

  return (
    <div className="viewer">
      <header className="topbar">
        <div className="topbar-brand">
          <span className="topbar-mark" aria-hidden="true">
            <LogoGlyph size={17} stroke={2.2} />
          </span>
          <span className="wordmark" style={{ fontSize: 14 }}>Familiar</span>
          <span className="topbar-sub">App Screens</span>
        </div>
        <div className="topbar-tabs" role="tablist">
          <button type="button" role="tab" aria-selected={loc.mode === 'canvas'} onClick={() => { window.location.hash = '#/'; }}>Canvas</button>
          <button type="button" role="tab" aria-selected={loc.mode === 'proto'} onClick={() => go(loc.mode === 'proto' ? loc.route : 'welcome')}>Prototype</button>
        </div>
      </header>
      {loc.mode === 'canvas'
        ? <Canvas onOpen={open} />
        : <Prototype route={loc.route} preset={preset} go={go} back={back} onJump={open} onReset={reset} />}
    </div>
  );
}
