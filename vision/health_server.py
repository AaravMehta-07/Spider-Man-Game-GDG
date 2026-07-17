from __future__ import annotations

import json
import os
import socket
import threading
from contextlib import suppress
from dataclasses import dataclass, field
from queue import Empty, Full, Queue
from time import monotonic
from uuid import uuid4


@dataclass(slots=True)
class HealthState:
    ready: bool = False
    mode: str = "starting"
    camera_connected: bool = False
    selected_camera: int = -1
    camera_fps: float = 0.0
    inference_fps: float = 0.0
    hand_fps: float = 0.0
    frames_captured: int = 0
    inference_frames: int = 0
    packets_sent: int = 0
    reconnects: int = 0
    calibrated: bool = False
    calibration_samples: int = 0
    instance_id: str = field(default_factory=lambda: uuid4().hex)
    process_id: int = field(default_factory=os.getpid)
    last_error: str = ""
    started_at: float = field(default_factory=monotonic)
    last_packet_at: float | None = None
    commands: Queue[dict[str, object]] = field(default_factory=lambda: Queue(maxsize=8))

    def mark_packet(self) -> None:
        self.packets_sent += 1
        self.last_packet_at = monotonic()

    def payload(self) -> bytes:
        return json.dumps(
            {
                "ready": self.ready,
                "mode": self.mode,
                "camera_connected": self.camera_connected,
                "selected_camera": self.selected_camera,
                "camera_fps": round(self.camera_fps, 2),
                "inference_fps": round(self.inference_fps, 2),
                "hand_fps": round(self.hand_fps, 2),
                "frames_captured": self.frames_captured,
                "inference_frames": self.inference_frames,
                "packets_sent": self.packets_sent,
                "reconnects": self.reconnects,
                "last_error": self.last_error,
                "uptime": round(monotonic() - self.started_at, 2),
                'calibrated': self.calibrated,
                'calibration_samples': self.calibration_samples,
                'instance_id': self.instance_id,
                'process_id': self.process_id,
                'packet_age_ms': round((monotonic() - self.last_packet_at) * 1000.0, 1)
                if self.last_packet_at is not None
                else -1.0,
            },
            separators=(",", ":"),
        ).encode("ascii")

    def enqueue_command(self, command: dict[str, object]) -> None:
        try:
            self.commands.put_nowait(command)
        except Full:
            with suppress(Empty):
                self.commands.get_nowait()
            self.commands.put_nowait(command)

    def drain_commands(self) -> list[dict[str, object]]:
        drained: list[dict[str, object]] = []
        while True:
            try:
                drained.append(self.commands.get_nowait())
            except Empty:
                return drained


class UdpHealthServer:
    def __init__(self, host: str, port: int, state: HealthState) -> None:
        self.host = host
        self.port = port
        self.state = state
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None
        self._socket: socket.socket | None = None

    def start(self) -> None:
        if self._thread is not None and self._thread.is_alive():
            return
        server = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        server.settimeout(0.2)
        try:
            server.bind((self.host, self.port))
        except OSError:
            server.close()
            raise
        self._socket = server
        self._thread = threading.Thread(target=self._run, name="vision-health", daemon=True)
        self._thread.start()

    def stop(self) -> None:
        self._stop.set()
        if self._socket is not None:
            self._socket.close()
        if self._thread:
            self._thread.join(timeout=1.0)
        self._socket = None

    @staticmethod
    def _valid_command(command: dict[str, object]) -> bool:
        name = command.get('command')
        if name in {'sync_session', 'restart_camera'}:
            return len(command) == 1
        if name == 'set_camera':
            camera_id = command.get('camera_id')
            return (
                len(command) == 2
                and isinstance(camera_id, int)
                and not isinstance(camera_id, bool)
                and 0 <= camera_id <= 16
            )
        if name == 'set_mirror':
            return len(command) == 2 and isinstance(command.get('enabled'), bool)
        return False

    def _run(self) -> None:
        server = self._socket
        if server is not None:
            server.settimeout(0.2)
            # The socket is bound synchronously in start so failures reach the launcher.
            while not self._stop.is_set():
                try:
                    packet, address = server.recvfrom(2048)
                    if packet == b"health":
                        server.sendto(self.state.payload(), address)
                        continue
                    command = json.loads(packet.decode("ascii"))
                    if isinstance(command, dict) and self._valid_command(command):
                        self.state.enqueue_command(command)
                        server.sendto(b'{"ok":true}', address)
                    else:
                        server.sendto(b'{"ok":false}', address)
                except (UnicodeError, json.JSONDecodeError):
                    continue
                except (TimeoutError, ConnectionResetError):
                    continue
                except OSError:
                    if not self._stop.is_set():
                        raise


def probe_health(host: str, port: int, timeout: float = 0.25) -> dict[str, object] | None:
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as client:
        client.settimeout(timeout)
        client.sendto(b"health", (host, port))
        try:
            packet, _ = client.recvfrom(2048)
        except (TimeoutError, OSError):
            return None
    try:
        payload = json.loads(packet.decode("ascii"))
    except (UnicodeError, json.JSONDecodeError):
        return None
    return payload if isinstance(payload, dict) else None
