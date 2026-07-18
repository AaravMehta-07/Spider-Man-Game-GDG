from __future__ import annotations

import argparse
import logging
import signal
import socket
import sys
import threading
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from time import monotonic, sleep
from uuid import uuid4

from vision.health_server import HealthState, UdpHealthServer
from vision.movement_classifier import BodyActions, MovementClassifier
from vision.pose_features import (
    CalibrationProfile,
    PoseFeatures,
    calibration_from_samples,
    extract_pose,
)
from vision.protocol import InputSnapshot, encode_snapshot
from vision.simulator import ScriptedPlayer
from vision.web_gesture_classifier import WebActions, WebGestureClassifier
from web_protocol.config import ProjectConfig
from web_protocol.logging_setup import configure_logging


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="WEB//PROTOCOL local vision service")
    parser.add_argument("--simulate", action="store_true")
    parser.add_argument("--time-scale", type=float, default=1.0)
    parser.add_argument("--camera", type=int)
    parser.add_argument("--debug", action="store_true")
    parser.add_argument("--instance-id")
    return parser


def run_simulator(
    config: ProjectConfig,
    stop: threading.Event,
    logger: logging.Logger,
    time_scale: float = 1.0,
    instance_id: str | None = None,
) -> int:
    game = config.section("game")
    network = config.section("network")
    host, port = str(game["udp_host"]), int(game["udp_port"])
    health = HealthState(
        mode="starting",
        selected_camera=-1,
        calibrated=True,
        calibration_samples=24,
        instance_id=instance_id or uuid4().hex,
    )
    server = UdpHealthServer(host, int(game["health_port"]), health)
    server.start()
    player = ScriptedPlayer(session_id=uuid4().hex)
    interval = 1.0 / float(network["snapshot_hz"])
    started = monotonic()
    next_packet = started
    logger.info("simulated vision ready on udp://%s:%s", host, port)
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sender:
            while not stop.is_set():
                now = monotonic()
                if now < next_packet:
                    sleep(min(interval, next_packet - now))
                    continue
                for command in health.drain_commands():
                    if command.get("command") == "sync_session":
                        started = now
                        player = ScriptedPlayer(session_id=uuid4().hex)
                        logger.info("simulated vision session synchronized")
                    elif command.get("command") == "game_input_active":
                        health.game_input_active = True
                elapsed = ((now - started) * max(0.1, time_scale)) % 90.0
                snapshot = player.sample(elapsed)
                snapshot.camera_fps = float(network["snapshot_hz"])
                snapshot.pose_fps = float(network["snapshot_hz"])
                snapshot.hand_fps = float(network["snapshot_hz"])
                sender.sendto(encode_snapshot(snapshot), (host, port))
                health.mark_packet()
                health.inference_frames += 1
                health.inference_fps = float(network["snapshot_hz"])
                health.camera_fps = float(network["snapshot_hz"])
                health.camera_connected = True
                health.frames_captured += 1
                health.mode = "simulated"
                health.ready = True
                next_packet = max(next_packet + interval, now)
    finally:
        server.stop()
    return 0


def _hand_actions(
    result, classifiers: dict[str, WebGestureClassifier], timestamp: float
) -> dict[str, WebActions]:
    actions: dict[str, WebActions] = {}
    for index, landmarks in enumerate(result.hand_landmarks):
        label = "Right"
        if index < len(result.handedness) and result.handedness[index]:
            label = result.handedness[index][0].category_name
        classifier = classifiers.get(label)
        if classifier is None:
            classifier = WebGestureClassifier()
            classifiers[label] = classifier
        actions[label] = classifier.classify(landmarks, timestamp)
    for label, classifier in classifiers.items():
        if label not in actions:
            classifier.mark_missing()
    return actions


def _reset_hand_classifiers(classifiers: dict[str, WebGestureClassifier]) -> None:
    for classifier in classifiers.values():
        classifier.reset()


def calibration_profile_when_ready(
    samples: list[PoseFeatures], elapsed: float, duration: float, minimum_samples: int
) -> CalibrationProfile | None:
    if elapsed < duration:
        return None
    fallback_minimum = min(8, minimum_samples)
    safe_samples = samples if len(samples) >= fallback_minimum else []
    return calibration_from_samples(safe_samples)


def _snapshot(
    sequence: int,
    session_id: str,
    pose: PoseFeatures | None,
    body: BodyActions,
    hands: dict[str, WebActions],
) -> InputSnapshot:
    left = hands.get("Left")
    right = hands.get("Right")
    aims = [hand for hand in (left, right) if hand is not None]
    aim_x = sum(hand.aim_x for hand in aims) / len(aims) if aims else 0.5
    aim_y = sum(hand.aim_y for hand in aims) / len(aims) if aims else 0.5
    pulls = [hand.pull for hand in aims]
    return InputSnapshot(
        sequence=sequence,
        session_id=session_id,
        tracked=pose is not None,
        pose_confidence=pose.confidence if pose else 0.0,
        hand_confidence=1.0 if aims else 0.0,
        hand_count=len(aims),
        move=body.move,
        aim_x=aim_x,
        aim_y=aim_y,
        aim_left_x=left.aim_x if left else 0.5,
        aim_left_y=left.aim_y if left else 0.5,
        aim_right_x=right.aim_x if right else 0.5,
        aim_right_y=right.aim_y if right else 0.5,
        jump=body.jump,
        crouch=body.crouch,
        dodge_left=body.dodge_left,
        dodge_right=body.dodge_right,
        shield=body.shield,
        web_left=bool(left and left.held),
        web_right=bool(right and right.held),
        web_left_trigger=bool(left and left.trigger),
        web_right_trigger=bool(right and right.trigger),
        fist_left=bool(left and left.fist),
        fist_right=bool(right and right.fist),
        palm_open_left=bool(left and left.open_palm),
        palm_open_right=bool(right and right.open_palm),
        gesture_left=left.gesture if left else "OPEN",
        gesture_right=right.gesture if right else "OPEN",
        pull=max(pulls, default=0.0),
        two_hand_pull=min(left.pull, right.pull) if left and right else 0.0,
    )


def run_live(
    config: ProjectConfig, args: argparse.Namespace, stop: threading.Event, logger: logging.Logger
) -> int:
    import cv2

    from vision.camera_service import CameraService
    from vision.hand_service import HandService
    from vision.pose_service import PoseService

    game = config.section("game")
    vision_config = config.section("vision")
    models = config.section("models")
    calibration = config.section("calibration")
    gestures = config.section("gestures")
    root = config.root
    camera_id = args.camera if args.camera is not None else int(vision_config["camera_id"])
    camera = CameraService(
        camera_id,
        int(vision_config["capture_width"]),
        int(vision_config["capture_height"]),
        bool(vision_config["mirror"]),
        logger,
        int(vision_config["target_fps"]),
    )
    pose_service = PoseService(root / str(models["pose"]), float(vision_config["pose_confidence"]))
    hand_service = HandService(root / str(models["hands"]), float(vision_config["hand_confidence"]))
    health = HealthState(
        mode="starting",
        selected_camera=camera_id,
        instance_id=args.instance_id or uuid4().hex,
    )
    health_server = UdpHealthServer(str(game["udp_host"]), int(game["health_port"]), health)
    health_server.start()
    camera.start()
    samples: list[PoseFeatures] = []
    movement: MovementClassifier | None = None
    classifier_options = {
        "release_grace": float(gestures["trigger_release_ms"]) / 1000.0,
        "trigger_hold": float(gestures["trigger_hold_ms"]) / 1000.0,
    }
    hands = {
        "Left": WebGestureClassifier(**classifier_options),
        "Right": WebGestureClassifier(**classifier_options),
    }
    session_id = uuid4().hex
    sequence = 0
    last_frame_sequence = 0
    service_started = monotonic()
    calibration_started = service_started
    inference_started = service_started
    inference_frames = 0
    logger.info("live vision starting; waiting for camera %s", camera_id)
    try:
        with (
            socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sender,
            ThreadPoolExecutor(max_workers=2, thread_name_prefix="landmarks") as inference_pool,
        ):
            target = (str(game["udp_host"]), int(game["udp_port"]))
            while not stop.is_set():
                for command in health.drain_commands():
                    name = str(command.get("command", ""))
                    if name == "sync_session":
                        samples.clear()
                        movement = None
                        _reset_hand_classifiers(hands)
                        session_id = uuid4().hex
                        sequence = 0
                        calibration_started = monotonic()
                        health.calibrated = False
                        health.calibration_samples = 0
                        logger.info("vision session synchronized; calibration restarted")
                    elif name == "game_input_active":
                        health.game_input_active = True
                    elif name == "restart_camera":
                        camera.request_restart()
                        samples.clear()
                        movement = None
                        _reset_hand_classifiers(hands)
                        calibration_started = -1.0
                        health.calibrated = False
                        health.calibration_samples = 0
                    elif name == "set_camera":
                        camera.request_restart(camera_id=int(command.get("camera_id", 0)))
                        samples.clear()
                        movement = None
                        _reset_hand_classifiers(hands)
                        calibration_started = -1.0
                        health.calibrated = False
                        health.calibration_samples = 0
                    elif name == "set_mirror":
                        camera.request_restart(mirror=bool(command.get("enabled", True)))
                        samples.clear()
                        movement = None
                        _reset_hand_classifiers(hands)
                        calibration_started = -1.0
                        health.calibrated = False
                        health.calibration_samples = 0
                frame = camera.frames.wait_newer(last_frame_sequence, timeout=0.1)
                health.camera_connected = camera.metrics.connected
                health.selected_camera = camera.metrics.selected_camera
                health.camera_fps = camera.metrics.fps
                health.frames_captured = camera.metrics.frames
                health.reconnects = camera.metrics.reconnects
                health.last_error = camera.metrics.last_error
                if camera.metrics.worker_error:
                    raise RuntimeError(f"camera worker failed: {camera.metrics.worker_error}")
                if not camera.metrics.connected:
                    health.ready = False
                    health.mode = "reconnecting" if camera.metrics.reconnects else "starting"
                if frame is None:
                    if (
                        health.last_packet_at is not None
                        and monotonic() - health.last_packet_at > 3.0
                        and camera.metrics.connected
                    ):
                        health.ready = False
                        health.mode = "stalled"
                        raise RuntimeError("camera frames stalled for more than three seconds")
                    continue
                last_frame_sequence = frame.sequence
                now = monotonic()
                if calibration_started < 0.0:
                    calibration_started = now
                timestamp_ms = max(1, int((now - service_started) * 1000.0))
                inference_frame = cv2.resize(
                    frame.value,
                    (
                        int(vision_config["inference_width"]),
                        int(vision_config["inference_height"]),
                    ),
                    interpolation=cv2.INTER_AREA,
                )
                pose_future = inference_pool.submit(
                    pose_service.detect, inference_frame, timestamp_ms
                )
                hand_result = hand_service.detect(inference_frame, timestamp_ms)
                pose_result = pose_future.result()
                pose = (
                    extract_pose(pose_result.pose_landmarks[0])
                    if pose_result.pose_landmarks
                    else None
                )
                if pose and movement is None:
                    samples.append(pose)
                    health.calibration_samples = len(samples)
                    profile = calibration_profile_when_ready(
                        samples,
                        now - calibration_started,
                        float(calibration["duration_seconds"]),
                        int(calibration["minimum_samples"]),
                    )
                    if profile is not None:
                        movement = MovementClassifier(
                            profile,
                            float(calibration["lean_threshold"]),
                            float(calibration["jump_threshold"]),
                            float(calibration["crouch_threshold"]),
                            float(calibration["dodge_velocity_threshold"]),
                        )
                        health.calibrated = True
                body = movement.classify(pose, now) if movement and pose else BodyActions()
                hand_actions = _hand_actions(hand_result, hands, now)
                sequence += 1
                snapshot = _snapshot(sequence, session_id, pose, body, hand_actions)
                snapshot.camera_fps = camera.metrics.fps
                snapshot.pose_fps = health.inference_fps
                snapshot.hand_fps = health.inference_fps
                sender.sendto(encode_snapshot(snapshot), target)
                health.mark_packet()
                inference_frames += 1
                health.inference_frames += 1
                health.ready = bool(camera.metrics.connected and camera.metrics.frames > 0)
                health.mode = "live" if health.ready else "reconnecting"
                if health.ready and health.packets_sent == 1:
                    logger.info(
                        "live vision ready; camera %s via %s; first frame and UDP packet sent",
                        camera.metrics.selected_camera,
                        camera.metrics.backend,
                    )
                elapsed = now - inference_started
                if elapsed >= 1.0:
                    health.inference_fps = inference_frames / elapsed
                    health.hand_fps = health.inference_fps
                    inference_frames = 0
                    inference_started = now
    finally:
        camera.stop()
        health_server.stop()
        pose_service.close()
        hand_service.close()
    return 0


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    root = Path(__file__).resolve().parents[1]
    logger = configure_logging(root, args.debug, "vision")
    config = ProjectConfig.load(root)
    stop = threading.Event()
    signal.signal(signal.SIGINT, lambda *_: stop.set())
    signal.signal(signal.SIGTERM, lambda *_: stop.set())
    try:
        if args.simulate:
            return run_simulator(config, stop, logger, args.time_scale, args.instance_id)
        return run_live(config, args, stop, logger)
    except Exception as error:
        logger.error("vision service failed: %s", error)
        return 20


if __name__ == "__main__":
    sys.exit(main())
