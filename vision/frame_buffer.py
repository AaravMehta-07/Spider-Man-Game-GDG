from __future__ import annotations

from dataclasses import dataclass
from threading import Condition
from time import monotonic
from typing import Generic, TypeVar

T = TypeVar("T")


@dataclass(frozen=True, slots=True)
class StampedFrame(Generic[T]):
    sequence: int
    captured_at: float
    value: T


class LatestFrameBuffer(Generic[T]):
    """Single-slot frame exchange; producers never accumulate camera latency."""

    def __init__(self) -> None:
        self._condition = Condition()
        self._latest: StampedFrame[T] | None = None
        self._sequence = 0
        self._closed = False

    def publish(self, value: T, captured_at: float | None = None) -> StampedFrame[T]:
        with self._condition:
            if self._closed:
                raise RuntimeError("frame buffer is closed")
            self._sequence += 1
            frame = StampedFrame(self._sequence, captured_at or monotonic(), value)
            self._latest = frame
            self._condition.notify_all()
            return frame

    def latest(self) -> StampedFrame[T] | None:
        with self._condition:
            return self._latest

    def wait_newer(self, sequence: int, timeout: float = 0.1) -> StampedFrame[T] | None:
        with self._condition:
            self._condition.wait_for(
                lambda: self._closed
                or (self._latest is not None and self._latest.sequence > sequence),
                timeout=timeout,
            )
            if self._latest is not None and self._latest.sequence > sequence:
                return self._latest
            return None

    def clear(self) -> None:
        with self._condition:
            self._latest = None

    def close(self) -> None:
        with self._condition:
            self._closed = True
            self._condition.notify_all()
