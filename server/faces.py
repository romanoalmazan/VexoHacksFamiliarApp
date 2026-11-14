# Tells which enrolled person is in a camera picture.
#
# Only people who were enrolled (by themselves or by family) can be recognised. Pictures
# are compared and thrown away: what is kept per person is a name, a relationship and a
# list of numbers describing the face (server/people.json, git-ignored). Those numbers are
# biometric data: enrol only people who agreed, and use forget() when they ask.
#
# Needs: python3 -m pip install opencv-python-headless, and the two model files in
# server/models/ (see the README).
import json
import threading
import time
from pathlib import Path

import cv2
import numpy as np

HERE = Path(__file__).resolve().parent
MODELS = HERE / "models"
PEOPLE_FILE = HERE / "people.json"

# How alike two faces must be (cosine, 0..1). The model's own line for "same person" is
# 0.363. A wrong name does harm, so we only say a name out loud well above that line.
SURE = 0.45
POSSIBLE = 0.363
LONGEST_SIDE = 960           # bigger pictures are shrunk first: faster, and plenty for faces
MAX_PHOTOS = 8               # per person


class FacesError(Exception):
    """A sentence a person can act on."""


class Faces:
    def __init__(self, people_file: Path = PEOPLE_FILE):
        self.people_file = people_file
        self.lock = threading.Lock()            # the models are not safe to use from two threads
        self.detector = None
        self.recogniser = None
        self.people = {}                        # name -> {"relationship": str, "faces": [[float]]}
        try:
            self.people = json.loads(people_file.read_text())
        except (OSError, ValueError):
            pass

    # -- the models -------------------------------------------------------------------

    def load(self) -> None:
        if self.detector is not None:
            return
        yunet, sface = MODELS / "yunet.onnx", MODELS / "sface.onnx"
        if not (yunet.exists() and sface.exists()):
            raise FacesError("The face model files are missing from server/models/. The README says how to get them.")
        self.detector = cv2.FaceDetectorYN.create(str(yunet), "", (320, 320), 0.8)
        self.recogniser = cv2.FaceRecognizerSF.create(str(sface), "")

    def embeddings(self, jpeg: bytes) -> list:
        """One list of numbers per face in the picture, biggest face first."""
        self.load()
        picture = cv2.imdecode(np.frombuffer(jpeg, np.uint8), cv2.IMREAD_COLOR)
        if picture is None:
            raise FacesError("That was not a picture the server could read.")
        height, width = picture.shape[:2]
        scale = LONGEST_SIDE / max(height, width)
        if scale < 1:
            picture = cv2.resize(picture, (int(width * scale), int(height * scale)))
            height, width = picture.shape[:2]
        self.detector.setInputSize((width, height))
        _, found = self.detector.detect(picture)
        if found is None:
            return []
        found = sorted(found, key=lambda face: -face[2] * face[3])
        return [self.recogniser.feature(self.recogniser.alignCrop(picture, face)).flatten().tolist() for face in found]

    # -- what the app asks for -----------------------------------------------------------

    def enrol(self, name: str, relationship: str, jpeg: bytes) -> dict:
        name, relationship = " ".join(str(name).split())[:60], " ".join(str(relationship).split())[:60]
        if not name:
            raise FacesError("Type the person's name first.")
        with self.lock:
            faces = self.embeddings(jpeg)
            if len(faces) != 1:
                raise FacesError("No face found. Hold the camera closer, in good light." if not faces
                                 else "More than one face in the picture. Enrol one person at a time.")
            # "agreed" is when the person registering them confirmed that they agreed.
            person = self.people.setdefault(name, {"relationship": relationship, "faces": [], "agreed": time.time()})
            if relationship:
                person["relationship"] = relationship
            person["faces"] = (person["faces"] + faces)[-MAX_PHOTOS:]
            self.keep()
            return {"name": name, "relationship": person["relationship"], "photos": len(person["faces"])}

    def look(self, jpeg: bytes) -> dict:
        """Who is in the picture. "sure" may be said out loud; "possible" is for the screen only."""
        with self.lock:
            faces = self.embeddings(jpeg)
            people, unknown = {}, 0
            for face in faces:
                name, score = self.closest(face)
                if name is None or score < POSSIBLE:
                    unknown += 1
                elif name not in people or score > people[name]["score"]:
                    people[name] = {"name": name, "relationship": self.people[name]["relationship"],
                                    "match": "sure" if score >= SURE else "possible", "score": round(score, 3)}
            return {"people": sorted(people.values(), key=lambda p: -p["score"]), "unknown": unknown}

    def list(self) -> list:
        with self.lock:
            return [{"name": name, "relationship": person["relationship"], "photos": len(person["faces"])}
                    for name, person in sorted(self.people.items())]

    def forget(self, name: str) -> bool:
        with self.lock:
            gone = self.people.pop(name, None) is not None
            if gone:
                self.keep()
            return gone

    # -- inside --------------------------------------------------------------------------

    def closest(self, face: list):
        best_name, best = None, -1.0
        mine = np.asarray(face, np.float32)
        mine = mine / (np.linalg.norm(mine) or 1)
        for name, person in self.people.items():
            for theirs in person["faces"]:
                theirs = np.asarray(theirs, np.float32)
                score = float(mine @ (theirs / (np.linalg.norm(theirs) or 1)))
                if score > best:
                    best_name, best = name, score
        return best_name, best

    def keep(self) -> None:
        self.people_file.write_text(json.dumps(self.people))
        self.people_file.chmod(0o600)
