from __future__ import annotations

import socket
from time import sleep

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
        for camera_id in range(12):
            state.enqueue_command({"command": "set_camera", "camera_id": camera_id})
        commands = state.drain_commands()
        assert len(commands) == 8
        assert commands[0]["camera_id"] == 4
    finally:
        server.stop()