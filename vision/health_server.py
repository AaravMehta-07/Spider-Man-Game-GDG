from __future__ import annotations

import json
import socket
import threading
from dataclasses import dataclass, field
from time import monotonic


@dataclass(slots=True)
class HealthState:
    ready: bool = False
    mode: str = "starting"
    camera_fps: float = 0.0
    inference_fps: float = 0.0
    packets_sent: int = 0
    started_at: float = field(default_factory=monotonic)

    def payload(self) -> bytes:
        return json.dumps(
            {
                "ready": self.ready,
                "mode": self.mode,
                "camera_fps": round(self.camera_fps, 2),
                "inference_fps": round(self.inference_fps, 2),
                "packets_sent": self.packets_sent,
                "uptime": round(monotonic() - self.started_at, 2),
            },
            separators=(",", ":"),
        ).encode("ascii")


class UdpHealthServer:
    def __init__(self, host: str, port: int, state: HealthState) -> None:
        self.host = host
        self.port = port
        self.state = state
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None

    def start(self) -> None:
        self._thread = threading.Thread(target=self._run, name="vision-health", daemon=True)
        self._thread.start()

    def stop(self) -> None:
        self._stop.set()
        if self._thread:
            self._thread.join(timeout=1.0)

    def _run(self) -> None:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as server:
            server.settimeout(0.2)
            server.bind((self.host, self.port))
            while not self._stop.is_set():
                try:
                    _, address = server.recvfrom(128)
                    server.sendto(self.state.payload(), address)
                except TimeoutError:
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
    return json.loads(packet.decode("ascii"))
