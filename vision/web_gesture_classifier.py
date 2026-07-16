from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass

from vision.hand_features import HandLandmark, aim_point, is_fist, is_pinching, is_web_pose


@dataclass(slots=True)
class WebActions:
    trigger: bool
    held: bool
    fist: bool
    aim_x: float
    aim_y: float
    pull: float


class WebGestureClassifier:
    def __init__(self) -> None:
        self._active = False
        self._last_fist = False
        self._last_wrist_y: float | None = None

    def classify(self, points: Sequence[HandLandmark]) -> WebActions:
        fist = is_fist(points)
        active = is_web_pose(points) or is_pinching(points) or (self._last_fist and not fist)
        trigger = active and not self._active
        wrist_y = points[0].y
        pull = 0.0
        if fist and self._last_wrist_y is not None:
            pull = max(0.0, min(1.0, (wrist_y - self._last_wrist_y) * 8.0))
        self._active = active
        self._last_fist = fist
        self._last_wrist_y = wrist_y
        x, y = aim_point(points)
        return WebActions(trigger, active, fist, x, y, pull)

    def reset(self) -> None:
        self._active = False
        self._last_fist = False
        self._last_wrist_y = None
