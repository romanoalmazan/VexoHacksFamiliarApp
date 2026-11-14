# Familiar's server: the iPhone app sends the band's sound here, this program sends it on
# to Deepgram, and the text comes back to the phone labelled by speaker.
#
#     python3 server/server.py              (start it in the familiar/ folder)
#
# The Deepgram key lives ONLY here (environment variable DEEPGRAM_API_KEY, or the .env
# file in the folder you start this in). It never goes into the app.
#
# While a phone is streaming, everything the band's microphone hears goes over the
# internet to Deepgram, a company: tell the people near the band.
#
#   phone -> server : binary messages, one Opus packet each (as the band sent them)
#   server -> phone : JSON text messages
#       {"type": "ready"}
#       {"type": "transcript", "final": true|false, "segments": [{"speaker": 0, "text": "..."}]}
#       {"type": "speakers", "me": 0, "names": {"1": "Maria"}}   which voice is which person
#       {"type": "all", "segments": [...]}       everything settled so far, sent when a voice gets a name
#       {"type": "error", "message": "..."}                       (see who.py for the rules)
#
# ONLY REGISTERED PEOPLE ARE RECORDED. Words are kept, shown and remembered only when the
# voice is the wearer's or belongs to a registered person the camera recognised. Anyone
# else's words come to the phone as {"speaker": 2, "text": "", "hidden": true}, are never
# printed or saved, and are dropped when the conversation ends. A conversation with no
# registered person in it leaves nothing behind. (Deepgram still hears the whole room to
# make the text: that cannot be avoided with one microphone.)
#
# Faces use a second connection to the same port, at the path /faces (same pairing code):
#   phone -> server : a binary message = one JPEG camera picture: who is in it?
#                     {"type": "enrol", "name": "...", "relationship": "...", "consent": true, "jpeg": "<base64>"}
#                         (registers a person; refused unless consent is true)
#                     {"type": "people"}  ·  {"type": "forget", "name": "..."}
#   server -> phone : {"type": "faces", "people": [{"name", "relationship", "match": "sure"|"possible"}], "unknown": 0}
#                     {"type": "enrolled", "name", "relationship", "photos"}
#                     {"type": "people", "people": [{"name", "relationship", "photos", "recall", "facts", "follow_ups", "last_seen"}]}
#                     ("recall" is one sentence about the last conversation; people in "faces" carry it too)
#                     {"type": "error", "message": "..."}
# Pictures are compared and thrown away. See faces.py for what is kept.
import argparse
import asyncio
import base64
import binascii
import hmac
import json
import secrets
import socket
import time
from pathlib import Path

import websockets

from diarized import DiarizedSpeech, speech
from profiles import Profiles, ProfilesError, env as setting
from who import Sight, Who

HERE = Path(__file__).resolve().parent
CODE_FILE = HERE / ".pairing-code"                 # our own code, not a service key; git-ignored
SAVE_TO = HERE.parent / "conversations"            # text only, never sound; git-ignored


PROFILES = Profiles()                              # what each person last talked about (Gemini)
SIGHT = Sight()                                    # who the camera sees: faces() writes, stream() reads


def pairing_code() -> str:
    """A code the app must show before it may stream. Made once, kept between runs."""
    try:
        code = CODE_FILE.read_text().strip()
        if len(code) >= 6:
            return code
    except OSError:
        pass
    code = "%06d" % secrets.randbelow(10 ** 6)
    CODE_FILE.write_text(code + "\n")
    CODE_FILE.chmod(0o600)
    return code


def save(started: float, lines: list, who: Who):
    """Keeps the wearer's and registered people's words. Nothing at all if no registered
    person took part."""
    people = sorted(set(who.names.values()))
    if not people:
        if lines:
            print("Nobody registered took part: nothing was kept.")
        return None
    kept = [dict(line, person=who.person(line["speaker"])) for line in lines if who.person(line["speaker"])]
    dropped = len(lines) - len(kept)
    SAVE_TO.mkdir(exist_ok=True)
    name = time.strftime("%Y-%m-%d_%H-%M-%S", time.localtime(started)) + ".json"
    conversation = {"started": started, "ended": time.time(), "people": people, "segments": kept}
    with open(SAVE_TO / name, "w", encoding="utf-8") as f:
        json.dump(conversation, f, indent=1)
    print("Saved the conversation (text only) to conversations/%s%s" % (
        name, ". %d line(s) from people who are not registered were not kept." % dropped if dropped else ""))
    return conversation


def remember(conversation) -> None:
    """After a conversation: Gemini works out what to remember about each named person."""
    if not conversation or not conversation.get("people"):
        return
    try:
        updated = PROFILES.learn(conversation)
        for name in updated:
            print("Remembered about %s: %s" % (name, PROFILES.get(name).get("recall", "(nothing new)")))
    except ProfilesError as problem:
        print("No profiles from this conversation. %s" % problem)


async def stream(phone, code: str) -> None:
    given = phone.request.headers.get("Authorization", "")
    if not hmac.compare_digest(given.encode(), ("Bearer " + code).encode()):
        await phone.close(4401, "wrong pairing code")
        return

    loop = asyncio.get_running_loop()
    outbox: asyncio.Queue = asyncio.Queue()
    started, lines = time.time(), []
    who = Who(SIGHT)

    def shown(pieces):
        """Words of the wearer and of registered people as they are; anyone else's withheld."""
        return [piece if who.person(piece["speaker"]) else {"speaker": piece["speaker"], "text": "", "hidden": True}
                for piece in pieces]

    def on_segments(pieces, final):                 # called on the Deepgram client's thread
        changed = False
        if final:
            for piece in pieces:
                lines.append({"speaker": piece["speaker"], "text": piece["text"], "time": time.time()})
            changed = who.heard(pieces)
        loop.call_soon_threadsafe(outbox.put_nowait, {"type": "transcript", "final": final, "segments": shown(pieces)})
        if changed:
            # A voice just got a name: what it said before can be shown now.
            loop.call_soon_threadsafe(outbox.put_nowait, who.message())
            loop.call_soon_threadsafe(outbox.put_nowait, {"type": "all", "final": False, "segments": shown(
                [{"speaker": line["speaker"], "text": line["text"]} for line in lines])})

    try:
        # start() blocks while it connects, so it runs on a helper thread.
        ears = await loop.run_in_executor(None, lambda: DiarizedSpeech(on_segments).start())
    except speech.VexoError as problem:
        # The kit's sentences say what to do and never contain the key.
        print("Cannot start: %s" % problem)
        await phone.send(json.dumps({"type": "error", "message": str(problem)}))
        await phone.close(1011, "speech engine not available")
        return

    print("A phone is streaming. Text:")
    await phone.send(json.dumps({"type": "ready"}))

    async def to_phone():
        while True:
            message = await outbox.get()
            if message["type"] == "speakers":
                print("  (voices: %s)" % ", ".join(["speaker %s is the wearer" % message["me"]] +
                                                   ["speaker %s is %s" % pair for pair in message["names"].items()]))
            elif message["type"] == "transcript" and message["final"]:
                for piece in message["segments"]:
                    if piece.get("hidden"):
                        print("  [not registered] (not kept)")
                    else:
                        print("  [%s] %s" % (who.person(piece["speaker"]), piece["text"]))
            await phone.send(json.dumps(message))

    sender = asyncio.create_task(to_phone())
    try:
        async for packet in phone:
            if isinstance(packet, (bytes, bytearray)) and 0 < len(packet) <= 4096:
                ears.feed(bytes(packet))
                if ears.error:
                    await phone.send(json.dumps({"type": "error", "message": "Deepgram stopped listening. Start again."}))
                    break
    except websockets.ConnectionClosed:
        pass
    finally:
        try:
            await loop.run_in_executor(None, ears.stop)     # waits for the last words
        except speech.VexoError:
            pass
        await asyncio.sleep(0.1)                            # let the last words reach the phone
        sender.cancel()
        conversation = save(started, lines, who)
        await loop.run_in_executor(None, remember, conversation)
        print("The phone stopped streaming.")


_faces = None


def face_engine():
    """Made on first use, so the server still runs for sound alone if OpenCV is missing."""
    global _faces
    if _faces is None:
        from faces import Faces
        _faces = Faces()
    return _faces


async def faces(phone, code: str) -> None:
    given = phone.request.headers.get("Authorization", "")
    if not hmac.compare_digest(given.encode(), ("Bearer " + code).encode()):
        await phone.close(4401, "wrong pairing code")
        return
    loop = asyncio.get_running_loop()
    try:
        engine = face_engine()
        from faces import FacesError
        await loop.run_in_executor(None, engine.load)
    except Exception as problem:                              # no OpenCV, or no model files
        print("Faces cannot start: %s" % problem)
        await phone.send(json.dumps({"type": "error", "message": "The server cannot recognise faces yet: %s" % problem}))
        await phone.close(1011, "face engine not available")
        return

    def answer(message) -> dict:                              # runs on a helper thread
        if isinstance(message, (bytes, bytearray)):
            seen = engine.look(bytes(message))
            SIGHT.saw(seen["people"])
            for person in seen["people"]:
                person["recall"] = PROFILES.get(person["name"]).get("recall", "")
            return dict(seen, type="faces")
        try:
            asked = json.loads(message)
            kind = asked.get("type")
        except (ValueError, AttributeError):
            raise FacesError("The server did not understand that message.")
        if kind == "enrol":
            try:
                jpeg = base64.b64decode(asked.get("jpeg") or "", validate=True)
            except (binascii.Error, ValueError, TypeError):
                raise FacesError("That was not a picture the server could read.")
            if asked.get("consent") is not True:
                raise FacesError("Confirm that they (or their family) agreed before registering them.")
            done = dict(engine.enrol(asked.get("name") or "", asked.get("relationship") or "", jpeg), type="enrolled")
            print("Registered a face for %s (%d photo(s))." % (done["name"], done["photos"]))
            return done
        if kind == "forget":
            engine.forget(str(asked.get("name")))
            PROFILES.forget(str(asked.get("name")))
        elif kind != "people":
            raise FacesError("The server did not understand that message.")
        people = engine.list()
        for person in people:
            profile = PROFILES.get(person["name"])
            person.update(recall=profile.get("recall", ""), facts=profile.get("facts", []),
                          follow_ups=profile.get("follow_ups", []), last_seen=profile.get("last_seen"))
        return {"type": "people", "people": people}

    print("A phone's camera is connected for faces.")
    await phone.send(json.dumps({"type": "ready"}))
    try:
        async for message in phone:
            try:
                reply = await loop.run_in_executor(None, answer, message)
            except FacesError as problem:
                reply = {"type": "error", "message": str(problem)}
            await phone.send(json.dumps(reply))
    except websockets.ConnectionClosed:
        pass
    SIGHT.clear()
    print("The phone's camera disconnected.")


async def route(phone, code: str) -> None:
    if phone.request.path.split("?")[0].rstrip("/") == "/faces":
        await faces(phone, code)
    else:
        await stream(phone, code)


def addresses(port: int) -> list:
    found = ["ws://%s.local:%d" % (socket.gethostname().split(".")[0], port)]
    try:
        probe = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        probe.connect(("10.255.255.255", 1))                # sends nothing: only picks the Wi-Fi address
        found.append("ws://%s:%d" % (probe.getsockname()[0], port))
        probe.close()
    except OSError:
        pass
    return found


async def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8765)
    port = parser.parse_args().port
    code = pairing_code()
    try:
        speech.find_key()
        print("Deepgram key: found.")
    except speech.VexoError as problem:
        print("No Deepgram key yet, so there will be no text. %s" % problem)
    print("Gemini key: found." if setting("GEMINI_API_KEY") else
          "No Gemini key yet, so nothing is remembered about people. Put GEMINI_API_KEY=your-key in .env.")
    print("Familiar server is running. In the app, under Live transcript, type:")
    for address in addresses(port):
        print("    Server:        %s" % address)
    print("    Pairing code:  %s" % code)
    print("Phone and laptop must be on the same Wi-Fi. Stop with Ctrl+C.")
    # Camera pictures are far bigger than sound packets; stream() still ignores big sound packets.
    async with websockets.serve(lambda phone: route(phone, code), "0.0.0.0", port, max_size=2 * 1024 * 1024):
        await asyncio.Future()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\nStopped.")
