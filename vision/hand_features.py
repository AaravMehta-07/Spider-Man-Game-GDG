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


def is_fist(points: Sequence[HandLandmark]) -> bool:
    return all(points[tip].y > points[mcp].y for tip, mcp in ((8, 5), (12, 9), (16, 13), (20, 17)))


def is_web_pose(points: Sequence[HandLandmark]) -> bool:
    index_extended = points[8].y < points[6].y
    curled = all(points[tip].y > points[mcp].y for tip, mcp in ((12, 9), (16, 13), (20, 17)))
    thumb_open = abs(points[4].x - points[2].x) > 0.035
    return index_extended and curled and thumb_open


def is_pinching(points: Sequence[HandLandmark], threshold: float = 0.055) -> bool:
    return distance(points[4], points[8]) <= threshold


def aim_point(points: Sequence[HandLandmark]) -> tuple[float, float]:
    return max(0.0, min(1.0, points[8].x)), max(0.0, min(1.0, points[8].y))
