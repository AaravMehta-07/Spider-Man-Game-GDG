from __future__ import annotations

import json
from dataclasses import asdict, dataclass, field
from time import monotonic_ns
from typing import Any

PROTOCOL_VERSION = 1
MAX_PACKET_BYTES = 8192


@dataclass(slots=True)
class InputSnapshot:
    sequence: int
    session_id: str
    timestamp_ns: int = field(default_factory=monotonic_ns)
    tracked: bool = False
    pose_confidence: float = 0.0
    hand_confidence: float = 0.0
    move: float = 0.0
    aim_x: float = 0.5
    aim_y: float = 0.5
    jump: bool = False
    crouch: bool = False
    dodge_left: bool = False
    dodge_right: bool = False
    shield: bool = False
    web_left: bool = False
    web_right: bool = False
    pull: float = 0.0
    two_hand_pull: float = 0.0
    events: list[dict[str, Any]] = field(default_factory=list)

    def normalized(self) -> InputSnapshot:
        self.move = max(-1.0, min(1.0, float(self.move)))
        self.aim_x = max(0.0, min(1.0, float(self.aim_x)))
        self.aim_y = max(0.0, min(1.0, float(self.aim_y)))
        self.pull = max(0.0, min(1.0, float(self.pull)))
        self.two_hand_pull = max(0.0, min(1.0, float(self.two_hand_pull)))
        self.pose_confidence = max(0.0, min(1.0, float(self.pose_confidence)))
        self.hand_confidence = max(0.0, min(1.0, float(self.hand_confidence)))
        return self


def encode_snapshot(snapshot: InputSnapshot) -> bytes:
    payload = {"v": PROTOCOL_VERSION, "kind": "input", "data": asdict(snapshot.normalized())}
    encoded = json.dumps(payload, separators=(",", ":"), ensure_ascii=True).encode("utf-8")
    if len(encoded) > MAX_PACKET_BYTES:
        raise ValueError(f"UDP packet exceeds {MAX_PACKET_BYTES} bytes")
    return encoded


def decode_snapshot(packet: bytes) -> InputSnapshot:
    if len(packet) > MAX_PACKET_BYTES:
        raise ValueError("oversized UDP packet")
    payload = json.loads(packet.decode("utf-8"))
    if payload.get("v") != PROTOCOL_VERSION or payload.get("kind") != "input":
        raise ValueError("unsupported protocol packet")
    return InputSnapshot(**payload["data"]).normalized()
