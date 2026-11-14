# Turns a finished conversation into what is worth remembering about each person in it,
# using Gemini. The next time that person is in view, the wearer can be told who they are
# AND what they last talked about.
#
# Only people who were enrolled and recognised get a profile (see who.py). What is sent to
# Google: the conversation's text with names on the lines. No sound, no pictures.
# What is kept: server/profiles.json (git-ignored), text only.
#
# The key lives ONLY here: GEMINI_API_KEY in the environment, or in the .env file in the
# folder the server is started in. Optional: GEMINI_MODEL to pick the model yourself.
import json
import os
import threading
import time
import urllib.error
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
PROFILES_FILE = HERE / "profiles.json"
API = "https://generativelanguage.googleapis.com/v1beta"
MAX_FACTS = 20
MAX_VISITS = 10

PROMPT = """You help a person with memory loss remember the people in their life.
Below is a conversation between the wearer of a listening device ("Me") and other people.
For each person named in PEOPLE, say what is worth remembering from THIS conversation.

Rules:
- Use only what is in the conversation. Never guess or add anything. If a person said
  nothing worth remembering, give an empty "recall" and no facts.
- "recall": ONE short, warm, plain sentence spoken to the wearer about what this person
  told them or what they did together, starting with "Last time,". At most 20 words.
  Example: "Last time, she told you her grandson Leo graduated and she brought you photos."
- "facts": up to 5 short lasting facts about the person or their life (family, work,
  health, plans), each under 12 words. Not small talk.
- "follow_ups": up to 2 things the wearer could ask about next time, each under 12 words.
- Only the wearer and registered people appear below. Other people may have been in the
  room; their words were not kept, so some replies may seem to answer nothing.

Answer with JSON only, in this shape:
{"people": {"<name>": {"recall": "...", "facts": ["..."], "follow_ups": ["..."]}}}

PEOPLE: %s
WHAT WE ALREADY KNOW: %s

CONVERSATION:
%s
"""


class ProfilesError(Exception):
    """A sentence a person can act on. Never contains the key."""


def env(name: str) -> str:
    """From the environment, or from .env in the folder the program was started in."""
    found = os.environ.get(name, "").strip()
    if not found:
        try:
            for line in open(os.path.join(os.getcwd(), ".env"), encoding="utf-8"):
                line = line.strip()
                if line.startswith("export "):
                    line = line[7:]
                key, _, value = line.partition("=")
                if key.strip() == name and value.strip():
                    found = value.strip().strip("'\"")
        except (OSError, ValueError):
            pass
    return found


def call(path: str, body=None, timeout=40) -> dict:
    key = env("GEMINI_API_KEY")
    if not key:
        raise ProfilesError("Profiles need a Gemini key. Put GEMINI_API_KEY=your-key in the .env file in the folder you start the server in.")
    request = urllib.request.Request(API + path, data=json.dumps(body).encode() if body is not None else None,
                                     headers={"x-goog-api-key": key, "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(request, timeout=timeout) as answer:
            return json.loads(answer.read())
    except urllib.error.HTTPError as problem:
        detail = ""
        try:
            detail = json.loads(problem.read()).get("error", {}).get("message", "")
        except (ValueError, OSError):
            pass
        if problem.code in (401, 403) or "API key" in detail:
            raise ProfilesError("Gemini did not accept the key in GEMINI_API_KEY. Copy it again, the whole key and nothing else.")
        raise ProfilesError("Gemini answered with a problem (%d). %s" % (problem.code, detail.replace(key, "…")[:200]))
    except (urllib.error.URLError, OSError, ValueError) as problem:
        raise ProfilesError("Could not reach Gemini: %s" % problem)


_model = None


def model() -> str:
    """GEMINI_MODEL if set. Otherwise ask Google what this key can use and take the
    newest Flash model: fast and cheap is right for a sentence or two."""
    global _model
    if _model:
        return _model
    chosen = env("GEMINI_MODEL")
    if not chosen:
        usable = [m["name"].split("/")[-1] for m in call("/models?pageSize=200").get("models", [])
                  if "generateContent" in m.get("supportedGenerationMethods", [])]
        plain = [m for m in usable if m.startswith("gemini-") and not any(
            word in m for word in ("image", "tts", "audio", "live", "embedding", "vision", "thinking", "lite", "exp", "preview"))]

        def rank(name):                                   # "gemini-4.0-flash" -> (4.0, is flash)
            try:
                version = float(name.split("-")[1])
            except (IndexError, ValueError):
                version = 0.0
            return (version, "flash" in name, -len(name))
        candidates = sorted(plain or usable, key=rank, reverse=True)
        if not candidates:
            raise ProfilesError("This Gemini key has no model that can write text. Set GEMINI_MODEL in .env to choose one.")
        flash = [m for m in candidates if "flash" in m and rank(m)[0] == rank(candidates[0])[0]]
        chosen = (flash or candidates)[0]
    _model = chosen
    return chosen


def transcript(segments: list) -> str:
    lines = []
    for piece in segments:
        label = piece.get("person") or ("Speaker %s" % piece["speaker"] if piece.get("speaker") is not None else "Someone")
        if lines and lines[-1][0] == label:
            lines[-1][1] += " " + piece["text"]
        else:
            lines.append([label, piece["text"]])
    return "\n".join("%s: %s" % (label, text) for label, text in lines)


def clean(text, most=200) -> str:
    return " ".join(str(text or "").split())[:most]


class Profiles:
    def __init__(self, file: Path = PROFILES_FILE):
        self.file = file
        self.lock = threading.Lock()
        self.people = {}        # name -> {"recall", "last_seen", "facts": [], "follow_ups": [], "visits": [{"at", "recall"}]}
        try:
            self.people = json.loads(file.read_text())
        except (OSError, ValueError):
            pass

    def get(self, name: str) -> dict:
        with self.lock:
            return dict(self.people.get(name) or {})

    def forget(self, name: str) -> None:
        with self.lock:
            if self.people.pop(name, None) is not None:
                self.keep()

    def learn(self, conversation: dict) -> list:
        """Reads one saved conversation and updates the profile of each named person in
        it. Returns the names updated. Raises ProfilesError with a sentence to act on."""
        names = [n for n in conversation.get("people") or [] if n]
        said = [s for s in conversation.get("segments") or [] if s.get("person") in names]
        if not names or not said:
            return []
        with self.lock:
            known = {n: {"facts": (self.people.get(n) or {}).get("facts", [])} for n in names}
        prompt = PROMPT % (", ".join(names), json.dumps(known), transcript(conversation["segments"]))
        answer = call("/models/%s:generateContent" % model(), {
            "contents": [{"parts": [{"text": prompt}]}],
            "generationConfig": {"responseMimeType": "application/json", "temperature": 0.2}})
        try:
            text = answer["candidates"][0]["content"]["parts"][0]["text"]
            found = json.loads(text).get("people") or {}
        except (KeyError, IndexError, TypeError, ValueError, AttributeError):
            raise ProfilesError("Gemini's answer was not in the shape asked for. Nothing was changed.")
        at, updated = conversation.get("ended") or time.time(), []
        with self.lock:
            for name in names:
                new = found.get(name)
                if not isinstance(new, dict):
                    continue
                person = self.people.setdefault(name, {"facts": [], "follow_ups": [], "visits": []})
                person["last_seen"] = at
                recall = clean(new.get("recall"))
                if recall:
                    person["recall"] = recall
                    person["visits"] = (person.get("visits", []) + [{"at": at, "recall": recall}])[-MAX_VISITS:]
                facts = person.get("facts", [])
                for fact in new.get("facts") or []:
                    fact = clean(fact, 120)
                    if fact and fact.lower() not in [f.lower() for f in facts]:
                        facts.append(fact)
                person["facts"] = facts[-MAX_FACTS:]
                follow = [clean(f, 120) for f in new.get("follow_ups") or [] if clean(f)]
                if follow:
                    person["follow_ups"] = follow[:2]
                updated.append(name)
            if updated:
                self.keep()
        return updated

    def keep(self) -> None:
        self.file.write_text(json.dumps(self.people, indent=1))
        self.file.chmod(0o600)
