# Tests for summaries.py (no network: Gemini is replaced by a fake).
#     python3 -m unittest server/test_summaries.py
import json
import os
import sys
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))
import summaries  # noqa: E402
from profiles import ProfilesError  # noqa: E402

LINES = [{"speaker": 0, "text": "So what are you building?", "person": "Me"},
         {"speaker": 1, "text": "A small arm that sorts screws.", "person": "Maria"},
         {"speaker": 1, "text": "Leo is helping with the camera.", "person": "Maria"},
         {"speaker": 0, "text": "When is the demo?", "person": "Me"}]


def gemini_answer(obj):
    return {"candidates": [{"content": {"parts": [{"text": json.dumps(obj)}]}}]}


class Summarise(unittest.TestCase):
    def test_request_and_answer(self):
        sent = {}

        def fake_call(path, body, timeout=40):
            sent.update(path=path, body=body)
            return gemini_answer({"summary": "  Maria is building   a screw-sorting arm. ", "points": ["Leo helps", ""],
                                  "follow_ups": ["Ask about the demo"]})
        with mock.patch.object(summaries, "call", fake_call):
            got = summaries.summarise(LINES, "gemini-4-hydrogen", summaries.LIVE_PROMPT)
        self.assertEqual(sent["path"], "/models/gemini-4-hydrogen:generateContent")
        config = sent["body"]["generationConfig"]
        self.assertEqual(config["responseSchema"], summaries.SCHEMA)
        self.assertNotIn("temperature", config)                      # Gemini 4: no temperature
        prompt = sent["body"]["contents"][0]["parts"][0]["text"]
        self.assertIn("Maria: A small arm that sorts screws. Leo is helping with the camera.", prompt)
        self.assertEqual(got, {"summary": "Maria is building a screw-sorting arm.", "points": ["Leo helps"],
                               "follow_ups": ["Ask about the demo"], "model": "gemini-4-hydrogen"})

    def test_bad_answer_and_empty_conversation(self):
        with mock.patch.object(summaries, "call", lambda *a, **k: {"candidates": [{"content": {"parts": [{"text": "hi"}]}}]}):
            with self.assertRaises(ProfilesError):
                summaries.summarise(LINES, "m", summaries.LIVE_PROMPT)
        with self.assertRaises(ProfilesError):
            summaries.summarise([], "m", summaries.LIVE_PROMPT)

    def test_final_uses_carbon_unless_configured(self):
        seen = []
        with mock.patch.object(summaries, "summarise", lambda segs, model, prompt, **k: seen.append((model, prompt)) or {}):
            with mock.patch.object(summaries, "env", lambda name: ""):
                summaries.final_summary({"segments": LINES})
            with mock.patch.object(summaries, "env", lambda name: "gemini-4-argon" if name == "GEMINI_FINAL_SUMMARY_MODEL" else ""):
                summaries.final_summary({"segments": LINES})
        self.assertEqual([m for m, _ in seen], ["gemini-4-carbon", "gemini-4-argon"])
        self.assertIs(seen[0][1], summaries.FINAL_PROMPT)


class Live(unittest.TestCase):
    def make(self, lines, fake):
        sent, logged = [], []
        live = summaries.LiveSummaries(lambda: list(lines), sent.append, every=1, min_new=3, summarise=fake, log=logged.append)
        return live, sent, logged

    def test_waits_for_enough_new_lines(self):
        calls = []
        lines = LINES[:2]
        live, sent, _ = self.make(lines, lambda segs, model, prompt: calls.append(len(segs)) or {"summary": "s", "points": [], "follow_ups": [], "model": model})
        self.assertFalse(live.run_once())                            # 2 lines: not yet
        lines.extend(LINES[2:])
        self.assertTrue(live.run_once())                             # 4 lines: a summary
        lines.extend(LINES[:2])
        self.assertFalse(live.run_once())                            # only 2 new since: wait
        self.assertEqual(calls, [4])

    def test_sends_summary_and_counts_lines(self):
        live, sent, _ = self.make(LINES, lambda segs, model, prompt: {"summary": "s", "points": ["p"], "follow_ups": [], "model": model})
        self.assertTrue(live.run_once())
        self.assertEqual((sent[0]["type"], sent[0]["final"], sent[0]["lines"]), ("summary", False, 4))
        self.assertEqual(sent[0]["model"], live.model)
        self.assertFalse(live.run_once())                            # nothing new since

    def test_errors_are_said_once_and_never_reach_the_phone(self):
        def broken(*a, **k):
            raise ProfilesError("Could not reach Gemini.")
        live, sent, logged = self.make(LINES, broken)
        live.run_once()
        live.run_once()
        self.assertEqual(sent, [])
        self.assertEqual(len(logged), 1)


if __name__ == "__main__":
    unittest.main()
