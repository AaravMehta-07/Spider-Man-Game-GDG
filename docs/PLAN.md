# WEB//PROTOCOL Implementation Plan

## Product boundary

`WEB//PROTOCOL: SPIDER-SENSE` is a native, offline Windows installation game.
One participant uses a webcam, pose, and hand gestures to complete a continuous
90-second chase and boss mission. Python performs vision inference; Godot owns
rendering, gameplay, timing, persistence, and presentation.

## Delivery stages

1. **Foundation**: initialize Git, detect Python/Godot/templates, establish
   configuration, scripts, logs, tests, and a process-supervised root launcher.
2. **Vision**: implement latest-frame capture, pose and hand inference,
   calibration, smoothing, pure action classifiers, UDP protocol, health,
   deterministic simulation, and fail-soft camera recovery.
3. **Godot core**: build the Forward+ project, app state machine, exact session
   clock, input abstraction, UDP receiver, keyboard fallback, diagnostics,
   persistence, operator controls, and complete reset semantics.
4. **Continuous chase**: author the city timeline, movement challenges,
   Spider-Sense warnings, web targeting and pressure, drones, barriers, anchors,
   swing, rescues, destruction, health, scoring, and adaptation.
5. **The Void Regent**: transition without loading, render distortion and readable
   counter tells, implement defensive responses, counter-web hits, debris sling,
   and an assisted two-hand web-pull finisher.
6. **Presentation**: build attract, calibration, HUD, results and recruitment
   screens; procedural city art, generated textures/audio, shaders, VFX pools,
   quality scaling, branding replacement points, and cinematic audio transitions.
7. **Reliability**: exercise camera loss, service restart, stale packets, low FPS,
   corrupted saves, player absence, Last Chance Mode, repeated resets, and clean
   process shutdown.
8. **Release proof**: run unit/GDScript/integration tests, deterministic 90-second
   capture, inspect all 13 screenshots, fix visual defects, export the Windows
   executable, smoke-test it, and write an evidence-bounded final report.

## Architecture

```text
Camera -> bounded latest frame -> MediaPipe Tasks -> pure action state machines
       -> sequenced UDP snapshots/events -> Godot input abstraction
       -> central app state machine -> chase/boss systems -> HUD/VFX/audio
```

UDP snapshots are disposable and sequence-numbered. Discrete events include an
event ID for deduplication. Heartbeats and monotonic timestamps allow Godot to
reject stale input. Simulation and keyboard controls feed the same normalized
action interface as live vision.

## Quality gates

- The app clock owns state transitions at 0.0, 5.5, 9.5, 55.0, 58.0, 78.0,
  83.0, and 90.0 seconds.
- Every mission mechanic has a timed assist so tracking cannot deadlock progress.
- Screenshot capture produces the required named 1920x1080 frames and timing/FPS
  evidence; images are manually inspected before visual completion is claimed.
- `Build/WebProtocol.exe` must exist and launch before export is marked complete.
- Webcam and six-hour event claims require actual hardware/soak evidence.
