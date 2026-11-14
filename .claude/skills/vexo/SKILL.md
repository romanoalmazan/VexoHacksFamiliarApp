---
name: vexo
description: Build with the Vexo Open band (wristband with motion sensor, microphone, colour LED) using the vendored vexo-open-kit. Use for any task that connects to, reads from, or controls the band: motion/gestures/taps/steps, LED, microphone/speech-to-text (Deepgram), AI on band input (OpenAI), the pretend band (--sim), the dashboard, or raw Bluetooth/USB code.
---

# Vexo Open band

The kit lives at `vexo-open-kit/` inside this project (cloned from
https://github.com/VexoAI-Org/vexo-open-kit, git-ignored). **Before writing band code, read
`vexo-open-kit/AGENTS.md` in full** — it is the authoritative guide. Open the other docs only
when it points to them (`docs/api.md` for every call, `examples/`, `projects/`).

## Layout (required — samples break otherwise)

```
familiar/                 our code goes here (app.py, index.html, ...)
  vexo-open-kit/          the kit, unchanged; never edit or put our files inside it
  .env                    team keys; git-ignored; never committed
```

- Python import: `sys.path.insert(0, str(Path(__file__).resolve().parent / "vexo-open-kit" / "python"))` then `from vexo_open.sync import Band` (async: `from vexo_open import Band`). Not pip-installed.
- Speech/AI helpers: add `vexo-open-kit/examples/python` to `sys.path`, then `import speech, ai`.
- Web: `import { Band } from './vexo-open-kit/js/src/index.js'`; serve from this folder with `python3 -m http.server 8000 --bind 127.0.0.1` (always `--bind 127.0.0.1`); Chrome/Edge only; connect inside a click handler.
- Do not edit `js/`, `python/`, `contract/`, `dashboard/`, `scripts/` in the kit. Report suspected kit bugs instead.

## Band number — hard rules

- **Ask the team for their band number before writing or running anything that connects.** Never guess, never use 42/7 or any number from examples. Band N is `Vexo-HACK-NN`.
- Store it once (one constant, e.g. `BAND = 17`) and use it everywhere. Check project memory for a recorded band number first.
- Never scan for, connect to, or command any other band; never loop over numbers; never use the unfiltered `Band.connect(None, transport="serial")` without checking `band.number`. Never renumber a band.
- Band not found → tell them to double-tap it (blinks blue, discoverable 60 s) and close any other connection (dashboard tab, other program). Use `--sim` meanwhile.

## Rules that bite

1. Nothing streams until `band.configure(...)` (`events=True`, `motion=50`, `activity=True`, `audio=True`, `mic_level=True`, `battery=True`, `link=True`).
2. Link close resets the band (LED off, streams off). Reconfigure on every connect, or use `auto_reconnect=True`.
3. **Mic on ⇒ LED locked** (solid blue; `set_led` fails `denied`). Listen first, then set light.
4. One Bluetooth connection at a time — close the dashboard before running a program.
5. Audio events are raw Opus packets; use `speech.listen(band, seconds)` for text or `PcmDecoder` (`pip install av`) for samples.
6. Call `speech.listen` from the main program, never inside a handler. Keep handlers short.
7. Accel range defaults to ±2 g — call `band.set_motion(accel_range=8)` for shakes/punches.
8. Band storage is public and slow (10 writes/s) — never store secrets or names.
9. iOS browsers, Safari and Firefox have no Web Bluetooth. Fallback: USB cable, `transport="serial"`.

## Pretend band

`Band.connect(BAND, transport="sim")` (JS: `{ transport: 'sim' }`). Develop and test against it first, then remove the transport option for the real band. For deterministic tests use `SimTransport(BAND, auto_tap=False)` and drive it via `band.transport.tap(...)`, `play_motion(...)`, `set_loudness(...)`, etc. Its default data is calm (no shakes/falls), and its audio is silence unless given `audio_packets=`.

## Keys (Deepgram + OpenAI)

- `DEEPGRAM_API_KEY`, `OPENAI_API_KEY` come from env vars or a git-ignored `.env` the team creates themselves (`cp vexo-open-kit/env.example .env`).
- Never ask for a key, never write one to a file, never print/log it, never put it in a web page. OpenAI is Python-only.
- Check keys: `python3 vexo-open-kit/examples/python/check_keys.py`.
- Use the kit helpers (`speech.py`, `ai.py`: `ai.ask`, `ai.choose` + `ai.tool`, `ai.extract`); don't write new clients. Let the model choose among predefined actions; never execute model output.
- Mic sends sound to Deepgram: keep the on-screen/printed notice and `mip_opt_out=true`.

## Starting points

- `vexo-open-kit/projects/` (reaction game, band leash, clap lights, step diary, fall alarm, gesture trainer). Check here first if the idea is close to one; thresholds need tuning on a real band.
- `vexo-open-kit/examples/python/ask_the_band.py`, `voice_commands.py`, `meeting_notes.py` are the voice+AI patterns. Copy one into this folder and keep the `sys.path` line.
- Smoke test: `python3 vexo-open-kit/examples/python/led.py --sim`.
- Dashboard: `http://localhost:8000/vexo-open-kit/dashboard/?band=<N>`.
