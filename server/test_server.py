# Checks the server with the kit's pretend Deepgram: no internet, no real key.
#     python3 -m unittest discover -s server
import asyncio
import json
import os
import sys
import unittest
from pathlib import Path
from unittest import mock

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent / "vexo-open-kit" / "examples" / "test"))

import websockets  # noqa: E402

import server  # noqa: E402
from deepgram_mock import MockDeepgram  # noqa: E402
from diarized import segments, speech  # noqa: E402
from who import Sight, Who  # noqa: E402
import profiles  # noqa: E402


class Segments(unittest.TestCase):
    def test_groups_words_by_speaker(self):
        words = [{"word": "hi", "punctuated_word": "Hi,", "speaker": 0}, {"word": "im", "punctuated_word": "I'm", "speaker": 0},
                 {"word": "sarah", "punctuated_word": "Sarah.", "speaker": 0}, {"word": "nice", "punctuated_word": "Nice!", "speaker": 1},
                 {"word": "yeah", "speaker": 0}]
        self.assertEqual(segments(words), [{"speaker": 0, "text": "Hi, I'm Sarah."}, {"speaker": 1, "text": "Nice!"},
                                           {"speaker": 0, "text": "yeah"}])

    def test_odd_input(self):
        self.assertEqual(segments(None), [])
        self.assertEqual(segments([{"word": "x"}, "junk", {"word": ""}, {"word": "y", "speaker": True}]),
                         [{"speaker": None, "text": "x y"}])


class WhichVoiceIsWho(unittest.TestCase):
    LONG = "hello there how are you"

    def said(self, who, speaker, text=LONG):
        return who.heard([{"speaker": speaker, "text": text}])

    def test_first_voice_is_the_wearer_then_faces_name_the_rest(self):
        sight = Sight()
        who = Who(sight)
        sure = lambda *names: sight.saw([{"name": n, "match": "sure"} for n in names])
        self.assertFalse(who.heard([{"speaker": None, "text": "?"}]))
        sure("Maria")
        self.assertTrue(self.said(who, 0))                  # the wearer, even with Maria in view
        self.assertEqual((who.me, who.names), (0, {}))
        self.assertFalse(self.said(who, 0))
        self.assertFalse(self.said(who, 1, "hi"))           # one word is not enough to name a voice
        self.assertTrue(self.said(who, 1))                  # another voice, Maria in view
        self.assertEqual(who.person(1), "Maria")
        sight.clear()
        self.assertFalse(self.said(who, 1))                 # looked away: she keeps her name
        self.assertEqual(who.person(1), "Maria")
        sure("Maria", "Sam")
        self.assertFalse(self.said(who, 2))                 # two people in view: no guess
        sight.saw([{"name": "Sam", "match": "possible"}])
        self.assertFalse(self.said(who, 2))                 # not sure enough: no guess
        sure("Sam")
        self.assertTrue(self.said(who, 2))
        self.assertFalse(self.said(who, 1, "yeah okay"))    # a glance at Sam while Maria says a little: no flip
        self.assertFalse(self.said(who, 1))                 # Sam 7 words to Maria's 6: still not clearly
        self.assertEqual(who.person(1), "Maria")
        self.assertEqual(who.message(), {"type": "speakers", "me": 0, "names": {"1": "Maria", "2": "Sam"}})
        self.assertEqual([who.person(s) for s in (0, 1, 2, 3, None)], ["Me", "Maria", "Sam", None, None])
        self.assertTrue(self.said(who, 1, self.LONG + " " + self.LONG))    # 17 to 6: it was Sam all along
        self.assertEqual(who.person(1), "Sam")

    def test_old_sightings_do_not_count(self):
        sight = Sight()
        who = Who(sight)
        sight.saw([{"name": "Maria", "match": "sure"}])
        sight.at -= 60
        self.said(who, 0)
        self.assertFalse(self.said(who, 1))
        self.assertIsNone(who.person(1))


class EndToEnd(unittest.TestCase):
    def setUp(self):
        patch = mock.patch.object(server, "VOICE", None)      # as if no voice is registered on this laptop
        patch.start()
        self.addCleanup(patch.stop)

    def run_phone(self, code_sent, packets=120):
        async def go():
            got = []
            async with websockets.serve(lambda phone: server.stream(phone, "123456"), "127.0.0.1", 0, max_size=4096) as listening:
                port = listening.sockets[0].getsockname()[1]
                async with websockets.connect("ws://127.0.0.1:%d" % port,
                                              additional_headers={"Authorization": "Bearer " + code_sent}) as phone:
                    try:
                        first = json.loads(await asyncio.wait_for(phone.recv(), 5))
                        got.append(first)
                        for _ in range(packets):
                            await phone.send(b"\x01" * 40)
                        while len(got) < 3:
                            got.append(json.loads(await asyncio.wait_for(phone.recv(), 5)))
                    except websockets.ConnectionClosed as closed:
                        got.append(closed.rcvd.code if closed.rcvd else None)
            await asyncio.sleep(0.3)
            return got
        return asyncio.run(go())

    def test_text_comes_back(self):
        with MockDeepgram() as deepgram, mock.patch.object(speech.DeepgramSpeech, "URL", deepgram.url), \
                mock.patch.dict(os.environ, {"DEEPGRAM_API_KEY": "made-up-key"}), mock.patch.object(server, "save", return_value=None) as saved:
            got = self.run_phone("123456")
            self.assertEqual(got[0], {"type": "ready", "knows_wearer": False})
            # The pretend Deepgram gives no speaker numbers, so nobody is known: words withheld.
            self.assertTrue(all(m["type"] == "transcript" and m["segments"][0] == {"speaker": None, "text": "", "hidden": True} for m in got[1:]))
            self.assertIn("diarize=true", deepgram.requests[0]["path"])
            self.assertIn("mip_opt_out=true", deepgram.requests[0]["path"])
            self.assertGreater(len(deepgram.sound), 100)
            saved.assert_called_once()

    def test_wrong_code_is_turned_away(self):
        with MockDeepgram() as deepgram, mock.patch.object(speech.DeepgramSpeech, "URL", deepgram.url), \
                mock.patch.dict(os.environ, {"DEEPGRAM_API_KEY": "made-up-key"}):
            self.assertEqual(self.run_phone("000000"), [4401])
            self.assertEqual(deepgram.sound, [])

    def test_no_key_says_so(self):
        with mock.patch.dict(os.environ, {"DEEPGRAM_API_KEY": ""}), mock.patch.object(speech.os, "getcwd", return_value="/nonexistent"):
            got = self.run_phone("123456", packets=0)
            self.assertEqual(got[0]["type"], "error")
            self.assertIn("Deepgram key", got[0]["message"])


class FakeEars:
    """Stands in for Deepgram: the wearer speaks, then a second voice, twice."""
    error = None
    script = [(0, "Hello Maria."), (1, "Hello dad."), (2, "Tea, anyone?"), (1, "I brought the photos.")]

    def __init__(self, on_segments, on_words=None):
        self.on_segments, self.on_words, self.fed = on_segments, on_words, 0

    def start(self):
        return self

    def feed(self, packet):
        if self.fed < len(self.script):
            speaker, text = self.script[self.fed]
            self.on_segments([{"speaker": speaker, "text": text}], True)
        self.fed += 1

    def stop(self):
        pass


class VoicesGetNames(unittest.TestCase):
    def test_a_conversation_with_maria_in_view(self):
        async def go():
            got = []
            async with websockets.serve(lambda phone: server.stream(phone, "123456"), "127.0.0.1", 0) as listening:
                port = listening.sockets[0].getsockname()[1]
                async with websockets.connect("ws://127.0.0.1:%d" % port, additional_headers={"Authorization": "Bearer 123456"}) as phone:
                    got.append(json.loads(await asyncio.wait_for(phone.recv(), 5)))
                    for _ in range(4):
                        await phone.send(b"\x01" * 40)
                    while len(got) < 9:
                        got.append(json.loads(await asyncio.wait_for(phone.recv(), 5)))
            await asyncio.sleep(0.3)
            return got
        server.SIGHT.saw([{"name": "Maria", "match": "sure"}])
        try:
            # remember() would send the text to the real Gemini and write the real profiles.
            with mock.patch.object(server, "DiarizedSpeech", FakeEars), mock.patch.object(server, "SAVE_TO", Path(self.folder.name)), \
                    mock.patch.object(server, "remember") as remembered:
                got = asyncio.run(go())
        finally:
            server.SIGHT.clear()
        hidden = lambda speaker: {"speaker": speaker, "text": "", "hidden": True}
        self.assertEqual([m for m in got if m["type"] == "speakers"],
                         [{"type": "speakers", "me": 0, "names": {}}, {"type": "speakers", "me": 0, "names": {"1": "Maria"}}])
        # Live: Maria's first words and the stranger's are withheld...
        self.assertEqual([m["segments"][0] for m in got if m["type"] == "transcript"],
                         [{"speaker": 0, "text": "Hello Maria."}, hidden(1), hidden(2), {"speaker": 1, "text": "I brought the photos."}])
        # ...then Maria is recognised, and hers are shown. The stranger's never are.
        everything = [m["segments"] for m in got if m["type"] == "all"]
        self.assertEqual(everything[0], [{"speaker": 0, "text": "Hello Maria."}])
        self.assertEqual(everything[1], [{"speaker": 0, "text": "Hello Maria."}, {"speaker": 1, "text": "Hello dad."}, hidden(2),
                                         {"speaker": 1, "text": "I brought the photos."}])
        saved = json.loads(next(Path(self.folder.name).glob("*.json")).read_text())
        self.assertEqual(saved["people"], ["Maria"])
        self.assertEqual(remembered.call_args[0][0]["people"], ["Maria"])
        self.assertEqual([(line["person"], line["text"]) for line in saved["segments"]],
                         [("Me", "Hello Maria."), ("Maria", "Hello dad."), ("Maria", "I brought the photos.")])
        self.assertNotIn("Tea", json.dumps(saved))

    def test_nobody_registered_leaves_nothing(self):
        who = Who(Sight())
        who.heard([{"speaker": 0, "text": "Hello."}])
        lines = [{"speaker": 0, "text": "Hello.", "time": 1.0}, {"speaker": 1, "text": "Who are you?", "time": 2.0}]
        with mock.patch.object(server, "SAVE_TO", Path(self.folder.name) / "none"):
            self.assertIsNone(server.save(0.0, lines, who))
        self.assertFalse((Path(self.folder.name) / "none").exists())

    def test_the_registered_voice_is_the_wearer_even_speaking_second(self):
        class Ears(FakeEars):
            script = [(1, "Hello dad, how are you today?"), (0, "Hello Maria, I am well."), (1, "I brought the photos."), (0, "Lovely.")]

            def feed(self, packet):
                if self.fed < len(self.script):
                    speaker = self.script[self.fed][0]
                    self.on_words([{"speaker": speaker, "start": self.fed * 3.0, "end": self.fed * 3.0 + 3.0}])
                super().feed(packet)

        class KnownVoice:
            registered = True

            def like_me(self, packets):
                return 0.8 if packets and packets[0] == b"me" else 0.1

        async def go():
            got = []
            async with websockets.serve(lambda phone: server.stream(phone, "123456"), "127.0.0.1", 0) as listening:
                port = listening.sockets[0].getsockname()[1]
                async with websockets.connect("ws://127.0.0.1:%d" % port, additional_headers={"Authorization": "Bearer 123456"}) as phone:
                    got.append(json.loads(await asyncio.wait_for(phone.recv(), 5)))
                    for packet in (b"maria", b"me", b"maria", b"me"):
                        await phone.send(packet * 150 if False else packet)
                        await asyncio.sleep(0.15)
                    try:
                        while True:
                            got.append(json.loads(await asyncio.wait_for(phone.recv(), 1)))
                    except asyncio.TimeoutError:
                        pass
            await asyncio.sleep(0.3)
            return got
        # One packet stands for three seconds here, so each voice's "sound" is its own packet.
        import voice
        server.SIGHT.saw([{"name": "Maria", "match": "sure"}])
        try:
            with mock.patch.object(server, "DiarizedSpeech", Ears), mock.patch.object(server, "SAVE_TO", Path(self.folder.name)), \
                    mock.patch.object(server, "remember"), mock.patch.object(server, "VOICE", KnownVoice()), \
                    mock.patch.object(voice, "PACKET", 3.0), mock.patch.object(server.SIGHT, "one", lambda: "Maria"):
                got = asyncio.run(go())
        finally:
            server.SIGHT.clear()
        self.assertEqual(got[0], {"type": "ready", "knows_wearer": True})
        self.assertEqual([m for m in got if m["type"] == "speakers"][-1], {"type": "speakers", "me": 0, "names": {"1": "Maria"}})
        saved = json.loads(next(Path(self.folder.name).glob("*.json")).read_text())
        self.assertEqual([(line["person"], line["text"]) for line in saved["segments"]],
                         [("Maria", "Hello dad, how are you today?"), ("Me", "Hello Maria, I am well."), ("Maria", "I brought the photos."), ("Me", "Lovely.")])

    def setUp(self):
        import tempfile
        self.folder = tempfile.TemporaryDirectory()
        patch = mock.patch.object(server, "VOICE", None)
        patch.start()
        self.addCleanup(patch.stop)

    def tearDown(self):
        self.folder.cleanup()


class MyVoice(unittest.TestCase):
    def test_which_voice_is_mine(self):
        import voice

        class Known:
            def like_me(self, packets):
                return {b"a": 0.2, b"b": 0.7, b"c": 0.68}[packets[-1]]
        ears = voice.Listening(Known())
        for packet in (b"a",) * 200 + (b"b",) * 200 + (b"c",) * 200:
            ears.packet(packet)
        word = lambda speaker, start, end: {"speaker": speaker, "start": start, "end": end}
        self.assertEqual(ears.words([word(0, 0.0, 1.0), {"speaker": None}, "junk"]), [])       # too little said
        self.assertEqual(ears.words([word(0, 1.0, 3.9), word(1, 4.1, 7.9)]), [0, 1])
        self.assertEqual(ears.words([word(0, 3.9, 3.95)]), [])                                   # just compared
        self.assertAlmostEqual(ears.compare(0), 0.2)
        self.assertIsNone(ears.me())                                                            # nobody sounds like the wearer yet
        self.assertAlmostEqual(ears.compare(1), 0.7)
        self.assertEqual(ears.me(), 1)
        ears.words([word(2, 8.1, 11.9)])
        ears.compare(2)
        self.assertIsNone(ears.me())                                                            # two voices equally alike: no guess

    def test_set_me_takes_the_name_off_the_wearer(self):
        sight = Sight()
        who = Who(sight, first_voice_is_me=False)
        sight.saw([{"name": "Maria", "match": "sure"}])
        self.assertTrue(who.heard([{"speaker": 0, "text": "hello there how are you"}]))        # not known to be the wearer yet
        self.assertEqual((who.me, who.person(0)), (None, "Maria"))
        self.assertTrue(who.set_me(0))
        self.assertFalse(who.set_me(0))
        self.assertEqual((who.person(0), who.names), ("Me", {}))

    def test_registering_over_the_wire(self):
        class Fake:
            registered = False

            def register(self, packets):
                if len(packets) < 3:
                    raise server.VoiceError("That was only 0 seconds. Read for at least 6.")
                self.registered = True
                return {"registered": True, "seconds": 9.0}

            def forget(self):
                self.registered = False

        async def go(code):
            got = []
            async with websockets.serve(lambda phone: server.route(phone, "123456"), "127.0.0.1", 0) as listening:
                port = listening.sockets[0].getsockname()[1]
                async with websockets.connect("ws://127.0.0.1:%d/voice" % port, additional_headers={"Authorization": "Bearer " + code}) as phone:
                    try:
                        got.append(json.loads(await asyncio.wait_for(phone.recv(), 5)))
                        for message in ('{"type": "done"}', b"x", b"x", b"x", '{"type": "done"}', '{"type": "forget"}', "junk"):
                            await phone.send(message)
                            if isinstance(message, str):
                                got.append(json.loads(await asyncio.wait_for(phone.recv(), 5)))
                    except websockets.ConnectionClosed as closed:
                        got.append(closed.rcvd.code if closed.rcvd else None)
            return got
        with mock.patch.object(server, "VOICE", Fake()):
            got = asyncio.run(go("123456"))
            self.assertEqual(asyncio.run(go("000000")), [4401])
        self.assertEqual(got[0], {"type": "ready", "registered": False})
        self.assertEqual(got[1]["type"], "error")
        self.assertEqual(got[2], {"type": "voice", "registered": True, "seconds": 9.0})
        self.assertEqual(got[3], {"type": "voice", "registered": False})
        self.assertEqual(got[4]["type"], "error")


class Remembering(unittest.TestCase):
    TALK = {"ended": 1000.0, "people": ["Maria"], "segments": [
        {"speaker": 0, "person": "Me", "text": "Hello Maria."}, {"speaker": 1, "person": "Maria", "text": "Leo graduated!"},
        {"speaker": 1, "person": "Maria", "text": "I brought photos."}, {"speaker": 2, "person": None, "text": "Tea?"}]}

    def gemini(self, people):
        def call(path, body=None, timeout=40):
            self.asked.append((path, body))
            return {"candidates": [{"content": {"parts": [{"text": json.dumps({"people": people})}]}}]}
        return call

    def setUp(self):
        import tempfile
        self.folder, self.asked = tempfile.TemporaryDirectory(), []
        self.book = profiles.Profiles(Path(self.folder.name) / "profiles.json")

    def tearDown(self):
        self.folder.cleanup()

    def test_a_conversation_becomes_a_profile(self):
        answer = {"Maria": {"recall": "Last time, she told you Leo graduated.", "facts": ["Grandson Leo graduated", "grandson leo graduated"],
                            "follow_ups": ["Ask to see the photos", "x", "y"]}, "Stranger": {"recall": "no"}}
        with mock.patch.object(profiles, "call", self.gemini(answer)), mock.patch.object(profiles, "_model", "gemini-test"):
            self.assertEqual(self.book.learn(self.TALK), ["Maria"])
            self.assertEqual(self.book.learn(dict(self.TALK, people=[])), [])          # nobody named: Gemini not asked
        self.assertEqual(len(self.asked), 1)
        path, body = self.asked[0]
        self.assertEqual(path, "/models/gemini-test:generateContent")
        prompt = body["contents"][0]["parts"][0]["text"]
        self.assertIn("Me: Hello Maria.\nMaria: Leo graduated! I brought photos.\nSpeaker 2: Tea?", prompt)
        maria = profiles.Profiles(self.book.file).get("Maria")
        self.assertEqual(maria["recall"], "Last time, she told you Leo graduated.")
        self.assertEqual(maria["facts"], ["Grandson Leo graduated"])
        self.assertEqual(len(maria["follow_ups"]), 2)
        self.assertEqual(maria["last_seen"], 1000.0)
        self.assertEqual(self.book.get("Stranger"), {})
        self.book.forget("Maria")
        self.assertEqual(profiles.Profiles(self.book.file).get("Maria"), {})

    def test_a_bad_answer_changes_nothing(self):
        with mock.patch.object(profiles, "call", lambda *a, **k: {"candidates": []}), mock.patch.object(profiles, "_model", "gemini-test"):
            with self.assertRaises(profiles.ProfilesError):
                self.book.learn(self.TALK)
        self.assertEqual(self.book.get("Maria"), {})

    def test_no_key_says_so_and_picks_newest_flash(self):
        with mock.patch.dict(os.environ, {"GEMINI_API_KEY": "", "GEMINI_MODEL": ""}), mock.patch.object(profiles.os, "getcwd", return_value="/nonexistent"):
            with self.assertRaises(profiles.ProfilesError) as raised:
                profiles.call("/models")
            self.assertIn("GEMINI_API_KEY", str(raised.exception))
            listed = {"models": [{"name": "models/" + n, "supportedGenerationMethods": ["generateContent"]} for n in
                                 ("gemini-2.5-flash", "gemini-4.0-pro", "gemini-4.0-flash", "gemini-4.0-flash-lite", "gemini-4.0-flash-image")]
                      + [{"name": "models/gemini-5-embedding", "supportedGenerationMethods": ["embedContent"]}]}
            with mock.patch.object(profiles, "call", lambda *a, **k: listed), mock.patch.object(profiles, "_model", None):
                self.assertEqual(profiles.model(), "gemini-4.0-flash")
        profiles._model = None


class FakeEngine:
    """Stands in for faces.Faces: no OpenCV, no model files."""
    def __init__(self):
        self.people = {}

    def load(self):
        pass

    def enrol(self, name, relationship, jpeg):
        if jpeg != b"one face":
            raise server_faces_error()("No face found. Hold the camera closer, in good light.")
        self.people[name] = relationship
        return {"name": name, "relationship": relationship, "photos": 1}

    def look(self, jpeg):
        return {"people": [{"name": n, "relationship": r, "match": "sure", "score": 0.9} for n, r in self.people.items()], "unknown": 0}

    def list(self):
        return [{"name": n, "relationship": r, "photos": 1} for n, r in self.people.items()]

    def forget(self, name):
        return self.people.pop(name, None) is not None


def server_faces_error():
    from faces import FacesError
    return FacesError


@unittest.skipUnless(__import__("importlib").util.find_spec("cv2"), "OpenCV is not installed")
class FacesOverTheWire(unittest.TestCase):
    def talk(self, code_sent, messages):
        async def go():
            got = []
            async with websockets.serve(lambda phone: server.route(phone, "123456"), "127.0.0.1", 0, max_size=2 ** 21) as listening:
                port = listening.sockets[0].getsockname()[1]
                async with websockets.connect("ws://127.0.0.1:%d/faces" % port,
                                              additional_headers={"Authorization": "Bearer " + code_sent}) as phone:
                    try:
                        got.append(json.loads(await asyncio.wait_for(phone.recv(), 5)))
                        for message in messages:
                            await phone.send(message)
                            got.append(json.loads(await asyncio.wait_for(phone.recv(), 5)))
                    except websockets.ConnectionClosed as closed:
                        got.append(closed.rcvd.code if closed.rcvd else None)
            return got
        with mock.patch.object(server, "_faces", FakeEngine()):
            return asyncio.run(go())

    def test_enrol_look_forget(self):
        import base64
        enrol = lambda picture, consent=True: json.dumps({"type": "enrol", "name": "Maria", "relationship": "daughter", "consent": consent,
                                                          "jpeg": base64.b64encode(picture).decode()})
        got = self.talk("123456", [b"a picture", enrol(b"no face"), enrol(b"one face"), b"a picture",
                                   json.dumps({"type": "forget", "name": "Maria"}), "junk", enrol(b"one face", consent=False)])
        self.assertEqual(got[0], {"type": "ready"})
        self.assertEqual(got[1], {"type": "faces", "people": [], "unknown": 0})
        self.assertEqual(got[2]["type"], "error")
        self.assertEqual(got[3], {"type": "enrolled", "name": "Maria", "relationship": "daughter", "photos": 1})
        self.assertEqual(got[4]["people"][0]["name"], "Maria")
        self.assertEqual(got[5], {"type": "people", "people": []})
        self.assertEqual(got[6]["type"], "error")
        self.assertIn("agreed", got[7]["message"])                  # no yes, no registration

    def test_wrong_code_is_turned_away(self):
        self.assertEqual(self.talk("000000", [b"a picture"]), [4401])


class Matching(unittest.TestCase):
    @unittest.skipUnless(__import__("importlib").util.find_spec("cv2"), "OpenCV is not installed")
    def test_strict_about_names(self):
        import tempfile
        from faces import Faces
        with tempfile.TemporaryDirectory() as folder:
            engine = Faces(Path(folder) / "people.json")
            pictures = {b"maria": [[1.0, 0.0, 0.0]], b"alike": [[0.8, 0.6, 0.0]], b"bit alike": [[0.4, 0.916, 0.0]],
                        b"stranger": [[0.0, 0.0, 1.0]], b"nobody": [], b"two": [[1.0, 0.0, 0.0], [0.0, 0.0, 1.0]]}
            with mock.patch.object(Faces, "embeddings", lambda self, jpeg: pictures[jpeg]):
                self.assertEqual(engine.enrol(" Maria ", "daughter", b"maria")["name"], "Maria")
                self.assertEqual(engine.look(b"alike")["people"][0]["match"], "sure")
                self.assertEqual(engine.look(b"bit alike")["people"][0]["match"], "possible")
                self.assertEqual(engine.look(b"stranger"), {"people": [], "unknown": 1})
                self.assertEqual(engine.look(b"two")["unknown"], 1)
                for bad in (b"nobody", b"two"):
                    with self.assertRaises(Exception):
                        engine.enrol("Sam", "", bad)
                self.assertEqual(Faces(Path(folder) / "people.json").list(), [{"name": "Maria", "relationship": "daughter", "photos": 1}])
                self.assertTrue(engine.forget("Maria"))
                self.assertEqual(engine.look(b"maria"), {"people": [], "unknown": 1})


if __name__ == "__main__":
    unittest.main()
