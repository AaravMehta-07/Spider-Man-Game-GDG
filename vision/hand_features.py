from __future__ import annotations

from collections.abc import Sequence
from math import sqrt
from typing import Protocol


class HandLandmark(Protocol):
    x: float
    y: float
    z: float


def distance(a: HandLandmark, b: HandLandmark) -> float:
    return sqrt((a.x - b.x) ** 2 + (a.y - b.y) ** 2)


def distance_3d(a: HandLandmark, b: HandLandmark) -> float:
    return sqrt((a.x - b.x) ** 2 + (a.y - b.y) ** 2 + (a.z - b.z) ** 2)


def palm_scale(points: Sequence[HandLandmark]) -> float:
    return max(0.04, distance(points[0], points[9]))


def _finger_straightness(points: Sequence[HandLandmark], tip: int, joint: int) -> float:
    base = points[max(0, joint - 1)]
    first = (
        points[joint].x - base.x,
        points[joint].y - base.y,
        points[joint].z - base.z,
    )
    second = (
        points[tip].x - points[joint].x,
        points[tip].y - points[joint].y,
        points[tip].z - points[joint].z,
    )
    first_length = sqrt(sum(component * component for component in first))
    second_length = sqrt(sum(component * component for component in second))
    if first_length < 0.01 or second_length < 0.01:
        return -1.0
    return sum(a * b for a, b in zip(first, second, strict=True)) / (first_length * second_length)


def _points_outward(points: Sequence[HandLandmark], tip: int, joint: int) -> bool:
    """Return whether a fingertip points away from the palm, independent of rotation."""
    wrist = points[0]
    palm_axis = (
        points[9].x - wrist.x,
        points[9].y - wrist.y,
        points[9].z - wrist.z,
    )
    finger_axis = (
        points[tip].x - points[joint].x,
        points[tip].y - points[joint].y,
        points[tip].z - points[joint].z,
    )
    palm_length = sqrt(sum(component * component for component in palm_axis))
    finger_length = sqrt(sum(component * component for component in finger_axis))
    if palm_length > 0.025 and finger_length > 0.015:
        alignment = sum(a * b for a, b in zip(palm_axis, finger_axis, strict=True))
        directionally_outward = alignment / (palm_length * finger_length) > 0.08
    else:
        # Defensive fallback for incomplete or synthetic landmark sets.
        directionally_outward = points[tip].y < points[joint].y
    scale = max(0.04, distance_3d(wrist, points[9]))
    reaches_outward = (
        distance_3d(points[tip], wrist) > distance_3d(points[joint], wrist) + scale * 0.015
    )
    straight_enough = _finger_straightness(points, tip, joint) > 0.35
    return reaches_outward and (directionally_outward or straight_enough)


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
    if is_fist(points):
        return False
    # Classic Spider-Man pose: index + pinky out, middle + ring folded.
    # Directional extension works with a rotated hand while rejecting a fist,
    # pinch, or single pointing finger.
    index_extended = _points_outward(points, 8, 6)
    middle_ring_folded = (
        (_curled(points, 12, 10) or not _points_outward(points, 12, 10))
        and (_curled(points, 16, 14) or not _points_outward(points, 16, 14))
    )
    pinky_extended = _points_outward(points, 20, 18)
    return index_extended and pinky_extended and middle_ring_folded


def is_pinching(points: Sequence[HandLandmark], threshold: float | None = None) -> bool:
    limit = (
        threshold if threshold is not None else min(0.085, max(0.035, palm_scale(points) * 0.48))
    )
    return distance(points[4], points[8]) <= limit


def aim_point(points: Sequence[HandLandmark]) -> tuple[float, float]:
    return max(0.0, min(1.0, points[8].x)), max(0.0, min(1.0, points[8].y))
