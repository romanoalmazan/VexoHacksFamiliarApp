# VexoHacksFamiliarApp

## Faces (server setup)

The server recognises enrolled faces with OpenCV. Once per laptop:

```
python3 -m pip install --user opencv-python-headless
mkdir -p server/models
curl -L -o server/models/yunet.onnx https://github.com/opencv/opencv_zoo/raw/main/models/face_detection_yunet/face_detection_yunet_2023mar.onnx
curl -L -o server/models/sface.onnx https://github.com/opencv/opencv_zoo/raw/main/models/face_recognition_sface/face_recognition_sface_2021dec.onnx
```

Then `python3 server/server.py` as before. In the app: **People & faces** → type the
server address and pairing code → **Look for faces**. Add a person (name, who they are,
a photo or the face in view) and they are recognised from then on.

Camera pictures are compared and thrown away. Per enrolled person the server keeps a
name, a relationship and numbers describing the face (`server/people.json`, not in git).
Only enrol people who agreed. Swipe a person in the app to forget them.

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
3. Familiar → People & faces → Camera: **Meta glasses** → **Link Meta glasses**.
   Meta AI opens, asks, and returns to Familiar.
4. **Look for faces**. The first time, Meta AI asks to allow the camera.

Without glasses, choose **iPhone** as the camera: everything else is the same.

## Web prototype (design)

`web-prototype/` is a clickable prototype of the planned app design (React + TypeScript + Vite):
every screen and flow, light and dark themes, and motion. It runs on demo data, separate from the server.

```
cd web-prototype
npm install
npm run dev        # http://localhost:5173
```

## Reflections
