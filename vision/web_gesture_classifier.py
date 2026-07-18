from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass
from time import monotonic

from vision.hand_features import (
    HandLandmark,
    aim_point,
    is_fist,
    is_open_palm,
    is_pinching,
    is_web_pose,
)


@dataclass(slots=True)
class WebActions:
    trigger: bool
    held: bool
    fist: bool
    aim_x: float
    aim_y: float
    pull: float
    gesture: str
    open_palm: bool = False


class WebGestureClassifier:
    def __init__(
        self,
        pull_velocity: float = 0.35,
        release_grace: float = 0.14,
        trigger_hold: float = 0.08,
    ) -> None:
        self._active = False
        self._last_wrist_y: float | None = None
        self._last_time: float | None = None
        self._missing_frames = 0
        self._last_web_signal = False
        self._web_pose_started: float | None = None
        self._release_started: float | None = None
        self._cooldown_until = 0.0
        self.pull_velocity = max(0.05, pull_velocity)
        self.release_grace = max(0.05, release_grace)
        self.trigger_hold = max(0.0, trigger_hold)

    def classify(
        self, points: Sequence[HandLandmark], timestamp: float | None = None
    ) -> WebActions:
        now = monotonic() if timestamp is None else timestamp
        fist = is_fist(points)
        web_pose = is_web_pose(points)
        pinch = is_pinching(points)
        if web_pose:
            if self._web_pose_started is None:
                self._web_pose_started = now
            web_signal = now - self._web_pose_started + 1e-9 >= self.trigger_hold
        else:
            self._web_pose_started = None
            web_signal = False
        was_active = self._active
        trigger_candidate = not was_active and web_signal and not self._last_web_signal
        trigger = trigger_candidate and now >= self._cooldown_until
        if trigger:
            self._cooldown_until = now + 0.22
        if web_signal or (fist and was_active):
            active = True
            self._release_started = None
        elif was_active:
            if self._release_started is None:
                self._release_started = now
            active = now - self._release_started < self.release_grace
        else:
            active = False
        wrist_y = points[0].y
        pull = 0.0
        if fist and active and self._last_wrist_y is not None and self._last_time is not None:
            elapsed = max(0.001, now - self._last_time)
            velocity = (wrist_y - self._last_wrist_y) / elapsed
            pull = max(0.0, min(1.0, velocity / self.pull_velocity))
        self._active = active
        self._last_web_signal = web_signal
        self._last_wrist_y = wrist_y
        self._last_time = now
        self._missing_frames = 0
        x, y = aim_point(points)
        if fist and was_active:
            gesture = "PULL"
        elif fist:
            gesture = "FIST"
        elif web_pose:
            gesture = "SPIDER_POSE"
        elif pinch:
            gesture = "PINCH"
        elif active:
            gesture = "WEB_HELD"
        else:
            gesture = "OPEN"
        return WebActions(trigger, active, fist, x, y, pull, gesture, is_open_palm(points))

    def mark_missing(self) -> None:
        self._missing_frames += 1
        if self._missing_frames >= 3:
            self.reset()

    def reset(self) -> None:
        self._active = False
        self._last_wrist_y = None
        self._last_time = None
        self._missing_frames = 0
        self._last_web_signal = False
        self._web_pose_started = None
        self._release_started = None
        self._cooldown_until = 0.0
