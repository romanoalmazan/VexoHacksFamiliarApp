# VexoHacksFamiliarApp

## Faces (server setup)

The server recognises enrolled faces with OpenCV. Once per laptop:

```
python3 -m pip install --user opencv-python-headless
mkdir -p server/models
curl -L -o server/models/yunet.onnx https://github.com/opencv/opencv_zoo/raw/main/models/face_detection_yunet/face_detection_yunet_2023mar.onnx
curl -L -o server/models/sface.onnx https://github.com/opencv/opencv_zoo/raw/main/models/face_recognition_sface/face_recognition_sface_2021dec.onnx
```

Then `python3 server/server.py` as before. In the app: the first-run setup asks for the
server address and pairing code (later: **Settings** → the server row). On the **People**
tab, **Register a person** (name, who they are, their yes, a photo or the face in view) and
they are recognised from then on. **Listen** on the Now tab starts the camera; **Just look
for faces** starts the camera alone.

Camera pictures are compared and thrown away. Per enrolled person the server keeps a
name, a relationship and numbers describing the face (`server/people.json`, not in git).
Only enrol people who agreed. Open a person on the People tab and tap **Forget** to
delete them.

## Voices (server setup)

The wearer registers their own voice in the app (Register my voice), so the server knows
which voice is theirs. Once per laptop:

```
python3 -m pip install --user sherpa-onnx
curl -L -o server/models/voice.onnx "https://github.com/k2-fsa/sherpa-onnx/releases/download/speaker-recongition-models/wespeaker_en_voxceleb_CAM%2B%2B.onnx"
brew install ffmpeg
```

What is kept is a description of the voice (`server/me.json`, not in git), never sound.

## Meta glasses

Uses Meta's Wearables Device Access Toolkit 1.0.1. On the demo iPhone:

1. Pair the glasses in the Meta AI app.
2. Meta AI → Settings → Your glasses → turn on **Developer Mode**.
3. Familiar → Settings → Camera → **Meta glasses** → **Link Meta glasses**.
   Meta AI opens, asks, and returns to Familiar.
4. **Listen** (or **Just look for faces**) on the Now tab. The first time, Meta AI asks to
   allow the camera.

Without glasses, choose **iPhone camera**: everything else is the same.


## Reflections
