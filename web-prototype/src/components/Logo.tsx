import type { CSSProperties } from 'react';

/*
 * Familiar logo.
 *
 * "Overlap" (primary) — two people drawn as two rings; the lens where they overlap is filled.
 * That shared lens is the moment of recognition: the part of a conversation you both hold.
 * It also reads as a calm, half-closed eye — "I know you".
 *
 * Alternates kept for comparison on the brand board:
 *  - "Hello"  — a soft speech bubble with a smile.
 *  - "Ripple" — the wrist tap: a dot with two rings spreading out.
 */
export type LogoVariant = 'overlap' | 'hello' | 'ripple';

export function LogoGlyph({
  variant = 'overlap', size = 24, stroke = 1.9, style, title,
}: {
  variant?: LogoVariant;
  size?: number;
  stroke?: number;
  style?: CSSProperties;
  title?: string;
}) {
  const common = {
    width: size, height: size, viewBox: '0 0 24 24', fill: 'none', stroke: 'currentColor',
    strokeWidth: stroke, strokeLinecap: 'round' as const, strokeLinejoin: 'round' as const,
    role: title ? 'img' : undefined, 'aria-hidden': title ? undefined : true, 'aria-label': title,
    style: { flexShrink: 0, display: 'block', ...style },
  };

  if (variant === 'hello') {
    return (
      <svg {...common}>
        <path d="M6 5h12a3.2 3.2 0 0 1 3.2 3.2v6.2a3.2 3.2 0 0 1-3.2 3.2h-5.4L8 20.6v-3H6a3.2 3.2 0 0 1-3.2-3.2V8.2A3.2 3.2 0 0 1 6 5z" />
        <path d="M8.6 11.2c.9 1.7 2.1 2.5 3.4 2.5s2.5-.8 3.4-2.5" />
      </svg>
    );
  }

  if (variant === 'ripple') {
    return (
      <svg {...common}>
        <circle cx="7.5" cy="16.5" r="2.3" fill="currentColor" stroke="none" />
        <path d="M7.5 10.2a6.3 6.3 0 0 1 6.3 6.3" />
        <path d="M7.5 4.6a11.9 11.9 0 0 1 11.9 11.9" opacity=".7" />
      </svg>
    );
  }

  // overlap — rings centred at (8.8, 12) and (15.2, 12), r = 6.2; they cross at x = 12, y = 12 ± 5.31
  return (
    <svg {...common}>
      <circle cx="8.8" cy="12" r="6.2" opacity=".92" />
      <circle cx="15.2" cy="12" r="6.2" opacity=".92" />
      <path d="M12 6.69A6.2 6.2 0 0 1 12 17.31A6.2 6.2 0 0 1 12 6.69Z" fill="currentColor" stroke="none" />
    </svg>
  );
}

/** App-icon tile: the glyph in white on the accent gradient, with iOS-style continuous corners. */
export function LogoTile({ size = 36, variant = 'overlap', className = '', style }: {
  size?: number; variant?: LogoVariant; className?: string; style?: CSSProperties;
}) {
  return (
    <span
      className={`logo-tile ${className}`}
      aria-hidden="true"
      style={{ width: size, height: size, borderRadius: size * 0.28, ...style }}
    >
      <LogoGlyph variant={variant} size={size * 0.62} stroke={size < 28 ? 2.4 : 1.9} />
    </span>
  );
}
