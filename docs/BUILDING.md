# Building

## Automated build

From the repository root:

    powershell -NoProfile -ExecutionPolicy Bypass -File .\build.ps1

The script locates Godot 4.7, runs an editor import, runs the custom GDScript tests,
exports the Windows Desktop release and verifies Build/WebProtocol.exe. Output goes
to logs/build.log and artifacts/build_reports/latest_build.json.

## Manual equivalent

    godot --headless --path game --editor --quit
    godot --headless --path game -s res://tests/test_runner.gd
    godot --headless --path game --export-release "Windows Desktop" Build/WebProtocol.exe

The exact executable path may be obtained with:

    .\.venv\Scripts\python.exe tools\locate_godot.py

## Test commands

    .\.venv\Scripts\python.exe -m ruff check .
    .\.venv\Scripts\python.exe -m pytest
    test.bat

## Release verification

    .\.venv\Scripts\python.exe tools\validate_build.py
    python main.py --simulate-vision --capture-demo --windowed

Do not claim a release build from editor import alone. The executable, hash, launch
smoke test and capture artifacts are separate gates.