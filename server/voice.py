# Knows the wearer's own voice.
#
# The wearer registers once: they read a sentence into the band, and what is kept is a
# list of numbers describing how their voice sounds (server/me.json, git-ignored; no
# sound is kept). In every later conversation the server compares each phrase it hears
# with those numbers, and the phrases that match are "Me", whoever speaks first.
#
# Deepgram's own speaker numbers are not enough for this: at the wrist it often puts the
# wearer and the person in front of them under one number, above all in the first half
# minute (seen 2026-11-14: a whole conversation with Justin came back as "speaker 0").
# So the wearer is found phrase by phrase, by sound, and Deepgram's numbers are only
# used to tell the OTHER voices apart.
#
# That list of numbers is biometric data, like the face ones. forget() deletes it.
#
# Needs: python3 -m pip install --user sherpa-onnx, the model file
# server/models/voice-titanet.onnx and the ffmpeg program (see the README).
#
# The model is NeMo's TitaNet-small. The first one tried (WeSpeaker CAM++) only gave true
# numbers for sound that was an exact multiple of 2 seconds long, and nonsense otherwise
# (measured 2026-11-14), so neither the registered voice nor any comparison could be
# trusted. TitaNet works from about half a second up. Numbers from one model mean nothing
# to another: a voice registered with the old model has to be registered again.
import json
import shutil
import subprocess
import sys
import threading
import time
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "vexo-open-kit" / "examples" / "python"))
from ogg_opus import OggOpusWriter  # noqa: E402  (the kit's own writer: packets -> an Ogg stream)

MODEL = HERE / "models" / "voice-titanet.onnx"
MODEL_NAME = "titanet-small"     # written into me.json: numbers from another model are not used
ME_FILE = HERE / "me.json"

PACKET = 0.02            # seconds of sound in one of the band's packets
REGISTER_AT_LEAST = 6.0  # seconds of reading needed to register
ME = -1                  # the wearer's speaker number (Deepgram's own numbers start at 0)
PHRASE_GAP = 0.35        # a pause this long (seconds) ends a phrase; so does the end of a sentence
COMPARE_FROM = 0.5       # seconds a phrase must last to be compared with any voice

# How alike two sounds are is a number from -1 to 1. Measured through the band's codec
# (2026-11-14, one recorded person and 19 computer voices): one second of the same voice
# 0.46 to 0.74, three seconds 0.8 and more; another voice mostly around 0, similar-sounding
# computer voices up to 0.7. So one number alone cannot be trusted for a short phrase.
# What decides is which of the two it is MORE like: the wearer, or the others in the room.
SOUNDS_LIKE_ME = 0.4     # while no other voice is known: at least this alike is the wearer
UNSURE = 0.1             # "me" and "not me" closer than this: the phrase could be either
WEAK = 0.2               # like nobody more than this: the phrase could be either
JOINED = 0.6             # a phrase that could be either goes with the one before it, if that ended less than this (seconds) earlier
MY_WEIGHT = 6.0          # the registered voice counts as this many seconds of the wearer speaking
OTHERS_FROM = 1.5        # seconds of other voices needed before a phrase is compared with them too
ALL_ME = 0.5             # "the other voices" taken together this alike to the wearer: it was the wearer all along


class VoiceError(Exception):
    """A sentence a person can act on."""


class _Sink:
    def __init__(self):
        self.data = bytearray()

    def write(self, page):
        self.data += page


def decode(packets: list) -> np.ndarray:
    """The band's Opus packets -> sound as numbers (16000 a second, -1..1)."""
    ffmpeg = shutil.which("ffmpeg") or "/opt/homebrew/bin/ffmpeg"
    sink = _Sink()
    ogg = OggOpusWriter(sink)
    for number, packet in enumerate(packets):
        ogg.write(number & 0xFFFF, packet)
    ogg.close()
    try:
        done = subprocess.run([ffmpeg, "-loglevel", "error", "-i", "pipe:0", "-f", "s16le", "-ac", "1", "-ar", "16000", "pipe:1"],
                              input=bytes(sink.data), capture_output=True, timeout=30)
    except (OSError, subprocess.TimeoutExpired):
        raise VoiceError("The server needs the ffmpeg program to work with voices. Install it with: brew install ffmpeg")
    return np.frombuffer(done.stdout[:len(done.stdout) // 2 * 2], np.int16).astype(np.float32) / 32768


class Voice:
    def __init__(self, file: Path = ME_FILE):
        self.file = file
        self.lock = threading.Lock()          # the model is not safe to use from two threads
        self.model = None
        self.mine = None                      # the wearer's voice, as numbers
        try:
            kept = json.loads(file.read_text())
            if kept.get("model") == MODEL_NAME:
                self.mine = np.asarray(kept["voice"], np.float32)
            else:
                print("The registered voice was made with an older voice model and cannot be used: "
                      "register the voice again in the app (Register my voice).")
        except (OSError, ValueError, KeyError, TypeError, AttributeError):
            pass

    @property
    def registered(self) -> bool:
        return self.mine is not None

    def numbers(self, sound: np.ndarray) -> np.ndarray:
        with self.lock:
            if self.model is None:
                if not MODEL.exists():
                    raise VoiceError("The voice model file is missing from server/models/. The README says how to get it.")
                try:
                    import sherpa_onnx
                except ImportError:
                    raise VoiceError("The server needs one more package for voices: python3 -m pip install --user sherpa-onnx")
                self.model = sherpa_onnx.SpeakerEmbeddingExtractor(sherpa_onnx.SpeakerEmbeddingExtractorConfig(model=str(MODEL)))
            stream = self.model.create_stream()
            stream.accept_waveform(sample_rate=16000, waveform=sound)
            stream.input_finished()
            return np.asarray(self.model.compute(stream), np.float32)

    def register(self, packets: list) -> dict:
        seconds = len(packets) * PACKET
        if seconds < REGISTER_AT_LEAST:
            raise VoiceError("That was only %.0f seconds. Read for at least %.0f." % (seconds, REGISTER_AT_LEAST))
        sound = decode(packets)
        if len(sound) < 16000 or float(np.sqrt(np.mean(sound ** 2))) < 0.003:
            raise VoiceError("The band heard almost nothing. Hold it nearer your mouth and read out loud.")
        self.mine = self.numbers(sound)
        self.file.write_text(json.dumps({"voice": self.mine.tolist(), "model": MODEL_NAME, "at": time.time(), "seconds": seconds}))
        self.file.chmod(0o600)
        return {"registered": True, "seconds": round(seconds, 1)}

    def forget(self) -> None:
        self.mine = None
        try:
            self.file.unlink()
        except OSError:
            pass


def phrases(words) -> list:
    """Deepgram's settled words -> phrases: [{"voice": Deepgram's speaker number, "text",
    "start", "end"}]. A phrase ends where Deepgram's number changes, where a sentence
    ends, or at a pause. One phrase is taken to be one person speaking."""
    out, open_phrase = [], False
    for word in words or []:
        if not isinstance(word, dict):
            continue
        text = str(word.get("punctuated_word") or word.get("word") or "").strip()
        try:
            start, end = float(word["start"]), float(word["end"])
        except (KeyError, TypeError, ValueError):
            continue
        if not text or end <= start:
            continue
        voice = word.get("speaker")
        voice = voice if isinstance(voice, int) and not isinstance(voice, bool) else None
        if open_phrase and out[-1]["voice"] == voice and start - out[-1]["end"] < PHRASE_GAP:
            out[-1]["text"] += " " + text
            out[-1]["end"] = end
        else:
            out.append({"voice": voice, "text": text, "start": start, "end": end})
        open_phrase = text[-1] not in ".?!"
    return out


def _alike(a, b) -> float:
    return float(a @ b / ((np.linalg.norm(a) * np.linalg.norm(b)) or 1))


class Listening:
    """One conversation: remembers the sound, and says of every phrase whether the wearer
    said it.

    Each phrase is compared with two things: the wearer's voice (the registered one, plus
    what the wearer has said so far in this room) and the other voices heard so far in
    this room. Whichever it is more like wins. Comparing with both is what makes short
    phrases work: a two-word answer is a poor match for anything, but it is still more
    like the person who said it. Every new phrase teaches both sides, so earlier phrases
    are decided again each time and can change."""

    def __init__(self, voice: Voice):
        self.voice = voice
        self.lock = threading.Lock()
        self.packets = []
        self.said = []           # every settled phrase, in order (see phrases(), plus what is worked out here)

    def packet(self, packet: bytes) -> None:
        with self.lock:
            self.packets.append(packet)

    def heard(self, words: list) -> list:
        """Deepgram's settled words -> [{"speaker": ME or Deepgram's number, "text",
        "phrase": its place in speakers()}]. Call speakers() afterwards: earlier phrases
        may have changed sides."""
        new = phrases(words)
        if not new:
            return []
        lead = 5                 # packets decoded before the first word, for the decoder to settle; then dropped
        first = max(0, int(min(p["start"] for p in new) / PACKET) - lead)
        with self.lock:
            packets = self.packets[first:int(max(p["end"] for p in new) / PACKET) + 2]
        sound = decode(packets) if packets else np.zeros(0, np.float32)
        with self.lock:
            edge = self.said[-1]["end"] if self.said else 0.0
        for place, phrase in enumerate(new):
            # Deepgram's times cut words close: a little more on each side, up to the neighbours.
            start = max(edge, phrase["start"] - 0.08)
            edge = phrase["end"]
            end = min(new[place + 1]["start"] if place + 1 < len(new) else phrase["end"] + 0.12, phrase["end"] + 0.12)
            piece = sound[max(0, int(round((start - first * PACKET) * 16000))):int(round((end - first * PACKET) * 16000))]
            phrase["seconds"] = len(piece) / 16000
            phrase["sound"] = phrase["mine"] = phrase["me"] = None
            phrase["silent"], phrase["teaches"] = False, 0
            if phrase["seconds"] >= COMPARE_FROM and float(np.sqrt(np.mean(piece ** 2))) > 0.0005:
                numbers = self.voice.numbers(piece)
                phrase["sound"] = numbers / (np.linalg.norm(numbers) or 1)
        with self.lock:
            at = len(self.said)
            self.said += new
            self._decide()
            return [{"speaker": ME if phrase["me"] else phrase["voice"], "text": phrase["text"], "phrase": at + i}
                    for i, phrase in enumerate(new)]

    def speakers(self) -> list:
        """The speaker number of every phrase so far, as decided now."""
        with self.lock:
            return [ME if phrase["me"] else phrase["voice"] for phrase in self.said]

    def guess(self, pieces: list) -> list:
        """For words that are not settled yet: each piece goes to whoever spoke last under
        that Deepgram number. The settled words put it right a moment later."""
        with self.lock:
            last = {phrase["voice"]: phrase["me"] for phrase in self.said}
        return [dict(piece, speaker=ME) if last.get(piece.get("speaker")) else piece for piece in pieces]

    def note(self, place: int) -> str:
        """A few numbers about one phrase for the server's window. No words."""
        with self.lock:
            phrase = self.said[place]
            who = "the wearer" if phrase["me"] else "not the wearer"
            if phrase["sound"] is None:
                return "%.1f s, too short to compare, goes with its neighbour: %s" % (phrase["seconds"], who)
            return "%.1f s, %.2f like the wearer%s%s: %s" % (
                phrase["seconds"], phrase["like_me"],
                "" if phrase["like_others"] is None else ", %.2f like the other voices" % phrase["like_others"],
                ", could be either so it goes with its neighbour" if phrase["silent"] else "", who)

    def _decide(self) -> None:
        """Sorts every phrase so far into "the wearer" and "not the wearer". Call with the lock held."""
        mine = self.voice.mine / (np.linalg.norm(self.voice.mine) or 1)
        nothing = np.zeros_like(mine)
        clear = [phrase for phrase in self.said if phrase["sound"] is not None]
        alone = False            # True once the phrases that seemed to be someone else turn out to be the wearer

        def judge(phrase) -> None:
            """Sets "mine" (more like the wearer?), "silent" (it could be either) and
            "teaches" (1: it shows what the wearer sounds like here, -1: what the others do, 0: neither)."""
            like_me, like_others = phrase["like_me"], phrase["like_others"]
            if like_others is None:                          # only the wearer's voice to compare with
                phrase["mine"] = like_me >= SOUNDS_LIKE_ME
                phrase["silent"] = abs(like_me - SOUNDS_LIKE_ME) < UNSURE or (alone and not phrase["mine"])
                # Anything that is not clearly the wearer is tried as "another voice": if those
                # phrases are alike, they become one (below), however near the wearer's they sound.
                phrase["teaches"] = 1 if phrase["mine"] and not phrase["silent"] else 0 if phrase["mine"] or alone else -1
            else:
                phrase["mine"] = like_me > like_others
                phrase["silent"] = abs(like_me - like_others) < UNSURE or max(like_me, like_others) < WEAK
                phrase["teaches"] = 0 if phrase["silent"] else 1 if phrase["mine"] else -1

        for phrase in clear:
            if phrase["mine"] is None:                       # new: a first look, against the registered voice alone
                phrase["like_me"], phrase["like_others"] = _alike(phrase["sound"], mine), None
                judge(phrase)
        for _ in range(8):                                   # a few rounds: each side's sound sharpens the other
            me = MY_WEIGHT * mine + sum((p["seconds"] * p["sound"] for p in clear if p["teaches"] > 0), nothing)
            others = sum((p["seconds"] * p["sound"] for p in clear if p["teaches"] < 0), nothing)
            others_seconds = sum(p["seconds"] for p in clear if p["teaches"] < 0)
            if others_seconds >= OTHERS_FROM and _alike(others, me) >= ALL_ME:
                alone, others, others_seconds = True, nothing, 0.0
            before = [(p["mine"], p["silent"], p["teaches"]) for p in clear]
            for phrase in clear:                             # a phrase is never compared with itself
                own = phrase["seconds"] * phrase["sound"]
                phrase["like_me"] = _alike(phrase["sound"], me - own if phrase["teaches"] > 0 else me)
                phrase["like_others"] = None
                if others_seconds - (phrase["seconds"] if phrase["teaches"] < 0 else 0) >= OTHERS_FROM:
                    phrase["like_others"] = _alike(phrase["sound"], others - own if phrase["teaches"] < 0 else others)
            for phrase in clear:
                judge(phrase)
            if before == [(p["mine"], p["silent"], p["teaches"]) for p in clear]:
                break

        # What is shown. A phrase that could be either (or is too short to compare) goes
        # with the phrase it follows, or failing that the one after it, when they are
        # nearly joined and Deepgram heard them as one voice.
        def joined(earlier, later) -> bool:
            return earlier["voice"] == later["voice"] and later["start"] - earlier["end"] < JOINED

        waiting = []
        for place, phrase in enumerate(self.said):
            before = self.said[place - 1] if place else None
            if phrase["sound"] is not None and not phrase["silent"]:
                phrase["me"] = phrase["mine"]
            elif before is not None and before["me"] is not None and joined(before, phrase):
                phrase["me"] = before["me"]
            else:
                phrase["me"] = None                          # decided below, from the phrase after it
                waiting.append(place)
        for place in reversed(waiting):
            phrase = self.said[place]
            after = self.said[place + 1] if place + 1 < len(self.said) else None
            if after is not None and joined(phrase, after):
                phrase["me"] = after["me"]
            elif phrase["sound"] is not None:
                phrase["me"] = phrase["mine"]                # alone: its own best guess
            else:                                            # alone and too short: what that Deepgram voice mostly is
                same = [p for p in clear if not p["silent"] and p["voice"] == phrase["voice"]]
                phrase["me"] = sum(p["seconds"] * (1 if p["mine"] else -1) for p in same) > 0
