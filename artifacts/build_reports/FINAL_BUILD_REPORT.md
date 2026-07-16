# FINAL BUILD REPORT

Generated: 2026-07-17 (Asia/Calcutta)

## Verdict

WEB//PROTOCOL: SPIDER-SENSE is implemented as a native, offline Windows game and is runnable from the repository root with `python main.py`. The release executable, local MediaPipe vision service, keyboard fallback, 90-second state machine, continuous chase, Veil boss, assisted double-web finisher, audio, local leaderboard, recovery paths, operator controls, deterministic captures, setup/build scripts, and documentation are present.

## Implemented

- Python 3.11 supervisor with health gating, one automatic vision restart, rotating logs, clean child shutdown, display-sleep prevention, setup check, build fallback, and bounded smoke mode.
- Local OpenCV and MediaPipe Tasks pipeline using a latest-frame buffer, 640x360 inference, pose and hand classifiers, smoothing/hysteresis, reconnectable camera capture, sequenced UDP snapshots, and bounded operator-command UDP.
- Godot 4.7.1 Forward+ release with an exact 0.0-90.0 second state machine and automatic reset.
- Ten non-overlapping authored chase events: billboard dodge, drone web, vent jump, barrier pull, scaffold crouch, swing, rescue, crane dodge, invisible shockwave shield, and route-collapse double web.
- Seamless distorted Veil reveal, six boss attacks, counters, debris sling, Last Chance recovery, boss web cage, and guaranteed two-handed containment.
- Procedural city, traffic props, path-follow skyline traffic, animated beacon, GPU/manual rain, fog/glow, adaptive VFX reduction, eight shaders, replaceable branding, and an original generated city plate.
- Forty-seven original procedural WAV files, separate Music/Effects buses, positional boss effects, and music crossfades.
- Two-page guarded operator panel, runtime camera selection/restart/mirroring, VSync/fullscreen/input toggles, diagnostics, reset/recalibrate/boss skip/attract controls, confirmed leaderboard clear, and confirmed quit.
- Atomic top-50 local leaderboard with malformed-file backup, daily top-five display, rank, privacy notice, and no raw image or landmark persistence.

## Validation Passed

- Python lint: `ruff check .` passed.
- Python tests: 15 passed, covering buffers, filters, classifiers, protocol, heartbeat, bounded commands, simulator phases, and camera reconnect attempts.
- Godot import/parser validation passed.
- GDScript tests: 44 assertions passed, including exact clock boundaries, 100 consecutive state resets, chase constraints/actions/scoring, boss/finisher, UDP deduplication/freshness, and save recovery.
- Windows release export passed: `C:\Aarav\Code\SpiderMan\Build\WebProtocol.exe`.
- Release size: 111,394,056 bytes.
- SHA-256: `16F3C111E22A5112B18D3D78E3AFC5158547ACD824235F67723D6F9F33B9285C`.
- Simulated-vision full session passed: 90.0 effective seconds, 13 screenshots, automatic attract reset, clean exit.
- Keyboard-only full session passed through calibration, chase, boss, results, and automatic reset.
- Supervisor restart smoke passed: the first vision PID was terminated, a different replacement PID appeared, and the launcher exited 0.
- Live webcam/game smoke passed using camera 0: mode `live`, 31.0 camera FPS, 19.4 pose FPS, 19.4 hand FPS, 197 input packets in 15.03 seconds, clean exit.
- Capture performance: 167.53 average instantaneous FPS and 157.5 FPS fifth percentile in 1280x720 windowed capture mode. Raw minimum was 6.67 FPS during synchronous PNG writing and is reported separately.
- Visual review completed for all 13 required frames. False camera-loss overlays and results-screen overlap found during review were fixed and the capture set was regenerated.

## Artifacts

- Executable: `C:\Aarav\Code\SpiderMan\Build\WebProtocol.exe`
- Build metadata: `artifacts/build_reports/latest_build.json`
- Final report: `artifacts/build_reports/FINAL_BUILD_REPORT.md`
- Screenshots: `artifacts/screenshots/01_attract.png` through `13_results.png`
- Vision capture timing: `artifacts/test_reports/capture_timing.json`
- Keyboard smoke timing: `artifacts/test_reports/keyboard_smoke.json`
- Live webcam smoke: `artifacts/test_reports/live_camera_smoke.json`
- Vision restart smoke: `artifacts/test_reports/vision_restart_smoke.json`

## Run

```powershell
python main.py
```

Setup and rebuild:

```powershell
powershell -ExecutionPolicy Bypass -File .\setup.ps1
powershell -ExecutionPolicy Bypass -File .\build.ps1
```

## Known Limits

- The measured live pose/hand rate was 19.4 FPS, effectively the lower edge of the requested approximate 20-30 FPS band. Event-day lighting, camera driver, USB port, and participant framing can change this measurement.
- The release passed a deterministic 100-session state/reset test, but a literal six-hour live-camera soak and 100 physically played sessions were not run during this build session.
- Branding, QR destination, procedural sound, and city artwork are original functional defaults intended to be replaced by organisers where appropriate.
- Sensitivity and audio baseline values are displayed in the operator panel and remain YAML/JSON-configured; camera, input mode, display, diagnostics, session, leaderboard, and quit controls are live at runtime.
- Screenshot performance was measured in a 1280x720 windowed validation run. The shipped viewport and fullscreen presentation are 1920x1080.

## Event-Day Checks

Run one organiser session in the final booth lighting, verify the correct camera with F5/F6, confirm both hands and full body remain visible, check speaker levels and QR destination, inspect F3 diagnostics, then run `capture_demo.bat`. Keep F4 keyboard mode available and use the confirmed quit sequence rather than terminating processes from Task Manager.