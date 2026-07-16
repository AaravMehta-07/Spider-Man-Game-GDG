# WEB//PROTOCOL Engineering Contract

## Mission

Build a native Windows Godot 4 game with a separate local Python vision service.
The public participant flow is one continuous mission and is hard-bounded to 90
seconds from calibration start through automatic reset.

## Non-negotiable behavior

- `python main.py` is the root entry point.
- Python and Godot communicate only over bounded localhost UDP messages.
- Camera inference never blocks Godot's render loop.
- Keyboard/mouse and deterministic simulated-vision modes remain first-class.
- Tracking, camera, audio, or performance failures degrade gracefully.
- Health reaching zero activates Last Chance Mode; it never ends the mission.
- The boss and assisted finisher always complete within the fixed timeline.
- Runtime uses no cloud service and stores no camera frames or biometric data.

## Code conventions

- Prefer small typed GDScript components and explicit signals.
- Prefer dataclasses, type hints, bounded queues, and pure classifiers in Python.
- Configuration belongs in YAML/JSON/resources, not magic values spread in code.
- Avoid per-frame allocation, file I/O, and unbounded history.
- Generated assets must be original and replaceable.
- Tests must distinguish simulated proof from live webcam proof.

## Verification

Run the narrowest relevant tests while editing, then finish with:

```powershell
python -m pytest
python main.py --setup-check
python main.py --simulate-vision --capture-demo --windowed
powershell -ExecutionPolicy Bypass -File .\build.ps1
```

Do not claim export, webcam, performance, or repeated-session success without the
corresponding artifact or observed run.

