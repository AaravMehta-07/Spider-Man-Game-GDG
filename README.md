# Spider-Man Game GDG

An original 90-second motion-controlled superhero arcade game for Windows. Godot
renders the game while a local Python and MediaPipe vision service turns webcam
poses and hand gestures into movement, aiming, web attacks, and air-written names.

This is an independent fan-inspired project and is not affiliated with or endorsed
by Marvel, Sony, or Insomniac Games.

## What You Need

- Windows 11
- Python 3.11
- Godot 4.7.x with matching export templates
- A webcam and enough room to stand with both arms visible

## Setup

```powershell
git clone https://github.com/AaravMehta-07/Spider-Man-Game-GDG.git
cd Spider-Man-Game-GDG
powershell -ExecutionPolicy Bypass -File .\setup.ps1
```

## Run

```powershell
python main.py
```

You can also double-click `run.bat`. Always launch through Python or `run.bat` so
the local vision service starts with the Godot game.

Useful fallback modes:

```powershell
python main.py --keyboard-only
python main.py --simulate-vision
python main.py --setup-check
```

## Camera Controls

- Hold both open palms for 3 seconds to begin.
- Close either fist and move it to air-write one uppercase name letter.
- Open the hand to lift the pen.
- Pinch to accept the predicted letter.
- Hold both fists to clear or undo.
- Hold both palms open to confirm the name and start the mission.
- Move or lean left and right to dodge.
- Raise or lower your body to jump or crouch.
- Aim with the average position of both hands.
- Use the web pose, pinch, or close a fist to fire and attack.
- Pull a closed fist toward your body after a web attaches.
- Push both hands forward and pull to perform the finisher.

The game displays the active gesture and keyboard fallback during play.

## Keyboard Controls

- `A` / `D`: move
- `Space`: jump
- `S`: crouch
- `Q` / `E`: dodge
- `F`: shield
- Mouse: aim and fire
- `P`: pull
- `F4`: switch camera and keyboard mode

## Privacy

Vision runs locally. Camera frames, hand landmarks, handwriting strokes, and
biometric templates are not saved or uploaded. Only the accepted display name,
score, gameplay metrics, and timestamp may be stored in the local leaderboard.

## Test

```powershell
python -m pytest
python main.py --setup-check
python main.py --simulate-vision --capture-demo --windowed
powershell -ExecutionPolicy Bypass -File .\build.ps1
```

More technical and event setup information is available in [`docs`](docs).
