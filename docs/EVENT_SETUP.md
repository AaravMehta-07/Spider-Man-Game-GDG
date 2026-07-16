# Event Setup

## Physical layout

- Mount the camera at 1.2-1.6 metres, centred above or below the display.
- Mark a standing point 2.2-3.0 metres from the camera.
- Mark a 2 x 2 metre clear movement zone with high-contrast floor tape.
- Remove chairs, cables and sharp edges from the participant area.
- Keep spectators behind the camera plane.
- Use a 1920x1080 display at 100 percent Windows scaling.

## Lighting

Use soft front or front-side light. Keep the full body brighter than the background.
Avoid strong backlights, flickering decorative lights and direct sunlight. Test dark
and light clothing. A plain but not featureless background gives stable tracking.

## Audio and display

Select the event display as primary or start with --windowed and move it before
F11. Disable notification banners. Set speakers so prompts are audible without
overwhelming nearby booths. Verify Master, Music and Effects levels before opening.

## Operator checklist

1. Connect camera, display and speakers.
2. Disable display sleep and Windows Focus Assist notifications.
3. Run python main.py --setup-check.
4. Run capture_demo.bat and inspect all screenshots.
5. Run one live-camera session with an organiser.
6. Confirm lean, jump, crouch, shield, both webs and pull.
7. Confirm F3 diagnostics, F4 fallback, F5-F8 camera controls, R reset and guarded quit.
8. Confirm automatic results reset and a leaderboard entry.
9. Keep keyboard and mouse at the operator position.

## Participant positioning

Ask the participant to stand on the marker, face the camera and keep their whole
body visible. Calibration is five and a half seconds and will continue with safe
defaults if confidence is imperfect. Web verification will also continue using
simplified gestures rather than holding the queue.

## Emergency operation

Press F4 for keyboard/mouse mode. Press R to reset a session. Open Ctrl+O for the
operator overlay. Use B while the panel is open to test the boss. Quit only with
Ctrl+Shift+Q followed by Y.

## Shutdown

Finish the active participant session when practical, use the confirmed quit
sequence, and wait for the launcher to stop vision. Do not kill power while a
leaderboard write is in progress. Archive logs and artifact reports after the event.