# Familiar — web prototype (design)

A clickable, browser-based prototype of the planned Familiar iPhone design: every screen, the full flow,
light and dark themes, and motion. It is a design reference for the SwiftUI app in [`../ios`](../ios).
It runs on demo data and does not talk to [`../server`](../server) yet.

The screens are hooked up to real app state, so the prototype behaves like the app.

## Run it

```bash
cd web-prototype
npm install
npm run dev
```

Open http://localhost:5173.

- **Canvas** (`#/`) shows every screen laid out in rows like the design. Click any board to open it in the prototype.
- **Prototype** (`#/p/<route>`) shows one phone you can tap through:
  - the left list jumps to any screen and loads that screen's demo state;
  - the right panel can simulate a familiar, unsure or new voice, switch the Lock Screen setting, show the live state, and reset the demo.

## Where things live

| Path | What it holds |
| --- | --- |
| `src/styles/tokens.css` | Colours, radii, font: every design token |
| `src/styles/app.css` | Classes for the app screens (buttons, cards, chips, tab bar, sheet…) |
| `src/components/` | `Icon` (all icons), shared UI (`Avatar`, `TabBar`, `SetupHeader`, `BandArt`, toast, rows) |
| `src/screens/Account.tsx` | 01b Sign up (email, Sign up with Apple, sign-in toggle) · 01c Verify email (6-digit code) |
| `src/screens/Setup.tsx` | 01 Welcome · 02 Pair · 03 Privacy · 04 Teach your voice |
| `src/screens/Event.tsx` | 05/06/10b Now (ready, live, saved) · 07a/07b Lock Screen · 07c Dynamic Island |
| `src/screens/Recognition.tsx` | 08 Recognized · 09 Possible match · 10 New voice sheet |
| `src/screens/After.tsx` | 11 Recap · 12a People · 12b Profile |
| `src/screens/Privacy.tsx` | 13 Show someone · 14 Privacy tab |
| `src/screens/Hero.tsx` | 00 Pitch hero (1920 × 1080) |
| `src/screens/registry.tsx` | Routes, canvas rows, and each board's demo state |
| `src/state/store.tsx` | App state + every action (start session, save, forget, …) |
| `src/data/demo.ts` | People, drafts, follow-ups and the single demo timeline |
| `src/viewer/` | Canvas + prototype chrome (not part of the app) |

## Account flow

Welcome → **Get started** → Sign up → Verify email → Pair band.

- **Sign up with Apple** skips verification. The account arrives already verified.
- **Email sign-up** checks the name, a valid email and a password of 8+ characters, with a live strength meter.
- **Verify** accepts any 6 digits in the demo. It shows a success check, then moves on to pairing. Resend has a 30-second countdown.
- **Sign in** ("Already have an account?") switches the same screen to email and password only.

## Visual system v5: Ghost white · Cool grey · Freezing blue, light + dark

- **Palette by name** (`src/styles/tokens.css`): ghost white surfaces, a cool grey scale for backgrounds, text and the graphite Live Activity card, and an icy freezing-blue accent for buttons, links, tiles and highlights.
- **Light and dark**: every colour is a token. `:root` holds the light theme and `[data-theme='dark']` overrides it, so the phone, a canvas board or a whole page can switch on its own.
- **Settings → Appearance** (`src/screens/Settings.tsx`, open it from the profile button at the top right of every tab):
  - Light, Dark or Automatic, each with a mini phone preview.
  - Automatic follows the device setting live.
  - Switching plays a circular reveal from where you tapped (View Transitions API, in `src/state/theme.ts`). It's instant under reduced motion or in browsers without the API.
- **Viewer**: the prototype panel has an Appearance switch, and the canvas has a Light/Dark toggle. Boards 15, 15b and 06d always show their own theme.

## Visual system v4: Aurora accent on the Apple theme (superseded by v5 colours)

- **Accent**: a blue → indigo → violet gradient (`--accent-grad`) with a soft glow, used on primary buttons, the app icon, tiles, progress bars and OTP focus. Text links use an indigo-leaning blue (`--blue #3B4FE4`, 5.6:1 on white).
- **Backgrounds**: cool greys with a faint aurora wash (blue top-left, violet top-right, cyan bottom).
- **Live Activity cards**: deep indigo-graphite with blue and violet glows. Green stays reserved for live and success.

## Visual system v3: Apple theme, readability, motion

- **Logo mark — "The Overlap"** (`src/components/Logo.tsx`): two rings for two people, with the shared lens filled in for the moment of recognition. It is used as the app icon, on the Lock Screen notification, in the Dynamic Island, on the pitch hero, in the viewer and as the favicon. Board 00b on the canvas shows how it is built, its sizes, and two alternates (Hello, Ripple).
- **Wordmark**: the logo uses Quicksand (rounded, friendly, uppercase, 0.2em tracking) through `.wordmark` and `--font-wordmark`. Body text stays SF Pro.
- **Theme** (`src/styles/tokens.css`): cool light greys on an iOS grouped background (`#F2F3F7`), iOS system colours (blue `#007AFF`, green `#34C759`, orange, red) and the SF Pro font stack (Inter on non-Apple machines).
- **iOS components** (`src/styles/app.css`):
  - Inset grouped cards with hairline separators.
  - Capsule buttons: blue filled, plus tinted-grey "gray" buttons.
  - Filled input and search fields, an iOS segmented control, and an iOS switch for consent.
  - Contacts-style grey monogram avatars, with green ones for people saved tonight.
  - Settings-style blue icon tiles.
- **Glass and Live Activity look**:
  - The tab bar floats as a frosted glass capsule.
  - Sheets are floating rounded glass panels.
  - Toasts are a dark glass HUD.
  - "Talking now" cards are graphite Live Activities with a green live accent.
  - The Lock Screen has a cool wallpaper with frosted notifications.
- **Readability**: label colours follow Apple's label hierarchy, with secondary text at about 7:1 contrast on white.
- **Motion** (`src/styles/motion.css`, transitions in `src/viewer/Prototype.tsx`):
  - Screen transitions: slide for drill-in and back, fade for tab switches, rise and sink for the "Show someone" modal, zoom for the Lock Screen.
  - Wrist-tap moment: the notification springs in, the phone buzzes, and rings ripple out.
  - Talking now: animated speaking bars, pulsing avatar rings, a gradient card reveal with a drifting bloom.
  - Micro-interactions: staggered list entrances, a spring toast with a drawn check, a sliding segmented-control thumb, a crossfading Lock Screen preview, buttons that press in, a bouncing tab icon, and a breathing "Ready" icon.
  - Everything is reduced to near-instant under `prefers-reduced-motion`.

## Changes from the design (from the review)

1. **One timeline.** The session starts at 6:30 PM. An unnamed voice is heard at 6:48, Priya at 6:52, the wrist tap for Maya comes at 6:56 (26 min in), Priya is saved at 7:01, and the session ends at 7:42 (1 h 12 min). Every screen reads its times from `src/data/demo.ts`.
2. **Voice counts add up.** Now — live shows "2 new voices". After Priya is saved it shows 1, which matches the unnamed draft left on Recap and People.
3. **Confidence everywhere.** "Voice match: likely" now also appears on Now — live, on the detailed Lock Screen and on the expanded Dynamic Island. An unsure match always shows the private Lock Screen card, whatever the setting.
4. **Consent before saving.** The New voice sheet has a "They're OK with being saved" checkbox, and Save stays disabled until it's ticked. "Please don't save me" on screen 13 discards the latest unsaved voice.
5. **Clearer labels.** "Use name" is now "Name session" (it shows "Named ✓" once tapped). Teach your voice moves from "Next sample" to "Finish setup" across 3 sentences.
6. **Confirm before deleting.** Forget Maya and Forget everyone… both ask for confirmation first.

To undo any of these, look for the matching code in the files above. Each one is a small, local edit.
