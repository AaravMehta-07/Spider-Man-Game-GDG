from __future__ import annotations

from collections.abc import Sequence
from math import hypot
from typing import Protocol


class HandLandmark(Protocol):
    x: float
    y: float
    z: float


def distance(a: HandLandmark, b: HandLandmark) -> float:
    return hypot(a.x - b.x, a.y - b.y)


def palm_scale(points: Sequence[HandLandmark]) -> float:
    return max(0.04, distance(points[0], points[9]))


def _extended(points: Sequence[HandLandmark], tip: int, joint: int) -> bool:
    vertical = points[tip].y < points[joint].y - palm_scale(points) * 0.06
    radial = distance(points[tip], points[0]) > distance(points[joint], points[0]) * 1.12
    return vertical or radial


def _curled(points: Sequence[HandLandmark], tip: int, joint: int) -> bool:
    vertical = points[tip].y > points[joint].y + palm_scale(points) * 0.06
    radial = distance(points[tip], points[0]) < distance(points[joint], points[0]) * 0.92
    return vertical or radial


def is_fist(points: Sequence[HandLandmark]) -> bool:
    return all(_curled(points, tip, joint) for tip, joint in ((8, 6), (12, 10), (16, 14), (20, 18)))


def is_open_palm(points: Sequence[HandLandmark]) -> bool:
    if is_fist(points):
        return False
    fingers_open = all(
        _extended(points, tip, joint) and not _curled(points, tip, joint)
        for tip, joint in ((8, 6), (12, 10), (16, 14), (20, 18))
    )
    thumb_clear = distance(points[4], points[5]) > palm_scale(points) * 0.42
    return fingers_open and thumb_clear


def is_web_pose(points: Sequence[HandLandmark]) -> bool:
    index_extended = _extended(points, 8, 6) and not _curled(points, 8, 6)
    middle_ring_curled = _curled(points, 12, 10) and _curled(points, 16, 14)
    pinky_extended = _extended(points, 20, 18) and not _curled(points, 20, 18)
    return index_extended and pinky_extended and middle_ring_curled


def is_pinching(points: Sequence[HandLandmark], threshold: float | None = None) -> bool:
    limit = (
        threshold
        if threshold is not None
        else min(0.085, max(0.035, palm_scale(points) * 0.48))
    )
    return distance(points[4], points[8]) <= limit


def aim_point(points: Sequence[HandLandmark]) -> tuple[float, float]:
    return max(0.0, min(1.0, points[8].x)), max(0.0, min(1.0, points[8].y))
