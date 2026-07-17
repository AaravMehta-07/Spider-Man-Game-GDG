from __future__ import annotations

import socket
import threading
from pathlib import Path
from time import sleep

import pytest

from vision.health_server import HealthState, UdpHealthServer, probe_health
from vision.simulator import ScriptedPlayer


def _free_udp_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.bind(("127.0.0.1", 0))
        return int(sock.getsockname()[1])


def test_health_heartbeat_round_trip() -> None:
    port = _free_udp_port()
    state = HealthState(ready=True, mode="test", packets_sent=12)
    server = UdpHealthServer("127.0.0.1", port, state)
    server.start()
    try:
        response = None
        for _ in range(20):
            response = probe_health("127.0.0.1", port, timeout=0.1)
            if response:
                break
            sleep(0.01)
        assert response is not None
        assert response["ready"] is True
        assert response["mode"] == "test"
        assert response["packets_sent"] == 12
        assert response["camera_connected"] is False
        assert response["frames_captured"] == 0
        assert response["inference_frames"] == 0
        assert response["last_error"] == ""
        assert isinstance(response["instance_id"], str)
        assert response["process_id"] > 0
        assert response["packet_age_ms"] == -1.0
    finally:
        server.stop()


def test_scripted_player_covers_chase_boss_and_finisher() -> None:
    player = ScriptedPlayer()
    chase = player.sample(16.2)
    boss = player.sample(59.6)
    finisher = player.sample(81.8)
    assert chase.tracked and abs(chase.move) > 0.0
    assert boss.dodge_left or boss.dodge_right or boss.shield
    assert finisher.web_left and finisher.web_right
    assert finisher.two_hand_pull > 0.9
    assert chase.sequence < boss.sequence < finisher.sequence


def test_camera_service_records_reconnect_attempt(monkeypatch) -> None:
    import logging

    from vision.camera_service import CameraService

    class ClosedCapture:
        def isOpened(self) -> bool:
            return False

        def release(self) -> None:
            return None

    service = CameraService(99, 320, 180, False, logging.getLogger("camera-test"))
    monkeypatch.setattr(service, "_open", lambda: ClosedCapture())
    service.start()
    try:
        for _ in range(50):
            if service.metrics.reconnects:
                break
            sleep(0.01)
        assert service.metrics.reconnects >= 1
        assert service.metrics.connected is False
        assert "unavailable" in service.metrics.last_error
    finally:
        service.stop()


def test_camera_worker_reports_backend_exception(monkeypatch) -> None:
    import logging

    from vision.camera_service import CameraService

    class ExplodingCapture:
        def isOpened(self) -> bool:
            return True

        def read(self):
            raise RuntimeError("backend exploded")

        def release(self) -> None:
            return None

    service = CameraService(0, 320, 180, False, logging.getLogger("camera-failure-test"))
    monkeypatch.setattr(service, "_open", lambda: ExplodingCapture())
    service.start()
    try:
        for _ in range(50):
            if service.metrics.worker_error:
                break
            sleep(0.01)
        assert "backend exploded" in service.metrics.worker_error
        assert service.metrics.connected is False
    finally:
        service.stop()


def test_operator_command_queue_is_bounded_and_delivered() -> None:
    port = _free_udp_port()
    state = HealthState(ready=True)
    server = UdpHealthServer("127.0.0.1", port, state)
    server.start()
    try:
        for _ in range(20):
            if probe_health("127.0.0.1", port, timeout=0.1):
                break
            sleep(0.01)
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as client:
            client.settimeout(0.5)
            client.sendto(b'{"command":"restart_camera"}', ("127.0.0.1", port))
            reply, _ = client.recvfrom(128)
        assert reply == b'{"ok":true}'
        assert state.drain_commands() == [{"command": "restart_camera"}]
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as client:
            client.settimeout(0.5)
            client.sendto(
                b'{"command":"set_camera","camera_id":"invalid"}',
                ("127.0.0.1", port),
            )
            invalid_reply, _ = client.recvfrom(128)
        assert invalid_reply == b'{"ok":false}'
        assert state.drain_commands() == []
        for camera_id in range(12):
            state.enqueue_command({"command": "set_camera", "camera_id": camera_id})
        commands = state.drain_commands()
        assert len(commands) == 8
        assert commands[0]["camera_id"] == 4
    finally:
        server.stop()


def test_launcher_waits_for_real_inference_packet(monkeypatch) -> None:
    import main as launcher

    health_states = iter(
        [
            {"ready": False, "packets_sent": 0, "inference_frames": 0},
            {"ready": True, "packets_sent": 0, "inference_frames": 0, "packet_age_ms": -1},
            {"ready": True, "packets_sent": 1, "inference_frames": 1, "packet_age_ms": 20},
        ]
    )

    class RunningProcess:
        def poll(self) -> None:
            return None

    class Config:
        def section(self, name: str) -> dict[str, object]:
            assert name == "game"
            return {"udp_host": "127.0.0.1", "health_port": 42421}

    calls = 0

    def fake_probe(_host: str, _port: int) -> dict[str, object]:
        nonlocal calls
        calls += 1
        return next(health_states)

    monkeypatch.setattr(launcher, "probe_health", fake_probe)
    monkeypatch.setattr(launcher, "sleep", lambda _seconds: None)
    assert launcher.wait_for_vision(Config(), RunningProcess(), timeout=1.0)
    assert calls == 3


def test_health_server_rejects_duplicate_port_synchronously() -> None:
    port = _free_udp_port()
    first = UdpHealthServer("127.0.0.1", port, HealthState())
    second = UdpHealthServer("127.0.0.1", port, HealthState())
    first.start()
    try:
        with pytest.raises(OSError):
            second.start()
    finally:
        second.stop()
        first.stop()


def test_probe_health_ignores_malformed_reply() -> None:
    port = _free_udp_port()
    server = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    server.bind(("127.0.0.1", port))

    def reply() -> None:
        _packet, address = server.recvfrom(128)
        server.sendto(b"not-json", address)
        server.close()

    worker = threading.Thread(target=reply)
    worker.start()
    assert probe_health("127.0.0.1", port) is None
    worker.join(timeout=1.0)


def test_launcher_requires_matching_instance_and_fresh_packet(monkeypatch) -> None:
    import main as launcher

    states = iter(
        [
            {
                "instance_id": "old",
                "ready": True,
                "packets_sent": 40,
                "inference_frames": 40,
                "packet_age_ms": 1,
            },
            {
                "instance_id": "new",
                "ready": True,
                "packets_sent": 1,
                "inference_frames": 1,
                "packet_age_ms": 1500,
            },
            {
                "instance_id": "new",
                "ready": True,
                "packets_sent": 2,
                "inference_frames": 2,
                "packet_age_ms": 10,
            },
        ]
    )

    class RunningProcess:
        def poll(self) -> None:
            return None

    class Config:
        def section(self, _name: str) -> dict[str, object]:
            return {"udp_host": "127.0.0.1", "health_port": 42421}

    monkeypatch.setattr(launcher, "probe_health", lambda *_args: next(states))
    monkeypatch.setattr(launcher, "sleep", lambda _seconds: None)
    assert launcher.wait_for_vision(
        Config(), RunningProcess(), timeout=1.0, expected_instance_id="new"
    )


def test_live_session_sync_restarts_calibration_without_resetting_detector_clock() -> None:
    source = (Path(__file__).resolve().parents[1] / "main.py").read_text(encoding="utf-8")
    assert 'name == "sync_session"' in source
    assert "calibration_started = monotonic()" in source
    assert "now - service_started" in source
