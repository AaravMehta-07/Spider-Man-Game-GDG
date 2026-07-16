# WEB//PROTOCOL: SPIDER-SENSE

An original native Windows motion-control arcade mission for AI/ML recruitment events.
A participant uses body movement and hand gestures in front of one webcam to chase
an unseen energy creature through a procedural city, counter it, sling debris, and
finish with a two-hand web pull.

The runtime is offline. Camera frames stay in memory, are never recorded, and are
processed by a separate Python 3.11 process using MediaPipe Tasks. Godot 4.7.1
renders the game and receives normalized input over localhost UDP.

## Hardware

- Windows 11
- Intel Core i7 class CPU, 16 GB RAM
- RTX 4050/4060 laptop GPU or comparable
- One 720p/1080p webcam
- 1920x1080 display or projector and speakers
- Clear 2 x 2 metre participant area

## Required software

- Python 3.11 x64
- Godot 4.7.x and matching export templates
- Git and PowerShell
- No internet connection is needed after setup

## Setup

    powershell -ExecutionPolicy Bypass -File .\setup.ps1

Setup creates .venv, installs pinned Python packages, verifies Godot and export
templates, validates the official local MediaPipe models, regenerates original WAV
assets and textures, runs tests, and exports Build\WebProtocol.exe.

Machine-specific paths are written to ignored config\local.yaml.

## Run

    python main.py

Useful modes:

    python main.py --setup-check
    python main.py --build
    python main.py --windowed
    python main.py --keyboard-only
    python main.py --simulate-vision
    python main.py --simulate-vision --capture-demo --windowed
    python main.py --boss-test --keyboard-only --windowed
    python main.py --camera 1
    python main.py --skip-calibration

The launcher supervises vision and game processes, waits for a health response,
restarts vision once, rotates logs, builds when the export is absent, and terminates
children when the game exits.

## Body controls

- Lean left/right: change lane
- Raise body: jump
- Lower shoulders/hips: crouch
- Fast lateral motion: dodge
- Both wrists raised and close: web shield
- Point with index hand: aim
- Web pose, pinch, or fist release: fire
- Close hand and pull toward body: web pull
- Both hands forward then pull: finisher

Calibration and verification time out safely. Conservative defaults and stronger
aim assistance are used when tracking confidence is low.

## Keyboard fallback

- A / D: move
- Space: jump
- S: crouch
- Q / E: dodge
- F: shield
- Mouse: aim
- Left/right mouse: left/right web
- P: pull
- Enter: begin mission

Operator keys:

- F3: diagnostics
- F4: camera/keyboard mode
- F5 / F6: previous/next camera while operator panel is open
- F7: restart camera
- F8: mirror camera
- F9: VSync
- F11: fullscreen
- M: mute
- R: reset
- C: recalibrate
- B: skip to boss while operator panel is open
- Tab: switch operator pages
- Home: return to attract
- Delete, then Y: clear local leaderboard
- Ctrl+O: operator panel
- Ctrl+Shift+Q, then Y: confirmed quit

Escape never quits the installation.

## Session

The participant session is hard-bounded:

| Time | State |
|---|---|
| 0.0-5.5 | Positioning and calibration |
| 5.5-9.5 | Web verification |
| 9.5-55.0 | Continuous city chase |
| 55.0-58.0 | Seamless boss reveal |
| 58.0-78.0 | The Veil combat |
| 78.0-83.0 | Double-web finisher |
| 83.0-90.0 | Results and reset |

Hero energy reaching zero activates Last Chance Mode and the mission continues.
The finisher uses a timed assist so every participant reaches containment.

## Webcam setup

Place the camera near display centre at chest-to-eye height, 2.2-3.0 metres from
the player. Light the player from the front, avoid a bright window behind them,
and keep the whole body visible with arms extended. See docs/EVENT_SETUP.md.

## Privacy

All inference is local. The application sends only normalized actions and
confidence values to Godot over 127.0.0.1. It does not save video, still frames,
raw landmarks, names, phone numbers, or contact details. The optional local
leaderboard stores only game metrics and a timestamp.

## Branding

Replace files under game/assets/branding while keeping the filenames. The generated
city plate and audio are original project assets. See docs/ASSET_REPLACEMENT.md.

## Troubleshooting

    python main.py --setup-check
    .\.venv\Scripts\python.exe tools\validate_installation.py
    .\.venv\Scripts\python.exe tools\inspect_logs.py

Use --keyboard-only during camera problems. Full remedies are in
docs/TROUBLESHOOTING.md.