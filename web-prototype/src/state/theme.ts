import { useEffect, useState } from 'react';
import { flushSync } from 'react-dom';
import type { Appearance } from './store';

export type Theme = 'light' | 'dark';

const darkQuery = () => (typeof window !== 'undefined' ? window.matchMedia('(prefers-color-scheme: dark)') : null);

/** Follows the device setting so "System" stays in sync live. */
export function useSystemTheme(): Theme {
  const [dark, setDark] = useState(() => darkQuery()?.matches ?? false);
  useEffect(() => {
    const q = darkQuery();
    if (!q) return;
    const on = (e: MediaQueryListEvent) => setDark(e.matches);
    q.addEventListener('change', on);
    return () => q.removeEventListener('change', on);
  }, []);
  return dark ? 'dark' : 'light';
}

export function useResolvedTheme(appearance: Appearance): Theme {
  const system = useSystemTheme();
  return appearance === 'system' ? system : appearance;
}

type DocWithVT = Document & {
  startViewTransition?: (cb: () => void) => { ready: Promise<void> };
};

/**
 * Runs `update` (which flips the theme) inside a View Transition, revealing the new theme
 * as a circle that grows from the tap point. Falls back to an instant switch where the
 * API is missing or the user prefers reduced motion.
 */
export function switchThemeSmoothly(update: () => void, origin?: { x: number; y: number }) {
  const doc = document as DocWithVT;
  const reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  if (!doc.startViewTransition || reduced) { update(); return; }

  const x = origin?.x ?? window.innerWidth / 2;
  const y = origin?.y ?? window.innerHeight / 2;
  const r = Math.hypot(Math.max(x, window.innerWidth - x), Math.max(y, window.innerHeight - y));

  const vt = doc.startViewTransition(() => { flushSync(update); });
  vt.ready.then(() => {
    document.documentElement.animate(
      { clipPath: [`circle(0px at ${x}px ${y}px)`, `circle(${r}px at ${x}px ${y}px)`] },
      { duration: 700, easing: 'cubic-bezier(0.65, 0, 0.35, 1)', pseudoElement: '::view-transition-new(root)' },
    );
  }).catch(() => { /* transition skipped — the theme still changed */ });
}
