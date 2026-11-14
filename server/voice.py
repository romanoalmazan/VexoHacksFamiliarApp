# Knows the wearer's own voice.
#
# The wearer registers once: they read a sentence into the band, and what is kept is a
# list of numbers describing how their voice sounds (server/me.json, git-ignored; no
# sound is kept). In every later conversation the server compares each voice it hears
# with those numbers, and the one that matches is "Me", whoever speaks first.
#
# That list of numbers is biometric data, like the face ones. forget() deletes it.
#
# Needs: python3 -m pip install --user sherpa-onnx, the model file server/models/voice.onnx
# and the ffmpeg program (see the README).
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

MODEL = HERE / "models" / "voice.onnx"
ME_FILE = HERE / "me.json"

PACKET = 0.02            # seconds of sound in one of the band's packets
REGISTER_AT_LEAST = 6.0  # seconds of reading needed to register
CHECK_FROM = 2.5         # seconds a voice must have spoken before it is compared
CHECK_AGAIN = 5.0        # compare again each time it has said this much more...
CHECK_UP_TO = 30.0       # ...until it has said this much
USE_LAST = 15.0          # seconds of a voice's most recent speech used for a comparison
SOUNDS_LIKE_ME = 0.55    # how alike (cosine, -1..1) a voice must be to be the wearer
CLEARLY = 0.05           # and this much more alike than any other voice in the room


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
            self.mine = np.asarray(json.loads(file.read_text())["voice"], np.float32)
        except (OSError, ValueError, KeyError, TypeError):
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
        self.file.write_text(json.dumps({"voice": self.mine.tolist(), "at": time.time(), "seconds": seconds}))
        self.file.chmod(0o600)
        return {"registered": True, "seconds": round(seconds, 1)}

    def forget(self) -> None:
        self.mine = None
        try:
            self.file.unlink()
        except OSError:
            pass

    def like_me(self, packets: list) -> float:
        """How much this sound is the wearer's voice: about 0 for a stranger, towards 1 for the wearer."""
        if self.mine is None or not packets:
            return 0.0
        sound = decode(packets)
        if len(sound) < 8000:
            return 0.0
        theirs = self.numbers(sound)
        return float(theirs @ self.mine / ((np.linalg.norm(theirs) * np.linalg.norm(self.mine)) or 1))


class Listening:
    """One conversation: remembers the sound and when each voice spoke, and says which
    voice is the wearer's."""

    def __init__(self, voice: Voice):
        self.voice = voice
        self.lock = threading.Lock()
        self.packets = []
        self.spoke = {}          # speaker -> [(first packet, last packet + 1)]
        self.seconds = {}        # speaker -> seconds spoken
        self.checked = {}        # speaker -> seconds spoken when last compared
        self.scores = {}         # speaker -> how much it sounds like the wearer

    def packet(self, packet: bytes) -> None:
        with self.lock:
            self.packets.append(packet)

    def words(self, words: list) -> list:
        """Deepgram's settled words (each with speaker, start, end). Returns the voices
        that have now said enough to be compared (again)."""
        due = []
        with self.lock:
            for word in words or []:
                try:
                    speaker, start, end = word["speaker"], float(word["start"]), float(word["end"])
                except (KeyError, TypeError, ValueError):
                    continue
                if not isinstance(speaker, int) or isinstance(speaker, bool) or end <= start:
                    continue
                self.spoke.setdefault(speaker, []).append((int(start / PACKET), int(end / PACKET) + 1))
                self.seconds[speaker] = self.seconds.get(speaker, 0.0) + end - start
            for speaker, said in self.seconds.items():
                last = self.checked.get(speaker)
                if (last is None and said >= CHECK_FROM) or (last is not None and last < CHECK_UP_TO and said - last >= CHECK_AGAIN):
                    self.checked[speaker] = said
                    due.append(speaker)
        return due

    def compare(self, speaker) -> float:
        with self.lock:
            chosen, left = [], int(USE_LAST / PACKET)
            for first, last in reversed(self.spoke.get(speaker, [])):      # the most recent speech first
                piece = self.packets[max(first, last - left):last]
                chosen[:0] = piece
                left -= len(piece)
                if left <= 0:
                    break
        score = self.voice.like_me(chosen)
        with self.lock:
            self.scores[speaker] = score
        return score

    def me(self):
        """The voice that is the wearer's, or None while no voice sounds enough like them."""
        with self.lock:
            ranked = sorted(self.scores.items(), key=lambda item: -item[1])
        if not ranked or ranked[0][1] < SOUNDS_LIKE_ME:
            return None
        if len(ranked) > 1 and ranked[0][1] - ranked[1][1] < CLEARLY:
            return None
        return ranked[0][0]
