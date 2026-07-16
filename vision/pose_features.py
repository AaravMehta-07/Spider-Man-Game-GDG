from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass
from math import hypot
from typing import Protocol


class Landmark(Protocol):
    x: float
    y: float
    z: float
    visibility: float


@dataclass(frozen=True, slots=True)
class PoseFeatures:
    center_x: float
    shoulder_y: float
    hip_y: float
    shoulder_width: float
    left_wrist_x: float
    left_wrist_y: float
    right_wrist_x: float
    right_wrist_y: float
    confidence: float


def extract_pose(landmarks: Sequence[Landmark]) -> PoseFeatures:
    if len(landmarks) < 29:
        raise ValueError("pose requires 29 landmarks")
    left_shoulder, right_shoulder = landmarks[11], landmarks[12]
    left_wrist, right_wrist = landmarks[15], landmarks[16]
    left_hip, right_hip = landmarks[23], landmarks[24]
    center_x = (left_shoulder.x + right_shoulder.x + left_hip.x + right_hip.x) * 0.25
    confidence = min(
        left_shoulder.visibility,
        right_shoulder.visibility,
        left_hip.visibility,
        right_hip.visibility,
    )
    return PoseFeatures(
        center_x=center_x,
        shoulder_y=(left_shoulder.y + right_shoulder.y) * 0.5,
        hip_y=(left_hip.y + right_hip.y) * 0.5,
        shoulder_width=max(
            0.05, hypot(left_shoulder.x - right_shoulder.x, left_shoulder.y - right_shoulder.y)
        ),
        left_wrist_x=left_wrist.x,
        left_wrist_y=left_wrist.y,
        right_wrist_x=right_wrist.x,
        right_wrist_y=right_wrist.y,
        confidence=confidence,
    )


@dataclass(frozen=True, slots=True)
class CalibrationProfile:
    center_x: float
    shoulder_y: float
    hip_y: float
    shoulder_width: float


def calibration_from_samples(samples: Sequence[PoseFeatures]) -> CalibrationProfile:
    if not samples:
        return CalibrationProfile(0.5, 0.42, 0.62, 0.22)
    count = float(len(samples))
    return CalibrationProfile(
        sum(item.center_x for item in samples) / count,
        sum(item.shoulder_y for item in samples) / count,
        sum(item.hip_y for item in samples) / count,
        max(0.08, sum(item.shoulder_width for item in samples) / count),
    )
