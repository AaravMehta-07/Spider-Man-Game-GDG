from dataclasses import dataclass

from vision.hand_features import aim_point, is_fist, is_pinching, is_web_pose
from vision.movement_classifier import MovementClassifier
from vision.pose_features import CalibrationProfile, PoseFeatures, calibration_from_samples
from vision.web_gesture_classifier import WebGestureClassifier


@dataclass
class Point:
    x: float = 0.5
    y: float = 0.5
    z: float = 0.0
    visibility: float = 1.0


def pose(center: float = 0.5, shoulder_y: float = 0.4, hip_y: float = 0.62) -> PoseFeatures:
    return PoseFeatures(center, shoulder_y, hip_y, 0.2, 0.42, 0.45, 0.58, 0.45, 0.95)


def neutral_hand() -> list[Point]:
    return [Point() for _ in range(21)]


def test_calibration_defaults_and_average() -> None:
    assert calibration_from_samples([]).center_x == 0.5
    result = calibration_from_samples([pose(0.4), pose(0.6)])
    assert result.center_x == 0.5
    assert result.shoulder_width == 0.2


def test_movement_jump_crouch_and_lean() -> None:
    classifier = MovementClassifier(CalibrationProfile(0.5, 0.4, 0.62, 0.2))
    right = classifier.classify(pose(center=0.62), 0.0)
    assert right.move > 0.5
    jumping = classifier.classify(pose(center=0.62, hip_y=0.58), 0.1)
    assert jumping.jump is True
    crouching = classifier.classify(pose(center=0.62, shoulder_y=0.44), 0.2)
    assert crouching.crouch is True


def test_hand_shapes_and_aim() -> None:
    points = neutral_hand()
    for tip, mcp in ((8, 5), (12, 9), (16, 13), (20, 17)):
        points[tip].y = 0.7
        points[mcp].y = 0.5
    assert is_fist(points)
    points[8].y = 0.3
    points[6].y = 0.5
    points[4].x = 0.7
    points[2].x = 0.5
    assert is_web_pose(points)
    points[4].x = points[8].x
    points[4].y = points[8].y
    assert is_pinching(points)
    assert aim_point(points) == (points[8].x, points[8].y)


def test_web_trigger_is_edge_based() -> None:
    points = neutral_hand()
    points[8].y = 0.3
    points[6].y = 0.5
    points[4].x = 0.7
    points[2].x = 0.5
    for tip, mcp in ((12, 9), (16, 13), (20, 17)):
        points[tip].y = 0.7
        points[mcp].y = 0.5
    classifier = WebGestureClassifier()
    assert classifier.classify(points).trigger is True
    assert classifier.classify(points).trigger is False
