from __future__ import annotations

import argparse
import logging
import signal
import socket
import sys
import threading
from pathlib import Path
from time import monotonic, sleep
from uuid import uuid4

import cv2

from vision.camera_service import CameraService
from vision.hand_service import HandService
from vision.health_server import HealthState, UdpHealthServer
from vision.movement_classifier import BodyActions, MovementClassifier
from vision.pose_features import PoseFeatures, calibration_from_samples, extract_pose
from vision.pose_service import PoseService
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
    return parser


def run_simulator(
    config: ProjectConfig,
    stop: threading.Event,
    logger: logging.Logger,
    time_scale: float = 1.0,
) -> int:
    game = config.section("game")
    network = config.section("network")
    host, port = str(game["udp_host"]), int(game["udp_port"])
    health = HealthState(ready=True, mode="simulated")
    server = UdpHealthServer(host, int(game["health_port"]), health)
    server.start()
    player = ScriptedPlayer()
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
                elapsed = ((now - started) * max(0.1, time_scale)) % 90.0
                snapshot = player.sample(elapsed)
                snapshot.camera_fps = float(network["snapshot_hz"])
                snapshot.pose_fps = float(network["snapshot_hz"])
                snapshot.hand_fps = float(network["snapshot_hz"])
                sender.sendto(encode_snapshot(snapshot), (host, port))
                health.packets_sent += 1
                health.inference_fps = float(network["snapshot_hz"])
                health.camera_fps = float(network["snapshot_hz"])
                next_packet = max(next_packet + interval, now)
    finally:
        server.stop()
    return 0


def _hand_actions(result, classifiers: dict[str, WebGestureClassifier]) -> dict[str, WebActions]:
    actions: dict[str, WebActions] = {}
    for index, landmarks in enumerate(result.hand_landmarks):
        label = "Right"
        if index < len(result.handedness) and result.handedness[index]:
            label = result.handedness[index][0].category_name
        classifier = classifiers.setdefault(label, WebGestureClassifier())
        actions[label] = classifier.classify(landmarks)
    return actions


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
        move=body.move,
        aim_x=aim_x,
        aim_y=aim_y,
        jump=body.jump,
        crouch=body.crouch,
        dodge_left=body.dodge_left,
        dodge_right=body.dodge_right,
        shield=body.shield,
        web_left=bool(left and left.held),
        web_right=bool(right and right.held),
        pull=max(pulls, default=0.0),
        two_hand_pull=min(left.pull, right.pull) if left and right else 0.0,
    )


def run_live(
    config: ProjectConfig, args: argparse.Namespace, stop: threading.Event, logger: logging.Logger
) -> int:
    game = config.section("game")
    vision_config = config.section("vision")
    models = config.section("models")
    calibration = config.section("calibration")
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
    health = HealthState(ready=True, mode="live")
    health_server = UdpHealthServer(str(game["udp_host"]), int(game["health_port"]), health)
    health_server.start()
    camera.start()
    samples: list[PoseFeatures] = []
    movement: MovementClassifier | None = None
    hands = {"Left": WebGestureClassifier(), "Right": WebGestureClassifier()}
    session_id = uuid4().hex
    sequence = 0
    last_frame_sequence = 0
    started = monotonic()
    inference_started = started
    inference_frames = 0
    logger.info("live vision ready; camera %s", camera_id)
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sender:
            target = (str(game["udp_host"]), int(game["udp_port"]))
            while not stop.is_set():
                for command in health.drain_commands():
                    name = str(command.get("command", ""))
                    if name == "restart_camera":
                        camera.request_restart()
                    elif name == "set_camera":
                        camera.request_restart(camera_id=int(command.get("camera_id", 0)))
                    elif name == "set_mirror":
                        camera.request_restart(mirror=bool(command.get("enabled", True)))
                frame = camera.frames.wait_newer(last_frame_sequence, timeout=0.1)
                health.camera_fps = camera.metrics.fps
                health.mode = "live" if camera.metrics.connected else "reconnecting"
                if frame is None:
                    continue
                last_frame_sequence = frame.sequence
                now = monotonic()
                timestamp_ms = max(1, int((now - started) * 1000.0))
                inference_frame = cv2.resize(
                    frame.value,
                    (
                        int(vision_config["inference_width"]),
                        int(vision_config["inference_height"]),
                    ),
                    interpolation=cv2.INTER_AREA,
                )
                pose_result = pose_service.detect(inference_frame, timestamp_ms)
                hand_result = hand_service.detect(inference_frame, timestamp_ms)
                pose = (
                    extract_pose(pose_result.pose_landmarks[0])
                    if pose_result.pose_landmarks
                    else None
                )
                if pose and movement is None:
                    samples.append(pose)
                    enough_time = now - started >= float(calibration["duration_seconds"])
                    if len(samples) >= int(calibration["minimum_samples"]) or enough_time:
                        movement = MovementClassifier(
                            calibration_from_samples(samples),
                            float(calibration["lean_threshold"]),
                            float(calibration["jump_threshold"]),
                            float(calibration["crouch_threshold"]),
                            float(calibration["dodge_velocity_threshold"]),
                        )
                body = movement.classify(pose, now) if movement and pose else BodyActions()
                hand_actions = _hand_actions(hand_result, hands)
                sequence += 1
                snapshot = _snapshot(sequence, session_id, pose, body, hand_actions)
                snapshot.camera_fps = camera.metrics.fps
                snapshot.pose_fps = health.inference_fps
                snapshot.hand_fps = health.inference_fps
                sender.sendto(encode_snapshot(snapshot), target)
                health.packets_sent += 1
                inference_frames += 1
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
    if args.simulate:
        return run_simulator(config, stop, logger, args.time_scale)
    try:
        return run_live(config, args, stop, logger)
    except Exception:
        logger.exception("live vision failed")
        return 20


if __name__ == "__main__":
    sys.exit(main())
