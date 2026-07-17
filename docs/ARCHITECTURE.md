# Architecture

## Process boundary

main.py supervises two children:

1. vision.main: camera capture, MediaPipe pose/hands, calibration and actions.
2. Build/WebProtocol.exe: Godot gameplay, rendering, audio, saves and operator UI.

Processes communicate over bounded localhost UDP. The supervisor probes a separate
UDP health port before launching the game. Readiness requires a connected camera,
captured frame, completed inference, and sent input packet. The supervisor restarts
vision at most once.

## Vision data flow

OpenCV Windows backend at requested 30 FPS -> LatestFrameBuffer -> parallel PoseLandmarker and HandLandmarker inference ->
filters and pure classifiers -> sequenced InputSnapshot -> UDP 127.0.0.1:42420.
Snapshots include independent bounded left/right hand coordinates and explicit
open-palm flags; gameplay aim remains the exact average of both visible hands.

There is no frame queue to accumulate latency. Camera reconnect and runtime camera
selection run on the capture thread. Operator commands use a separate bounded UDP
queue. Godot rejects duplicate sequence numbers within each process session and
treats packets older than 600 ms as stale. Simulated vision uses the same protocol.

## Godot composition

- SessionController: authoritative application state and 90-second clock
- UdpVisionReceiver: latest normalized vision input
- ChaseDirector: authored, non-overlapping challenges and chase metrics
- BossController: readable attacks, counters, sling and assisted finisher
- CityBuilder: procedural corridor, rain, vehicles, set pieces, Glider Raiders and the Void Regent
- GameHud: attract, HUD, warnings, results, diagnostics and operator surfaces
- AudioManager: original state music and effects
- SaveManager: bounded, sorted, atomic local leaderboard
- main.gd: explicit orchestration and normalized keyboard/vision input

## Failure boundaries

Camera loss changes health mode to reconnecting; the game can continue with
keyboard input. Stale packets do not fire webs. Vision failure is isolated from
Godot and supervised. Invalid configuration fails with a useful exit code.
Malformed leaderboard data is backed up and replaced. Missing audio logs a
warning but does not stop gameplay.

## Persistence

Settings and leaderboard are the only persistent participant data. Leaderboard
writes go to a temporary file, flush, and rename. Session state, action history,
cooldowns, set pieces, boss health, web pressure and HUD feedback reset together.

## Performance

The camera uses one latest frame. MediaPipe runs outside Godot. Procedural meshes
are created at startup and recycled through position wrapping; temporary set
pieces are capped by the authored schedule. GPU rain, path-follow traffic, animated beacons and web-cage elements are bounded. Sustained low FPS automatically reduces VFX before input work. No gameplay system performs per-frame filesystem I/O.
