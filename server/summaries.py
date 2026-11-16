# Quick summaries of a conversation while it happens, and one fuller summary when it ends, with Gemini 4.
#
#   live:   Gemini 4 Hydrogen (fast), at most every SUMMARY_EVERY seconds (20) once 3 new lines have settled
#           -> to the phone as {"type": "summary", "final": false, "summary", "points", "follow_ups", "model", "lines"}
#   final:  Gemini 4 Carbon (deeper reasoning), once, after the conversation ends -> saved with the conversation
#
# Same rule as everything else here: ONLY the wearer's words and registered people's are used. Anyone else's
# words were withheld from the phone and are never sent to Gemini. What is sent to Google: that text, with
# names on the lines. No sound, no pictures.
#
# Models: GEMINI_SUMMARY_MODEL and GEMINI_FINAL_SUMMARY_MODEL in .env change them. Gemini 4 models take no
# temperature setting (Google's guidance); structured output keeps the answers in the shape below.
import json
import threading
import time

from profiles import ProfilesError, call, clean, env, transcript

LIVE_MODEL = "gemini-4-hydrogen"
FINAL_MODEL = "gemini-4-carbon"
EVERY = 20.0                 # seconds between live summaries at most
MIN_NEW = 3                  # settled lines needed before a new live summary
MAX_LINES = 80               # the most recent lines sent for a live summary

SCHEMA = {
    "type": "object",
    "properties": {
        "summary": {"type": "string"},
        "points": {"type": "array", "items": {"type": "string"}},
        "follow_ups": {"type": "array", "items": {"type": "string"}},
    },
    "required": ["summary", "points", "follow_ups"],
}

LIVE_PROMPT = """You help a person with memory loss follow a conversation while it is happening.
Below is the conversation so far between the wearer of a listening device ("Me") and other people.

Write, using ONLY what is in the conversation (never guess or add anything):
- "summary": what is being talked about right now, in one or two short, plain sentences, at most 30 words.
- "points": up to 4 key facts worth holding on to (names, plans, dates, places), each under 12 words.
- "follow_ups": up to 2 things the wearer could say or ask next, each under 12 words.
"Speaker N" lines are people whose name is not known. If there is too little to summarise, say so briefly.

CONVERSATION:
%s
"""

FINAL_PROMPT = """You help a person with memory loss remember a conversation that just ended.
Below is the whole conversation between the wearer of a listening device ("Me") and other people.

Write, using ONLY what is in the conversation (never guess or add anything):
- "summary": what the conversation was about, in at most 3 short, plain sentences.
- "points": up to 6 lasting facts or decisions (names, family, plans, dates), each under 14 words.
- "follow_ups": up to 3 things the wearer could ask or do next time, each under 14 words.
"Speaker N" lines are people whose name is not known.

CONVERSATION:
%s
"""


def summarise(segments, model, prompt, thinking=None, timeout=40) -> dict:
    """One summary of these segments ([{"speaker", "text", "person"}]). Raises ProfilesError with a sentence."""
    text = transcript(segments)
    if not text.strip():
        raise ProfilesError("Nothing to summarise yet.")
    config = {"responseMimeType": "application/json", "responseSchema": SCHEMA}
    if thinking:
        config["thinkingConfig"] = {"thinkingLevel": thinking}
    answer = call("/models/%s:generateContent" % model, {"contents": [{"parts": [{"text": prompt % text}]}],
                                                         "generationConfig": config}, timeout=timeout)
    try:
        found = json.loads(answer["candidates"][0]["content"]["parts"][0]["text"])
    except (KeyError, IndexError, TypeError, ValueError):
        raise ProfilesError("Gemini's summary was not in the shape asked for.")
    return {"summary": clean(found.get("summary"), 300),
            "points": [clean(p, 140) for p in found.get("points") or [] if clean(p)][:6],
            "follow_ups": [clean(f, 140) for f in found.get("follow_ups") or [] if clean(f)][:3],
            "model": model}


class LiveSummaries:
    """Summarises the conversation in the background while it happens. Never blocks the transcript: if Gemini
    is slow or fails, the phone simply keeps its last summary, and the server window says why (once)."""

    def __init__(self, lines, send, every=None, min_new=MIN_NEW, summarise=summarise, log=print):
        self.lines = lines                    # callable -> the shown, settled segments so far
        self.send = send                      # callable(dict) -> the phone
        self.every = float(env("SUMMARY_EVERY") or every or EVERY)
        self.min_new = min_new
        self.model = env("GEMINI_SUMMARY_MODEL") or LIVE_MODEL
        self.summarise = summarise
        self.log = log
        self.done = 0                         # lines covered by the last summary
        self.last = None
        self._said = None
        self._stop = threading.Event()

    def start(self):
        if not env("GEMINI_API_KEY"):
            self.log("No Gemini key: no live summaries.")
            return self
        threading.Thread(target=self._loop, name="summaries", daemon=True).start()
        return self

    def stop(self):
        self._stop.set()

    def _loop(self):
        while not self._stop.wait(self.every):
            self.run_once()

    def run_once(self) -> bool:
        segments = self.lines()
        if len(segments) - self.done < self.min_new:
            return False
        try:
            started = time.monotonic()
            result = self.summarise(segments[-MAX_LINES:], self.model, LIVE_PROMPT)
        except ProfilesError as problem:
            if str(problem) != self._said:
                self._said = str(problem)
                self.log("  (no live summary: %s)" % problem)
            return False
        self._said = None
        self.done = len(segments)
        self.last = dict(result, type="summary", final=False, lines=len(segments),
                         seconds=round(time.monotonic() - started, 1))
        self.send(self.last)
        return True


def final_summary(conversation) -> dict:
    """The fuller summary of a finished conversation (Gemini 4 Carbon). Raises ProfilesError."""
    model = env("GEMINI_FINAL_SUMMARY_MODEL") or FINAL_MODEL
    return summarise(conversation.get("segments") or [], model, FINAL_PROMPT, timeout=90)
