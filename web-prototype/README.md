# Familiar — web prototype (design)

A clickable, browser-based prototype of the planned Familiar iPhone design: every screen, the full flow,
light and dark themes, and motion. It is a design reference for the SwiftUI app in [`../ios`](../ios), and
it follows the rules and data of [`../server`](../server). It runs on demo data and does not connect to the
server yet.

## Run it

```bash
cd web-prototype
npm install
npm run dev
```

Open http://localhost:5173.

- **Canvas** (`#/`) shows every screen in rows, with a Light/Dark toggle. Click a board to open it in the prototype.
- **Prototype** (`#/p/<route>`) is one phone you tap through. The left list jumps to any screen with its demo state.
  The right panel simulates the camera and band: Maria in view (face match sure), Ruth walks in, might be Leo
  (possible), someone not registered speaks. It also switches appearance and the Lock Screen setting.
- With **Say who it is out loud** on, the browser speaks the line: “This is Maria, your daughter. Last time…”

## The story

Eleanor lives with memory loss. She wears the Vexo band (the ears) and Meta glasses (the eyes). Her daughter
Maria visits. The glasses see Maria, the band hears her, and Familiar says who she is and what they last talked
about. Words from anyone who isn't registered are hidden and never kept.

## How the screens map to the backend

| Screen | Backend (`server/server.py` and friends) |
| --- | --- |
| 01b Connect to your server | Server address + 6-digit pairing code, sent as `Authorization: Bearer <code>`. No accounts; keys stay on the server. |
| 02 Pair band | The band's Bluetooth link (`ios/VexoBand`), "Use a pretend band", "Blink the band's light", team band 64. |
| 03 How Familiar listens | The recording rules: only registered people are kept; others are hidden and dropped; pictures are compared and thrown away; text only; Deepgram hears the room. |
| 04b Register my voice | `/voice`: the wearer reads for 12 s through the band; the server keeps a description of the voice (`me.json`), never sound. Then “Me” is whoever sounds like the wearer; without it, the first voice. Forget my voice → `{"type": "forget"}`. |
| 04 Choose a camera | Meta glasses (Wearables Device Access Toolkit, Developer Mode, link via Meta AI) or the iPhone camera. "Say who it is out loud". |
| 05/06 Now, Listen, live transcript | The Listen toggle streams audio. `transcript` lines labelled by speaker; unregistered lines arrive as `{"hidden": true}` and show as "not kept". |
| "In view" card, 08 Recognized | `/faces` → `{"people": [{name, relationship, match: "sure", recall}]}`. |
| 09 Possible match | `match: "possible"` — no name is said or shown until the wearer confirms. |
| 10 Register a person | `{"type": "enrol", name, relationship, consent: true, jpeg}` — refused without consent. Several photos work best. |
| 11 Conversation | What `save()` kept (text only, nothing if no registered person) and what Gemini wrote: `recall`, `follow_ups`. |
| 12a People & faces / 12b Profile | `{"type": "people"}` → name, relationship, photos, recall, facts, follow_ups, last_seen. Forget → `{"type": "forget"}`. |
| 14 Privacy · 15 Settings | What the server keeps, Lock Screen privacy, server/band/camera, appearance. |

Lock Screen notifications and the Dynamic Island are iPhone-side ideas; the current SwiftUI app doesn't have them yet.

## Where things live

| Path | What it holds |
| --- | --- |
| `src/data/demo.ts` | Demo people and conversation, shaped like the server's records |
| `src/state/store.tsx` | App state and actions (connect, pair, listen, face match, register, forget, …) |
| `src/state/theme.ts` | Light / dark / automatic, and the circular theme reveal |
| `src/screens/` | All screens, plus `registry.tsx` (routes, canvas rows, demo state per board) |
| `src/components/` | Icons, logo ("The Overlap"), shared UI |
| `src/styles/tokens.css` | Colours (ghost white, cool grey, freezing blue) for light and dark |
| `src/styles/app.css`, `motion.css` | Component styles and animations |
| `src/viewer/` | Canvas and prototype chrome (not part of the app) |

## Visual system

- **Colour**: ghost white surfaces, a cool grey scale and an icy freezing-blue accent, with matching light and dark themes.
- **Apple-style components**: inset grouped cards, capsule buttons, a floating glass tab bar, frosted Lock Screen notifications, a graphite "In view" card.
- **Logo**: "The Overlap" — two rings for two people; the filled lens is the moment you recognise someone. Wordmark in Quicksand.
- **Motion**: screen transitions, the Lock Screen nudge, live indicators, staggered reveals, toasts. Reduced under `prefers-reduced-motion`.
