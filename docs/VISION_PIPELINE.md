# Vision Pipeline

## Capture

CameraService owns one OpenCV capture thread. On Windows it tries Media Foundation,
DirectShow, and automatic backend fallback across the configured camera and bounded
camera IDs. It requests the configured resolution with a one-frame driver buffer.
Frames are mirrored for participant intuition and
published into LatestFrameBuffer, a one-slot exchange. New frames replace old ones,
so inference never works through a latency backlog.

## MediaPipe

PoseService and HandService use official local MediaPipe Tasks model files in VIDEO
mode with increasing millisecond timestamps. Pose tracks one body; hands track up
to two. Their independent inference calls run concurrently in a fixed two-worker
pool, with no queued frame history. The models are loaded once and closed during
clean shutdown.

## Calibration and features

During the first seconds, valid pose frames estimate centre, shoulder height, hip
height and shoulder width. Missing or weak samples fall back to conservative
normalized defaults. Features are scale-relative, not pixel thresholds.

MovementClassifier applies confidence-aware smoothing and hysteresis:

- centre offset produces left/right lane control
- hip rise produces jump
- shoulder drop produces crouch
- lateral velocity produces dodge with cooldown
- raised, close wrists produce shield

Hand features identify an explicit open palm, index-forward web pose, pinch and fist release. Aim uses the
index fingertip. WebGestureClassifier turns sustained shapes into edge-safe triggers
and estimates pull from closed-hand wrist motion.

## Protocol

InputSnapshot contains protocol version, sequence, session ID, monotonic timestamp,
tracking confidence, movement, aim, action booleans and pull strengths. Packets are
compact JSON under 8192 bytes and sent to localhost UDP port 42420. Health replies
use port 42421.

Godot keeps only the highest sequence within each vision-process session ID and
accepts sequence 1 immediately after a supervised service restart. Input older
than 600 ms is stale. Stale or lost hand input never fires an accidental web.

The health service reports ready only after a camera is connected, a real frame
has been captured, inference has completed, and at least one input packet has been
sent. Camera connection, selected device, frame/inference/packet counts, reconnects,
and the last error are exposed for launcher diagnostics.

## Tuning

Edit config/vision.yaml and config/shared.yaml, or override machine values in
ignored config/local.yaml. Tune one threshold at a time with F3 diagnostics. Keep
hysteresis exits below entries. Prefer aim assistance over excessive smoothing,
because smoothing increases perceived latency.

## Privacy

Frames and raw landmarks remain in process memory. No camera image, video,
biometric template or raw landmark history is written to disk or sent online.
