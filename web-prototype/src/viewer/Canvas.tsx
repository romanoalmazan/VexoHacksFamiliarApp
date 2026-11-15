import { useEffect, useState } from 'react';
import { StoreProvider } from '../state/store';
import { type Board, routes, rows } from '../screens/registry';
import { switchThemeSmoothly } from '../state/theme';

const ZOOMS = [0.25, 0.35, 0.5, 0.65, 0.8, 1];

function BoardView({ board, onOpen, theme }: { board: Board; onOpen: (b: Board) => void; theme: 'light' | 'dark' }) {
  const Screen = routes[board.route];
  return (
    <figure className="board" style={{ width: board.w }}>
      <figcaption className="board-title"><span className="board-num">{board.num}</span>{board.title}</figcaption>
      <div
        role="link"
        tabIndex={0}
        className="board-frame"
        style={{ width: board.w, height: board.h }}
        onClick={() => onOpen(board)}
        onKeyDown={(e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); onOpen(board); } }}
        aria-label={`Open ${board.title} in the prototype`}
      >
        <div className="inert" aria-hidden="true" data-theme={board.theme ?? theme}>
          <StoreProvider initial={board.preset} interactive={false}><Screen /></StoreProvider>
        </div>
        <span className="board-hover">Open in prototype →</span>
      </div>
    </figure>
  );
}

export function Canvas({ onOpen }: { onOpen: (b: Board) => void }) {
  const [zoom, setZoom] = useState(() => {
    try { return Number(localStorage.getItem('familiar.zoom')) || 0.5; } catch { return 0.5; }
  });
  useEffect(() => { try { localStorage.setItem('familiar.zoom', String(zoom)); } catch { /* ignore */ } }, [zoom]);
  const [theme, setTheme] = useState<'light' | 'dark'>(() => {
    try { return localStorage.getItem('familiar.canvasTheme') === 'dark' ? 'dark' : 'light'; } catch { return 'light'; }
  });
  useEffect(() => { try { localStorage.setItem('familiar.canvasTheme', theme); } catch { /* ignore */ } }, [theme]);

  return (
    <div className="canvas-wrap">
      <div className="zoom-bar" role="group" aria-label="Zoom">
        {ZOOMS.map((z) => (
          <button key={z} type="button" aria-pressed={zoom === z} onClick={() => setZoom(z)}>{Math.round(z * 100)}%</button>
        ))}
        <span className="zoom-sep" aria-hidden="true" />
        {(['light', 'dark'] as const).map((m) => (
          <button key={m} type="button" aria-pressed={theme === m} onClick={(e) => switchThemeSmoothly(() => setTheme(m), { x: e.clientX, y: e.clientY })} style={{ textTransform: 'capitalize' }}>{m}</button>
        ))}
      </div>
      <div className="canvas" style={{ zoom }}>
        {rows.map((row) => (
          <section key={row.title} className="canvas-row">
            <h2 className="canvas-row-title">{row.title}</h2>
            <div className="canvas-boards">
              {row.boards.map((b) => <BoardView key={b.id} board={b} onOpen={onOpen} theme={theme} />)}
              {row.title.startsWith('Setup') && (
                <aside className="demo-note">
                  <strong>Demo path</strong> — press <em>Open in prototype</em> on 05 · Now — ready.
                  <ol>
                    <li>Listen → the Lock Screen shows someone you know is here.</li>
                    <li>Tap it → “This is Maria, your daughter” (spoken aloud).</li>
                    <li>‹ Now → the live transcript hides anyone not registered.</li>
                    <li>Stop listening → what to remember → Maria’s profile.</li>
                  </ol>
                  Consent beat: People → Register a person (name, relationship, photos, their OK).
                </aside>
              )}
            </div>
          </section>
        ))}
      </div>
    </div>
  );
}
