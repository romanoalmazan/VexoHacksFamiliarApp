# Familiar: Rough Plan

> Living document. Everything here can change. Claude updates it as we build: phases get
> checked off, decisions get logged, and pivots are recorded in the changelog.
>
> **Last updated:** 2026-11-14 (2:30 PT) · **Current phase:** 5 (the whole loop runs on real
> hardware; voice registration and the registered-only rule are untested on real speech;
> the app still has test screens, not the design) · **Hard stop:** submit before 6:00 PM PT today

---

## The idea

A native iOS app that pairs **two wearables**: the Vexo Open band (band **64**,
`Vexo-HACK-64`) and Meta glasses. The band's microphone stays on and hears the
conversation. The glasses' camera sees who the wearer is looking at. The face says **who**
the person is, the band's audio says **what they said**, and each person gets a
**profile**: who they are, how they're related to the wearer, and what they last talked
about. The next time that person walks up, the wearer is told who it is.

**Who it's for** (pivoted 2026-11-14, see decision 11)
- **People with dementia or memory loss, and their families.** "This is Maria, your
  daughter. Last week she told you about her grandson's graduation." Family members enrol
  themselves, so the people being recognised are the ones who agreed to it.
- Networking and "anyone who forgets names" are no longer the pitch. The same build would
  serve them, but the demo and the design choices follow the dementia use.

## Core loop

```
band mic ──BLE──▶ iPhone app ──▶ server ──▶ Deepgram (speech → text + speaker separation)
 (Opus audio)      ▲      │         │        (all API keys live here, never in the app)
                   │      │         ├──▶ Gemini (read transcript → update the profile)
glasses camera ────┘      │         │
 (frames, ~1 per second)  └────────▶├──▶ face match (which enrolled person is in view?)
                                    ▼
                               profiles DB ──▶ app: people list, profile cards, "who is this"
                                           └─▶ spoken line in the glasses' speakers

Face = who it is. Band audio = what was said. The band still shows nothing (decision 8).
Without glasses, the app still works: the user names the voice, or the name comes from the transcript.
```

---

## Phases

Build in thin vertical slices so no single piece blocks everything else. Tracks A and B
can run in parallel. They meet at the audio stream from the phone to the backend.

### Phase 0: Setup
- [x] Clone vexo-open-kit into the project (`vexo-open-kit/`, git-ignored)
- [x] Project skill for building with the band (`.claude/skills/vexo/SKILL.md`)
- [x] Band number recorded: **64**
- [x] Pretend band works (`python3 vexo-open-kit/examples/python/led.py --sim`)
- [ ] Real band 64 connects in the dashboard (`http://localhost:8000/vexo-open-kit/dashboard/?band=64`)
- [ ] `python3 -m pip install bleak`
- [ ] Team keys in `.env` (Deepgram + OpenAI; `cp vexo-open-kit/env.example .env`), then
      `python3 vexo-open-kit/examples/python/check_keys.py`
- [ ] Get a Gemini API key (organisers only provide Deepgram + OpenAI). Server `.env` only.
- [ ] Read the hackathon slides for the deadline, judging criteria, and any required tech

### Phase 1: Prove the audio [Track B, a teammate is testing the mic on the web]
Riskiest assumption first: **can a wrist mic pick up and separate the *other* person's voice?**
- [ ] Band 64 → Deepgram live with `diarize=true` → transcript labelled by speaker
- [ ] Test with 2–3 people at normal conversation distance (~1 m), in quiet and noisy rooms
- [ ] **Exit:** speaker labels are mostly right and the other person's words are mostly captured

### Phase 2: Profiles from text [Track B]
- [x] After each conversation, Gemini reads the name-labelled transcript and returns, per
      named person, one "Last time, …" sentence, lasting facts and things to ask next time
      (`server/profiles.py`; picks the newest Gemini Flash model the key allows, or `GEMINI_MODEL`)
- [x] Merged into a stored profile (`server/profiles.json`, text only; new facts added, old kept)
- [x] The app shows it on the person's card and in People, and the spoken line includes it
- [x] **Exit (passed 2:05 PM):** after one real conversation, a readable profile exists
      for the person. Keys are in `.env`; Gemini model in use: `gemini-4-argon`.

### Phase 3: Recognise returning people [Track B] (changed by the pivot, decision 12)
- [x] The wearer registers their own voice once (Register my voice: 12 seconds of
      reading into the band). In a conversation, the voice that sounds like it is "Me",
      whoever speaks first (`server/voice.py`). With no voice registered, the first voice
      is "Me". **Checked with computer voices only; thresholds are a first guess.**
- [ ] Recognise a returning person **by face** (Phase G). Voice fingerprints are dropped
      for the hackathon.
- [x] Link face to words (`server/who.py`): the first voice is "Me"; another voice that
      speaks while exactly one enrolled face is surely in view gets that person's name,
      for everything it said. Listen now starts the camera too, the transcript shows
      names, and saved conversations carry them. Worked in a real three-person test; names flipped
      between two people, fixed since (votes weighted by words, a name changes only on a clear lead).
- [ ] No glasses, or no face in view: name the voice from the transcript ("Hi, I'm Sarah")
      or let the user pick the person in the app
- [ ] **Exit:** the same person is recognised in a new session with no manual step

### Phase G: Glasses + faces [new track, one person, time-boxed]
Build the face part against the **iPhone camera first**, then swap the glasses in as the
camera. That way the glasses can fail without taking the face feature down with them.
- [x] Server: a JPEG in → find the face → compare with enrolled faces → the person,
      "possible", or unknown (`server/faces.py`, OpenCV; second connection at `/faces`)
- [x] App: People & faces screen. Enrol a person (name, relationship, face in view or a
      photo), see who is in view, swipe to forget. One picture a second goes to the server.
- [ ] **Gate, 1:15 PM:** enrolled face recognised from the iPhone camera **on a real
      iPhone** (built; checked only in the Simulator with still pictures). If it fails,
      drop faces and ship the voice-only app with the dementia pitch.
- [x] Glasses: Meta's toolkit 1.0.1 is in the app as a second camera (`GlassesCamera.swift`).
      Checked with the toolkit's pretend glasses: pictures reach the server and the
      enrolled face is recognised.
- [x] **Gate, 3:00 PM (passed 1:45 PM):** pictures arrive from the **real** glasses (README has the four
      steps). If not, the demo uses the phone camera and the pitch says the glasses are next.
- [ ] Spoken line ("This is Maria, your daughter"): built with the iPhone's own voice.
      **Unheard so far.** Check it plays in the glasses' speakers. ElevenLabs voice: not started.
- [x] Faces run during a conversation, and the band's words are attached to the person
      in view (Phase 3).

### Phase 4: iOS app [Track A, can start now]
- [x] Swift + CoreBluetooth (works on the real band 64 from an iPhone): scan for service `254f0001-df82-4a9c-a2b5-563a0f6b2021`,
      connect only to band 64, check the band number after connecting
- [x] Implement the band's commands we need in Swift (start audio, events, battery);
      unit-test against `vexo-open-kit/contract/test-vectors.json`
- [ ] Stream audio packets to the backend; reconnect and restart streams after a drop
- [ ] Screens: people list · profile card · live "who's talking". Build them to match the
      [UI design](https://claude.ai/artifact/B49Q5gvrt6Kkxk8MbH7jQ3) (decision 10).
- [ ] (declared in the app, untested) Background mode (`bluetooth-central`) so it keeps listening with the screen locked

### Phase 5: The recall moment + demo
- [ ] Live: known person in view → card on the phone and a spoken line within a few seconds
- [ ] Double-tap the band → "who is this?" (gesture events still work while the mic is on)
- [ ] Demo script (a family member walks up, the wearer is told who it is and what they
      last talked about), seeded profiles, pitch
- [ ] **4:45 PM: stop adding features.** Record the video, finish the README, submit on
      Devpost before 6:00 PM. Be ready to demo in person.

### What has to work by 6 PM, in order
1. Real Deepgram key, phone → server → speaker-labelled text (built, untested on the real service)
2. Gemini turns a conversation into a profile (Phase 2, not started)
3. People list + profile card + the "who is this" card in the app
4. Face recognition from the iPhone camera (Phase G, first gate)
5. Glasses as the camera, spoken line in the glasses

Items 1–3 are the product. Items 4–5 make it better. Nobody leaves 1–3 to work on 4–5.

---

## Decisions log

| # | Decision | Status | Why / notes |
|---|---|---|---|
| 1 | Native iOS app connects to the band | **Decided** | iPhone browsers have no Web Bluetooth; a native app uses CoreBluetooth. The kit has no Swift library, so we implement the Bluetooth contract ourselves. |
| 2 | Deepgram for transcription | **Decided** | Hackathon gives each team a key. The band's Opus audio goes to Deepgram as-is, with nothing to decode. Kit helper: `examples/python/speech.py`. |
| 3 | Deepgram separates speakers (`diarize=true`) | **Decided** (2026-11-14) | Replaces the earlier idea of Gemini for voice separation. Live, in the same call as transcription. Labels are per conversation only (see #9). |
| 4 | All API keys live on the server, never in the iOS app | **Decided** (2026-11-14) | Keys inside an app can be pulled out of the app file. The app talks only to our server. |
| 5 | Server language | Suggested: Python | Reuses the kit's `speech.py` helper and Python voice-ID libraries. |
| 6 | Database | Open | SQLite (fastest for a hackathon) vs Supabase (hosted, real-time sync to the app). |
| 7 | Gemini reads transcripts and builds/updates profiles | **Decided** (2026-11-14) | Server-side. Needs our own Gemini key. The kit's `ai.py` is OpenAI-only, so we write a small Gemini client. |
| 8 | The band shows nothing; all output is through the app | **Decided** (2026-11-14) | The LED is locked blue while the mic is on, and the band has no screen, speaker or vibration. Cards, notifications and any audio come from the iPhone. |
| 9 | Recognising the same person across conversations | **Replaced by #12** (2026-11-14) | Deepgram's speaker labels reset every session. Was going to be a stored voice fingerprint. Now the face does this job. |
| 10 | The app UI follows the design artifact | **Decided** (2026-11-14) | [Design](https://claude.ai/artifact/B49Q5gvrt6Kkxk8MbH7jQ3): Hero, Pair, Privacy, Voice setup, Now (ready/live), Lock Screen + Dynamic Island, Recognized / Possible match / New voice, Recap, People + Profile, Show someone, Privacy tab. |
| 11 | The product is for people with dementia and their families | **Decided** (2026-11-14) | Sharper pitch than "anyone who forgets names". It also fixes the consent problem: family members enrol themselves. The design artifact (decision 10) still applies, with wording changed to fit. |
| 12 | Meta glasses join the band in the same app; the face identifies the person | **Decided** (2026-11-14), time-boxed | A face is a far stronger identity signal than a voice picked up at the wrist, and it works before the person speaks. Band = ears, glasses = eyes. Gates in Phase G decide whether the glasses make the demo. |
| 13 | Face matching runs on the server, and the iPhone camera is the first camera | **Decided** (2026-11-14, built) | Same server and pairing as the audio. The phone camera gives a working face feature within the hour and a fallback if the glasses don't connect. |
| 14 | Only enrolled faces are matched; nothing is kept for strangers | **Decided** (2026-11-14, built) | Frames are compared and thrown away. A new person is saved only when the user or a family member adds them. See S5. |
| 15 | Only registered people are recorded | **Decided** (2026-11-14, built) | The user's call, for the dementia use. A person is registered in the app (name, relationship, a confirmed yes from them or family, photos). Only the wearer's words and recognised registered people's words are shown, saved or sent to Gemini. Anyone else's are withheld and dropped; a conversation with no registered person leaves nothing. Deepgram still hears the room to make the text. |
| 16 | The wearer registers their own voice | **Decided** (2026-11-14, built) | Replaces "the first voice is the wearer". A voice model on the server (sherpa-onnx, WeSpeaker CAM++) compares each voice in a conversation with the registered one. Brings back a voice fingerprint, but only for the wearer, who registers themselves. |

---

## Suggestions

**S6. Keep each device doing the one thing it's best at.** Judges will ask why the band is
needed when the glasses have microphones. Answer: the band listens all day on a small
battery, while the glasses' camera drains theirs fast, and the glasses' microphone access
in Meta's toolkit is experimental. So the band is always on, and the glasses' camera only
needs to run while the band hears someone other than the wearer. (Build the "wake the
camera on a voice" part only if there's time. It's a strong line in the pitch either way.)

**S7. Don't blend face and voice scores.** A weighted mix of two confidence numbers is
hard to tune and hard to explain. Use the rule in Phase 3: the face names the person, the
audio supplies the words. If two enrolled faces are in view, show both cards and attach
the words to neither.

**S8. Say it out loud.** A person with dementia shouldn't have to look at a phone. The
main output is one short spoken sentence in the glasses' speakers, in a calm voice. This
could use ElevenLabs (there's a sponsor track for it). The phone card is the backup, and
is what the audience sees in the demo.

**S9. A wrong name is worse than no name.** Telling someone with dementia that a stranger
is their daughter does harm. Set the face match strict, and when unsure say nothing or
show "Possible match" on the phone only (the design already has that screen).

**S10. Add a caregiver view if time allows.** A family member sets up the people, and
sees a recap of the day's visits. This is the "Show someone" and "Recap" screens in the
design, re-aimed at the family.

**S1. Split "who is speaking" into two jobs.** *Adopted for the first and third points
(decisions 3, 7). The second point is still open (decision 9).*
- *Within one conversation* ("speaker 0 vs speaker 1"): Deepgram does this itself with
  `diarize=true`. It's cheap and live, and needs no Gemini call.
- *Across conversations* ("this is the same Sarah from Tuesday"): neither Deepgram's
  labels nor an LLM remembers voices between sessions. This needs a stored **voice
  fingerprint** (speaker embedding) per person and a similarity match. Options: pyannote
  or SpeechBrain on the backend, or an on-device SDK. To decide in Phase 3.
- *Gemini's best use:* reading transcripts and building or updating profiles (facts,
  topics, relationships, follow-ups), where an LLM is strongest.

**S2. Enrol the wearer first.** The wearer's voice is the loudest on the wrist and is in
every conversation. Recognise it as "Me" and exclude it from profiles.

**S3. Test the mic early (Phase 1 before heavy iOS work).** The kit's own notes say speech
works best "within arm's length of the band." Networking happens at about 1 m. If the
other person's voice is too faint, we change the plan early. Options then: a gain setting
on the band, or the phone's own mic as a second source.

**S4. The band can't give feedback while listening.** *Adopted (decision 8).* While the mic is on, the LED is
locked solid blue. The band has no screen, speaker or vibration. All output goes to the
phone (notification, card) or to earbuds (spoken whisper: "That's Maria").

**S5. Consent and privacy as a feature, not an afterthought.** A saved voice fingerprint
counts as biometric data in many places, and the kit's safety rules say not to save
recordings of people who haven't agreed. Suggested defaults: store text summaries, not
raw audio. Only keep a full profile for someone after they've agreed, or after the user
confirms. Keep the blue light visible. Judges will likely ask about this.

---

## Constraints from the band (facts from the kit)

- Audio: Opus, 16 kHz mono, 20 ms packets (~24 kbit/s) over Bluetooth.
- One Bluetooth connection at a time. Close the dashboard before running the app.
- Link drop → the band turns everything off. The app must turn the mic back on after
  reconnecting. The band stays findable for 2 min after a drop. Otherwise it needs a
  double-tap (60 s window).
- Never connect to any band but 64 (other teams are in the room). The band number is also
  in the advertising packet's manufacturer data, so the app can filter on it.
- No heart rate, screen, speaker or vibration on the band.
- Band battery life with the mic always on: **unknown, measure it.**

## Constraints from the glasses (from Meta's docs and coverage, not yet tested by us)

- Access is through Meta's Wearables Device Access Toolkit, a Swift package
  (`facebook/meta-wearables-dat-ios`). It gives camera frames and photos.
- An unpublished app needs **Developer Mode** turned on in the Meta AI app (Settings → App
  Info → tap the version number five times), and internet access to register.
- Works with Ray-Ban Meta (Gen 1 and 2), Oakley Meta and Ray-Ban Display, on recent
  glasses software. The glasses must already be paired in the Meta AI app on the same phone.
- The toolkit has a pretend device (Mock Device Kit), so the code can be written before
  the glasses are in hand.
- Microphone audio through the toolkit is marked experimental. We don't use it; the band
  is the microphone.
- The iPhone holds two Bluetooth devices at once (band + glasses). **Untested together.**
- Camera battery life while streaming: **unknown, measure it.**

## Hackathon facts (from the slides)

- Hacking closes **6:00 PM PT, 2026-11-14**. Judging 6:30, finals 8:00–9:00.
- Submit: public GitHub repo + README, video demo, Devpost. Working demo in person.
- The project must be hardware-related. Vexo bands and Marv Labs cameras are provided.
  Meta glasses are not provided (they're the third-place prize).
- Sponsor tracks that fit: **Best use of Gemini 4** (profiles), **Best ElevenLabs
  project** (the spoken line). Meet each track's own requirements to enter it.

## Open questions
- We have Meta glasses (confirmed 2026-11-14). Which model, and is Developer Mode on?
- Does the iPhone keep the band and the glasses connected at the same time?
- Who takes Phase G? It must be someone who isn't needed for items 1–3.
- Who on the team takes Track A (iOS) vs Track B (pipeline)?
- How does the demo show "recognised on a different day"? (Pre-seeded profiles?)

---

## Changelog
- **2026-11-14:** Plan created. Idea, phases 0–5, decisions 1–7, suggestions S1–S5.
  Phase 0 mostly done (kit, skill, band 64, pretend-band test).
- **2026-11-14:** Decided: Deepgram separates speakers; Gemini reads transcripts and
  builds profiles; all API keys stay on the server; the band shows nothing and all
  output goes through the app. Added decision 9 (cross-session voice recognition, open).
- **2026-11-14:** Decision 10: the app UI is built from the design artifact (18 screens).
- **2026-11-14:** Order changed: a teammate tests the mic on the web (Phase 1), so the
  iOS app started now. Built `ios/`: the `VexoBand` Swift package (band protocol, checked
  against the kit's test vectors; Bluetooth client locked to band 64; pretend band) and
  the Familiar app with a band screen (connect, battery, signal, taps, mic test).
  Runs in the Simulator on the pretend band. Next: try it on an iPhone with band 64.
- **2026-11-14:** Real-band test passed on an iPhone 17 Pro Max: the app connected to
  band 64 and the mic test showed 50 packets/s. Next: send the audio to a server.
- **2026-11-14:** Built `server/` (Python): the phone streams the band's audio to it, it
  forwards to Deepgram with speaker separation through the kit's client, and sends back
  speaker-labelled text. Holds the Deepgram key; the app pairs with a 6-digit code;
  conversations are saved as text in `conversations/`. The app has a Live transcript
  section. Tested against the kit's pretend Deepgram only: **needs the real key and a
  phone-to-laptop test.**
- **2026-11-14 (12:10 PT): Pivot.** The product is now for people with dementia and their
  families (decision 11). Meta glasses join the band in the same app: the face identifies
  the person, the band's audio supplies what they said (decision 12). Voice fingerprints
  dropped (decision 9 replaced). Added Phase G with two time gates (1:15 PM phone-camera
  faces, 3:00 PM real glasses), a must-work order for 6 PM, suggestions S6–S10, glasses
  constraints and the hackathon facts from the slides. Nothing is built for this yet.
- **2026-11-14 (12:20 PT):** Built Phase G. Server: `faces.py` (OpenCV YuNet + SFace
  models, strict threshold, stores numbers not photos) on a `/faces` connection, 8 server
  tests pass. App: People & faces screen, iPhone camera, Meta glasses camera through
  Meta's toolkit 1.0.1, spoken announcement. Checked in the Simulator: still pictures
  (right person named, stranger not) and pretend glasses playing a video (pictures reach
  the server, face recognised). Builds for a real iPhone. **Not yet tried on a real
  iPhone, with real glasses, or with a live person's face.** Every teammate's laptop that
  runs the server needs the two README setup commands.
- **2026-11-14 (afternoon):** Considered swapping the glasses for a head-strapped GoPro
  Session + Raspberry Pi Zero 2 W ("MARV 4") and **rejected it**. The GoPro gives no live
  video over USB, only over its own Wi-Fi, and the Pi has one Wi-Fi radio, so it would need
  a second link to reach the server. All of that is unbuilt, while the glasses camera is
  already built. Staying with the Meta glasses (decision 12 unchanged), iPhone camera as
  the fallback.
- **2026-11-14 (1:45 PT):** Real glasses work. Ray-Ban Meta (Gen 2) linked to Familiar on
  the iPhone 17 Pro Max and the user confirmed it works well. What it took: update the
  glasses' firmware in Meta AI, turn on Developer Mode, tap Install next to the glasses on
  that screen, then Link Meta glasses in Familiar. The venue Wi-Fi blocks phone-to-laptop
  traffic, so the laptop joins the iPhone's hotspot (server address `ws://172.20.10.12:8765`
  there). A first "Device unavailable" went away on the next try with the glasses worn.
  Next: the Deepgram key, Gemini profiles, and attaching the band's words to the person in view.
- **2026-11-14 (2:00 PT):** Joined faces and voices. Server: `who.py` decides which voice
  is which person (first voice = wearer; votes from who is in view; no guess with two
  people in view) and saved conversations now have a name on each line plus a `people`
  list, ready for Gemini. App: Listen starts the camera as well, and the transcript shows
  "You" and names. 11 server tests pass, including a whole pretend conversation. **Not
  tried with real speech: the server still has no Deepgram key.**
- **2026-11-14 (2:15 PT):** Built Phase 2. `server/profiles.py` asks Gemini what to
  remember about each named person after a conversation and keeps it as text. The server
  sends the "Last time, …" sentence with each recognised face; the app shows it and says
  it after the name. Forgetting a person deletes their profile too. 14 server tests pass.
  **Never run against real Gemini or real speech: no keys in `.env` yet.**
- **2026-11-14 (2:10 PT): First real end-to-end run.** Band 64 mic → Deepgram → text by
  speaker; Ray-Ban Meta camera → faces → "Justin" and "Sasha" on their lines; Gemini wrote
  a profile for Sasha when the conversation ended. Found and fixed: one voice's name
  flipped between Justin and Sasha as the wearer looked around (now weighted by words,
  and a name only changes on a clear lead); the glasses preview was cropped and looked
  narrow (now the whole picture). Still seen: Deepgram splits and merges voices at the
  wrist, so some lines stay "Speaker N"; Justin got no profile because his voice ended
  the conversation labelled as Sasha. The fix is untested on real speech.
- **2026-11-14 (2:15 PT): Only registered people are recorded (decision 15).** App: a
  Register a person screen (name, relationship, "They agreed to this", photos from the
  camera or library), reachable from the main screen and from People. Server: refuses to
  register without the yes; withholds unregistered voices' words from the phone, the log
  and the saved file; saves nothing when no registered person took part; a voice's
  earlier words appear once it is recognised. 15 server tests pass; registering checked
  in the Simulator. **Not yet tried in a real conversation.** Known gap: the first voice
  after Listen is taken as the wearer and kept, whoever it is. The earlier test file
  `conversations/2026-11-14_14-02-06.json` predates this and still holds unregistered lines.
- **2026-11-14 (2:30 PT): The wearer registers their own voice (decision 16).** App:
  Register my voice screen (read a passage for 12 seconds into the band; forget my voice).
  Server: `voice.py` keeps a description of the voice, and in a conversation compares each
  voice with it once it has said 2.5 seconds, again every 5 seconds. Until the wearer is
  found their words are withheld like anyone unregistered. 19 server tests pass; the real
  audio path was checked with two computer voices (same voice 0.82–0.92, other 0.55–0.63,
  so the bar is 0.55 and the best must lead by 0.05). **Not tried with a real voice on
  the band: the bar may need moving. The server log prints each score.**
- **2026-11-14 (2:35 PT):** `PROJECT_OVERVIEW.md` now has a Features section listing
  everything built, grouped by listening, the wearer's voice, recognising people, naming
  voices, remembering, the recall moment, and the server. Pushed to GitHub.
