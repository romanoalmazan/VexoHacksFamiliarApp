# The kit's Deepgram client (vexo-open-kit/examples/python/speech.py), plus one thing it
# leaves out: WHO said each piece. Deepgram tags every word with a speaker number when
# asked to (diarize=true); the kit keeps only the text. This subclass keeps both.
#
# The key, the address and the "do not train on this" setting all stay in the kit's file.
import sys
from pathlib import Path

KIT = Path(__file__).resolve().parent.parent / "vexo-open-kit"
sys.path.insert(0, str(KIT / "examples" / "python"))
import speech  # noqa: E402  (the kit's helper; it finds the band library itself)


def segments(words):
    """Deepgram's word list -> [{"speaker": 0, "text": "Hi, I'm Sarah."}, ...]: one piece
    for each run of words by the same speaker. speaker is None when Deepgram gave none."""
    out = []
    for word in words or []:
        if not isinstance(word, dict):
            continue
        text = str(word.get("punctuated_word") or word.get("word") or "").strip()
        if not text:
            continue
        speaker = word.get("speaker")
        speaker = speaker if isinstance(speaker, int) and not isinstance(speaker, bool) else None
        if out and out[-1]["speaker"] == speaker:
            out[-1]["text"] += " " + text
        else:
            out.append({"speaker": speaker, "text": text})
    return out


class DiarizedSpeech(speech.DeepgramSpeech):
    """on_segments(pieces, final) is called from another thread while people speak.
    final=False is a guess that may still change; final=True is settled.

    tell_apart(words, final), if given, turns Deepgram's words (each with its speaker
    number and its times) into the pieces, in place of segments(): the server uses it to
    find the wearer's voice by sound."""

    def __init__(self, on_segments, tell_apart=None, **options):
        super().__init__(diarize="true", **options)
        self.on_segments = on_segments
        self.tell_apart = tell_apart

    def _message(self, message: dict) -> None:
        if message.get("type") == "Results":
            best = (message.get("channel", {}).get("alternatives") or [{}])[0]
            final = bool(message.get("is_final"))
            if self.tell_apart and isinstance(best.get("words"), list):
                pieces = self.tell_apart(best["words"], final)
            else:
                pieces = segments(best.get("words"))
            if not pieces:                                   # no word list: fall back to the plain text
                text = str(best.get("transcript") or "").strip()
                pieces = [{"speaker": None, "text": text}] if text else []
            if pieces:
                self.on_segments(pieces, final)
        super()._message(message)
