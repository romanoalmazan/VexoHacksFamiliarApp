# Familiar: Project Overview

Familiar helps people with dementia or memory loss recognise the people in their lives.
A wristband listens to the conversation, a pair of camera glasses sees who the wearer is
looking at, and the next time that person walks up, the wearer is told who it is and what
they last talked about: "This is Maria, your daughter. Last time, she told you about her
grandson's graduation."

Built in one day at the Vexo hackathon (2026-11-14) on the
[vexo-open-kit](https://github.com/VexoAI-Org/vexo-open-kit).

## How it works

Two wearables, one iPhone app, one small server.

| Part | Job |
|---|---|
| **Vexo Open band** (wrist) | The ears. Its microphone streams audio to the iPhone over Bluetooth. |
| **Meta glasses** (Ray-Ban Meta) | The eyes. The camera sends about one picture a second. The iPhone camera works as a stand-in. |
| **iPhone app** (`ios/`) | Connects both devices, forwards audio and pictures to the server, shows the transcript and who is in view, and speaks the person's name. |
| **Server** (`server/`) | Holds every API key. Turns audio into text, matches faces, decides which voice belongs to which person, and builds each person's profile. |

```
band mic ──Bluetooth──▶ iPhone app ──▶ server ──▶ Deepgram (speech → text, split by speaker)
                           ▲   │          │
glasses camera ────────────┘   │          ├──▶ face match (which registered person is in view?)
                               │          ├──▶ Gemini (conversation → what to remember)
                               ▼          ▼
                   card + spoken line ◀── profiles
```

The face says **who** the person is. The band's audio says **what they said**. The two are
joined on the server: the first voice after tapping Listen is the wearer, and another
voice that speaks while exactly one registered face is in view gets that person's name.

## Privacy rules built into the code

- **Only registered people are recorded.** A person is registered in the app with a name,
  a relationship and a confirmed yes from them or their family. The server refuses to
  register anyone without it.
- Words from anyone else are withheld from the phone, never saved, and dropped when the
  conversation ends. A conversation with no registered person leaves nothing behind.
- Camera pictures are compared and thrown away. Per person the server keeps a name, a
  relationship and numbers describing the face, not photos.
- Profiles are text only. No audio is stored.
- API keys live on the server and never in the app.
- One thing this does not cover: Deepgram hears the whole room in order to make the text.

## What's in the repo

```
ios/
  Familiar/            the SwiftUI app
    BandView.swift       main screen: band connection, battery, Listen, live transcript
    FacesView.swift      People & faces: who is in view, the people list
    RegisterView.swift   register a person (name, relationship, consent, photos)
    GlassesCamera.swift  Meta glasses camera (Meta Wearables Device Access Toolkit 1.0.1)
    PhoneCamera.swift    iPhone camera, used when there are no glasses
    FaceClient.swift     pictures to the server, names back
    TranscriptClient.swift  band audio to the server, text back
  VexoBand/            Swift package: the band's Bluetooth protocol, a pretend band,
                       and tests against the kit's test vectors
  project.yml          XcodeGen project definition
server/
  server.py            WebSocket server (port 8765), pairing code, the recording rules
  diarized.py          Deepgram with speaker separation, through the kit's client
  faces.py             face detection and matching (OpenCV YuNet + SFace)
  who.py               which voice is which person
  profiles.py          Gemini reads a conversation and updates each person's profile
  test_server.py       server tests
ROUGH_PLAN.md          the working plan: phases, decisions, changelog
README.md              setup for faces and the Meta glasses
```

## Running it

**Server** (on a laptop the iPhone can reach):

1. Clone the kit next to `server/`: `git clone https://github.com/VexoAI-Org/vexo-open-kit.git`
2. Put `DEEPGRAM_API_KEY` and `GEMINI_API_KEY` in a `.env` file in the project folder.
3. Install the face models (the two `curl` commands in [README.md](README.md)).
4. `python3 server/server.py`. It prints its address and a 6-digit pairing code.

**App:** open `ios/Familiar.xcodeproj` in Xcode and run it on an iPhone. Enter the server
address and pairing code, register a person, then tap Listen. Meta glasses setup is in
[README.md](README.md).

The band client connects only to band 64 (our team's band). To use a different one,
change `teamBand` in `ios/Familiar/FamiliarApp.swift`.

## Status

Working end to end in a real test: band microphone → Deepgram → text by speaker; Ray-Ban
Meta camera → faces → names on the right lines; Gemini wrote a profile when the
conversation ended.

Known gaps:

- Deepgram sometimes splits or merges voices picked up at the wrist, so some lines stay
  unnamed.
- The first voice after Listen is taken as the wearer, whoever it is.
- The spoken line plays through the iPhone's voice; not yet confirmed in the glasses'
  speakers.
- The app's screens are functional and do not yet match the planned design.

[ROUGH_PLAN.md](ROUGH_PLAN.md) has the full history, every decision and why it was made.

## Built with

Swift, SwiftUI and CoreBluetooth · Python and WebSockets · Deepgram (speech to text and
speaker separation) · Gemini (profiles) · OpenCV (faces) · Meta Wearables Device Access
Toolkit · Vexo Open band
