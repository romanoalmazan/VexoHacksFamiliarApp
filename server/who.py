# Joins the two halves: the band's sound says WHAT was said and by which voice ("speaker
# 0", "speaker 1": labels that only mean something inside one conversation). The camera
# says WHO is in front of the wearer. This file decides which voice belongs to which person.
#
# The rules, kept simple on purpose:
#   - The wearer ("Me"): if they registered their voice, voice.py finds their phrases by
#     sound and gives them a speaker number of their own (voice.ME), so here the wearer
#     is known from the start. If they never registered one, it is the first voice
#     heard after Listen is switched on, so then the wearer speaks first.
#   - When another voice speaks while exactly one enrolled person is surely in view, that
#     is a vote that the voice is that person, weighted by how many words were said (the
#     wearer often glances at someone else during a short "yeah").
#   - A voice gets a name after a few words' worth of votes. The name then labels
#     everything that voice said, before and after, in view or not.
#   - A name only changes when another person has clearly more votes, so names do not
#     flip back and forth. (Seen in the first real test, 2026-11-14.)
#   - Two enrolled people in view, or nobody: no vote. A wrong name is worse than no name.
import threading
import time

FRESH = 4.0          # seconds a camera sighting stays believable
ENOUGH = 3           # words' worth of votes before a voice gets a name
CLEARLY = 2          # times the votes another person needs to take a name over


class Sight:
    """Who the camera surely sees right now. Written by the faces connection."""

    def __init__(self):
        self.lock = threading.Lock()
        self.names, self.at = [], 0.0

    def saw(self, people: list) -> None:
        with self.lock:
            self.names = [p["name"] for p in people if p.get("match") == "sure"]
            self.at = time.time()

    def clear(self) -> None:
        with self.lock:
            self.names, self.at = [], 0.0

    def one(self):
        """The one enrolled person in view, or None (nobody, several, or stale)."""
        with self.lock:
            if len(self.names) == 1 and time.time() - self.at <= FRESH:
                return self.names[0]
            return None


class Who:
    """One conversation's answer to "which voice is which person"."""

    def __init__(self, sight: Sight, me=None):
        self.sight = sight
        self.first_voice_is_me = me is None
        self.me = me                 # the wearer's speaker number
        self.votes = {}              # speaker -> {name: count}
        self.names = {}              # speaker -> name

    def heard(self, pieces: list) -> bool:
        """Settled speech, as [{"speaker": 0, "text": "..."}]. True if the answer changed."""
        changed = False
        for piece in pieces:
            speaker = piece.get("speaker")
            if speaker is None:
                continue
            if self.me is None and self.first_voice_is_me:
                self.me, changed = speaker, True
                continue
            if speaker == self.me:
                continue
            name = self.sight.one()
            if name is None:
                continue
            tally = self.votes.setdefault(speaker, {})
            tally[name] = tally.get(name, 0) + max(1, len(str(piece.get("text", "")).split()))
            best = max(tally, key=tally.get)
            current = self.names.get(speaker)
            if current is None:
                settled = tally[best] >= ENOUGH
            else:
                settled = best != current and tally[best] >= CLEARLY * tally[current] and tally[best] - tally[current] >= ENOUGH
            if settled:
                self.names[speaker], changed = best, True
        return changed

    def person(self, speaker):
        """"Me", a name, or None."""
        if speaker is None:
            return None
        return "Me" if speaker == self.me else self.names.get(speaker)

    def message(self) -> dict:
        return {"type": "speakers", "me": self.me, "names": {str(s): n for s, n in self.names.items()}}
