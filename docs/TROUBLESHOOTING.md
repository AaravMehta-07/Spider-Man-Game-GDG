# Troubleshooting

## Python command uses 3.10

Install Python 3.11 and run setup.ps1. The launcher setup check reports the exact
runtime. The project virtual environment must be created from 3.11.

## Godot not found

Install Godot 4.7.1 or set game.godot_executable in config/local.yaml. Run
.venv/Scripts/python.exe tools/locate_godot.py to confirm detection.

## Export templates missing

Install the matching 4.7.1 stable templates under the Godot export_templates
directory. An editor executable alone cannot export Windows.

## Camera signal lost

Confirm no other app owns the camera. Use Ctrl+O to inspect mode, press F4 for
keyboard fallback, reconnect the camera, then restart the session with R. Camera
capture retries automatically.

## Player not tracked

Move back until the full body and both hands fit. Improve front lighting, remove
backlight, and avoid matching clothing/background contrast. The mission continues
with assistance rather than deadlocking.

## Webs do not fire

Show the index finger with other fingers curled, try pinch, or close then release a
fist. In fallback, use mouse buttons. Check web pressure and F3 packet age.

## No audio

Check Windows output device and M mute. Missing generated WAVs can be restored with
.venv/Scripts/python.exe tools/generate_audio.py, then rerun the Godot import.

## Corrupted leaderboard

The game renames malformed data with a corrupt timestamp suffix and starts a clean
list. It does not discard the malformed file silently.

## Logs

Use .venv/Scripts/python.exe tools/inspect_logs.py. Launcher, vision and build logs
rotate or are bounded. Capture and build reports live under artifacts.