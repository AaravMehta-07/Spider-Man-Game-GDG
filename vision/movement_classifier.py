from __future__ import annotations

from dataclasses import dataclass

from vision.landmark_filter import HysteresisGate, OneEuroLite
from vision.pose_features import CalibrationProfile, PoseFeatures


@dataclass(slots=True)
class BodyActions:
    move: float = 0.0
    jump: bool = False
    crouch: bool = False
    dodge_left: bool = False
    dodge_right: bool = False
    shield: bool = False


class MovementClassifier:
    def __init__(
        self,
        profile: CalibrationProfile,
        lean_threshold: float = 0.075,
        jump_threshold: float = 0.10,
        crouch_threshold: float = 0.12,
        dodge_velocity: float = 0.85,
    ) -> None:
        self.profile = profile
        self.lean_threshold = lean_threshold
        self.jump_threshold = jump_threshold
        self.crouch_threshold = crouch_threshold
        self.dodge_velocity = dodge_velocity
        self.jump_gate = HysteresisGate(jump_threshold, jump_threshold * 0.55)
        self.crouch_gate = HysteresisGate(crouch_threshold, crouch_threshold * 0.55)
        self.center_filter = OneEuroLite(0.55)
        self._last_center: float | None = None
        self._last_time: float | None = None
        self._dodge_cooldown_until = 0.0

    def classify(self, pose: PoseFeatures, timestamp: float) -> BodyActions:
        center = self.center_filter.update(pose.center_x, pose.confidence)
        offset = (center - self.profile.center_x) / self.profile.shoulder_width
        move = 0.0
        if abs(offset) >= self.lean_threshold:
            move = max(-1.0, min(1.0, offset * 3.2))
        jump_amount = (self.profile.hip_y - pose.hip_y) / self.profile.shoulder_width
        crouch_amount = (pose.shoulder_y - self.profile.shoulder_y) / self.profile.shoulder_width
        velocity = 0.0
        if self._last_center is not None and self._last_time is not None:
            elapsed = max(0.001, timestamp - self._last_time)
            velocity = (center - self._last_center) / elapsed
        dodge_left = velocity < -self.dodge_velocity and timestamp >= self._dodge_cooldown_until
        dodge_right = velocity > self.dodge_velocity and timestamp >= self._dodge_cooldown_until
        if dodge_left or dodge_right:
            self._dodge_cooldown_until = timestamp + 0.55
        self._last_center = center
        self._last_time = timestamp
        wrists_up = pose.left_wrist_y < pose.shoulder_y and pose.right_wrist_y < pose.shoulder_y
        wrists_close = abs(pose.left_wrist_x - pose.right_wrist_x) < pose.shoulder_width * 0.75
        return BodyActions(
            move=move,
            jump=self.jump_gate.update(jump_amount),
            crouch=self.crouch_gate.update(crouch_amount),
            dodge_left=dodge_left,
            dodge_right=dodge_right,
            shield=wrists_up and wrists_close,
        )

    def reset(self) -> None:
        self.jump_gate.reset()
        self.crouch_gate.reset()
        self.center_filter.reset()
        self._last_center = None
        self._last_time = None
        self._dodge_cooldown_until = 0.0
