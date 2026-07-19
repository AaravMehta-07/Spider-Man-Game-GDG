# Spider-Man Game GDG

A 90-second motion-controlled arcade game built for the GDG event. Godot renders
the game, while a local Python and MediaPipe service turns webcam poses and hand
gestures into movement, aiming, web attacks, and dodges.

This is an independent fan-inspired project. It is not affiliated with or endorsed
by Marvel, Sony, or Insomniac Games.

## Run on Windows

Requirements:

- Windows 11
- Python 3.11
- Godot 4.7.1 with the matching export templates
- A webcam with enough room to keep both hands in frame

```powershell
git clone https://github.com/AaravMehta-07/Spider-Man-Game-GDG.git
cd Spider-Man-Game-GDG
powershell -ExecutionPolicy Bypass -File .\setup.ps1
python main.py
```

Setup is only needed once. Later runs can use `python main.py` or `run.bat`.
Always start the game through one of these entry points so the vision service is
started with Godot.

Fallback and diagnostic modes:

```powershell
python main.py --keyboard-only
python main.py --simulate-vision
python main.py --setup-check
```

## Camera controls

- Hold both open palms for three seconds to start.
- Lean or step left and right to dodge and move.
- Raise or lower your body to jump or crouch.
- Aim using the average position of both index fingertips.
- Fire by extending the index and pinky while folding the middle and ring fingers.
- After a web attaches, close the hand and pull the arm back.
- Use the web pose with both hands, then pull both arms back for the finisher.

A fist, pinch, open palm, or ordinary aiming pose does not fire a web.

## Keyboard controls

- `A` / `D`: move
- `Space`: jump
- `S`: crouch
- `Q` / `E`: dodge
- `F`: shield
- Mouse: aim and fire
- `P`: pull
- `F4`: switch between camera and keyboard mode

## Docker

Docker provides a repeatable environment for the automated tests and the
simulated Python vision service:

```powershell
docker compose run --rm test
docker compose --profile vision up vision-sim
```

The public event game itself should still be run natively with `python main.py`.
The Godot window needs direct desktop, GPU, audio, and webcam access, which is not
reliable through Docker Desktop on Windows.

## Privacy

Vision runs locally. Camera frames and biometric data are not saved or uploaded.
Only scores, gameplay metrics, and timestamps may be stored in the local
leaderboard.

## Verify and build

```powershell
python -m pytest
python main.py --setup-check
python main.py --simulate-vision --capture-demo --windowed
powershell -ExecutionPolicy Bypass -File .\build.ps1
```

Technical and event setup notes are available in [`docs`](docs).
