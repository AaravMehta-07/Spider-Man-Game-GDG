# PRODUCTION AUDIT: WEB//PROTOCOL SPIDER-SENSE

Generated: 2026-07-17 (Asia/Calcutta)

## Verdict

The supervised Windows build is ready for production rehearsal and booth acceptance.
The reported camera-start/reset failure was reproduced from code and repaired. A
camera-mode mission can no longer start until a real camera frame has been processed
and a fresh tracked input packet exists. Tracking loss no longer returns the player
to the home screen.

The supported entry points are `run.bat` and `python main.py`. Directly opening
`Build\WebProtocol.exe` cannot start the separate Python vision service; that path
now stays safely on the home screen, explains the correct launch method, and offers
F4 keyboard fallback.

Public distribution is not yet a zero-action handoff: the executable is unsigned,
the recruitment QR is intentionally marked not configured, and the event owner must
confirm clearance for the final product name and supplied branding. Those external
release items do not block a supervised internal booth rehearsal.

## Root Causes Fixed

1. Live vision published `ready=true` before the camera thread opened a device.
2. Godot converted missing/stale tracking into an unconditional home reset after six seconds.
3. Enter started camera missions without checking for a fresh packet and tracked player.
4. A restarted vision process reset its packet counter, but Godot rejected the new sequence as stale.
5. The game did not explain aim, fire, attack, pull, shield, movement, or finisher gestures clearly.
6. Automated capture runs wrote synthetic scores into the participant leaderboard.
7. Build/test Godot processes used the default log path, which was unreliable in restricted Windows runs.
8. A new mission could inherit calibration state from packets produced before the
   participant entered, instead of requiring a fresh session calibration.
9. Web gestures could flicker between frames, a fist without an attached web was
   misread as a pull, and ordinary boss shots did not damage the boss.
10. A run could absorb unlimited obstacle collisions without a clear loss condition.
11. The attract screen asked for both hands but had no explicit, visible open-palm
    dwell lock and could leave a participant waiting without advancing.
12. Participant identity was fixed text rather than a camera-driven onboarding step.

## Repairs

- Health is false during startup/reconnect and becomes true only after camera connect,
  frame capture, inference, and a sent UDP input packet.
- Health telemetry now includes camera connection, selected device, frames, inference
  count, packets, reconnects, rates, and last error.
- Windows camera startup uses bounded Media Foundation, DirectShow, and automatic
  backend fallback across camera IDs 0-2.
- Pose and hand inference run concurrently in a fixed two-worker pool; no camera or
  inference queue can accumulate latency.
- The launcher waits up to 20 seconds for genuine readiness and prints actionable
  Windows camera/privacy/fallback guidance on failure.
- Enter is blocked until fresh tracked camera input exists. Keyboard mode remains
  immediately available with F4.
- Tracking loss shows a reconnect overlay and keyboard backup while the authoritative
  90-second clock and assisted gameplay continue. There is no tracking-loss reset.
- Vision session IDs reset Godot packet sequencing safely after a supervised restart.
- Each Godot mission synchronizes a new vision session and restarts calibration
  without resetting MediaPipe's monotonic timestamps.
- The home screen contains a full gesture guide. Calibration and verification show
  aim/fire steps and live detected actions. Every chase and boss prompt includes the
  required gesture plus keyboard/mouse equivalent.
- Capture/demo scores use an isolated artifact leaderboard instead of participant data.
- Runtime and build logs use explicit local paths; every state transition is logged.
- Aim is the exact average of both visible hands. Scale-aware classifiers recognize
  the classic index-and-pinky web pose, pinch, and fist-shot edges with release grace
  and cooldowns. Per-hand gesture names and shot confirmation are visible in the HUD.
- Boss shots use aim-space target locking, misses give immediate correction, and
  successful free-fire shots apply real damage without bypassing authored counters.
- The third obstacle collision disqualifies the run, caps the display at 3/3, and
  excludes the score from the leaderboard while preserving the required 90-second flow.
- Roads, buses, facades, street furniture, obstacles, the original Glider Raider,
  and the original armored cosmic boss, the Void Regent, received a visual upgrade.
- Camera onboarding now requires two explicitly detected open palms held for three
  seconds. The visible lock decays through brief tracking flicker and advances to
  name entry automatically; Enter remains a keyboard-only fallback.
- Name entry is a bounded local air-writing flow: close either fist to draw one
  uppercase block letter, open the hand to lift the pen, pinch to accept the
  prediction, hold both fists to clear/undo, and hold both palms open to confirm.
  Independent left/right aim coordinates prevent the averaged gameplay cursor from
  corrupting single-hand pen strokes. No frames, landmarks, or strokes are stored.
- Simulated vision creates a fresh session identity after mission synchronization,
  preventing reset packets from being discarded as stale across repeated runs.

## Validation Passed

- Python 3.11.9 setup check: passed.
- Python tests: 35 passed.
- Python lint for all changed Python modules: passed.
- GDScript tests: 125 assertions passed.
- Godot 4.7.1 import/parser validation: passed.
- Windows release export: passed.
- Release size: 111,539,792 bytes.
- Release SHA-256: `59988F64E21E30D76728738C56165A01293DAF8AB476266968D47DDDEBDFBCBD`.
- Simulated full mission: reached all authored states, results, 90.00-second reset,
  clean exit, and 13 regenerated screenshots.
- Capture performance at 1280x720: 84.18 average FPS, 60.00 FPS fifth percentile,
  with a 6.78 FPS raw minimum caused by synchronous PNG capture stalls.
- Three consecutive accelerated 90-second missions completed with zero launcher
  failures, 13 screenshots each, and automatic return to attract after every run.
- Live webcam smoke, camera 0: ready=true, Media Foundation, 30.00 camera FPS,
  23.65 pose/hand inference FPS, 455 captured frames, 386 inference packets,
  zero reconnects, no camera error, clean supervised exit.
- Interactive full mission with the live camera service active and keyboard fallback:
  state boundaries observed at 5.51, 9.52, 55.01, 58.00, 78.01, 83.01, and
  90.00 seconds, followed by automatic attract reset.
- Forced tracking-loss smoke: link loss observed; results and timeline reset still
  reached; game exited zero.
- Supervisor restart smoke: first vision PID terminated, replacement PID detected,
  launcher exited zero.
- Duplicate-supervisor smoke: the second launcher exited 21 with clear ownership
  guidance while the original vision service remained alive.
- Keyboard-only boss smoke: 12 seconds of supervised boss runtime, fresh simulated
  packets, clean launcher exit, and no camera dependency.
- UDP validation rejects malformed, oversized, duplicate, and retired-session packets.
- Leaderboard corruption recovery, backup restore, bounded history, and atomic commit
  behavior are covered by the GDScript suite.
- Direct-EXE negative path: camera offline state and launch guidance rendered; Enter
  remained blocked; F4 keyboard fallback started gameplay successfully.
- Visual review: attract/help, calibration, aim/fire verification, chase actions,
  pull, boss counters, finisher, results, offline guard, and keyboard fallback inspected.
- Forced failure replay: the third collision produced `MISSION FAILED`, capped the
  result at `3/3`, showed `NO RANK - RUN FAILED`, and did not save a participant score.
- Exact both-hand average regression: left aim (0.2, 0.3) and right aim (0.8, 0.7)
  produced combined aim (0.5, 0.5).
- Open-palm onboarding policy requires fresh tracking, exactly two hands, both
  explicit palm flags, and the complete three-second dwell. Air-name tests cover
  stroke bounds, A/V recognition, accept, safe keyboard input, clear, and undo.

## Evidence Boundaries

- The webcam device and live MediaPipe pipeline were observed, but the final 90-second
  interactive automation used keyboard fallback because no person was positioned in
  front of the laptop for a physical-gesture play-through.
- Gesture classifiers, simulated gestures, prompts, timing, camera frames, live
  inference packets, and keyboard gameplay are proven separately. A booth acceptance
  run with a standing participant in final lighting remains an operational check,
  especially for that participant's handwriting scale and open-palm/fist transitions.
- The automated capture sandbox logged a Windows certificate-store warning. The game
  uses no TLS or cloud service, and the normal elevated build/export completed cleanly.
- A literal multi-hour soak and 100 physical participant sessions were not performed.
- The exported EXE reports version 1.0.0.0 and the intended product metadata, but
  Authenticode status is `NotSigned` because no publisher certificate was supplied.
- The placeholder QR is visibly labeled `EVENT QR NOT CONFIGURED`; it cannot be
  mistaken for a live recruitment destination. Add the approved QR and marker before
  a public event.
- Trademark, venue, privacy-notice, and final brand approvals remain event-owner
  responsibilities rather than claims established by source or runtime testing.

## Artifacts

- Executable: `C:\Aarav\Code\SpiderMan\Build\WebProtocol.exe`
- Build metadata: `artifacts/build_reports/latest_build.json`
- Screenshots: `artifacts/screenshots/01_attract.png`, `01_air_name.png`, and the
  authored mission states through `13_results.png`
- Failure result: `artifacts/screenshots/13_failure_results.png`
- Capture timing: `artifacts/test_reports/capture_timing.json`
- Live camera: `artifacts/test_reports/live_camera_smoke.json`
- Tracking loss: `artifacts/test_reports/tracking_loss_smoke.json`
- Vision restart: `artifacts/test_reports/vision_restart_smoke.json`
- Repeated runtime: `artifacts/test_reports/repeated_runtime_smoke.json`
- Interactive runtime log: `logs/godot_runtime.log`

## Run

```powershell
.\run.bat
```

Equivalent:

```powershell
python main.py
```

Do not use the EXE alone for camera mode. Before an event, run one participant
acceptance session in final lighting, confirm the camera indicator, both-hand tracking,
speaker levels, projector framing, and the QR destination.
