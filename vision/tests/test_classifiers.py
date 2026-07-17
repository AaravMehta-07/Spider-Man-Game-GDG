from dataclasses import dataclass

from vision.hand_features import aim_point, is_fist, is_open_palm, is_pinching, is_web_pose
from vision.main import _snapshot, calibration_profile_when_ready
from vision.movement_classifier import BodyActions, MovementClassifier
from vision.pose_features import CalibrationProfile, PoseFeatures, calibration_from_samples
from vision.web_gesture_classifier import WebActions, WebGestureClassifier


@dataclass
class Point:
    x: float = 0.5
    y: float = 0.5
    z: float = 0.0
    visibility: float = 1.0


def pose(center: float = 0.5, shoulder_y: float = 0.4, hip_y: float = 0.62) -> PoseFeatures:
    return PoseFeatures(center, shoulder_y, hip_y, 0.2, 0.42, 0.45, 0.58, 0.45, 0.95)


def neutral_hand() -> list[Point]:
    points = [Point() for _ in range(21)]
    points[4].x = 0.3
    points[8].x = 0.7
    return points


def web_hand() -> list[Point]:
    points = neutral_hand()
    points[8].y = 0.3
    points[6].y = 0.5
    points[4].x = 0.7
    points[2].x = 0.5
    for tip, mcp in ((12, 9), (16, 13), (20, 17)):
        points[tip].y = 0.7
        points[mcp].y = 0.5
    return points


def classic_spider_hand() -> list[Point]:
    points = web_hand()
    points[20].y = 0.3
    points[18].y = 0.5
    return points


def fist_hand(wrist_y: float = 0.5) -> list[Point]:
    points = neutral_hand()
    points[0].y = wrist_y
    for tip, mcp in ((8, 5), (12, 9), (16, 13), (20, 17)):
        points[tip].y = 0.7
        points[mcp].y = 0.5
    return points


def open_hand() -> list[Point]:
    points = neutral_hand()
    points[0] = Point(0.5, 0.75)
    points[9] = Point(0.5, 0.52)
    points[4] = Point(0.22, 0.48)
    points[5] = Point(0.42, 0.55)
    for tip, joint in ((8, 6), (12, 10), (16, 14), (20, 18)):
        points[tip] = Point(points[joint].x, 0.2)
        points[joint].y = 0.45
    return points


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


def test_classic_index_and_pinky_spider_pose_is_recognized() -> None:
    assert is_web_pose(classic_spider_hand())
    action = WebGestureClassifier().classify(classic_spider_hand(), 0.0)
    assert action.trigger and action.held and action.gesture == "SPIDER_POSE"


def test_open_palm_is_explicit_not_an_unknown_hand_shape() -> None:
    assert is_open_palm(open_hand())
    assert not is_open_palm(fist_hand())
    assert WebGestureClassifier().classify(open_hand(), 0.0).open_palm


def test_snapshot_preserves_two_hand_average_aim() -> None:
    left = WebActions(True, True, False, 0.2, 0.3, 0.0, "SPIDER_POSE")
    right = WebActions(False, True, False, 0.8, 0.7, 0.0, "PINCH")
    snapshot = _snapshot(1, "average", None, BodyActions(), {"Left": left, "Right": right})
    assert snapshot.aim_x == 0.5
    assert snapshot.aim_y == 0.5
    assert snapshot.web_left_trigger is True
    assert snapshot.gesture_right == "PINCH"
    assert snapshot.aim_left_x == 0.2 and snapshot.aim_right_x == 0.8


def test_web_trigger_is_edge_based() -> None:
    points = web_hand()
    classifier = WebGestureClassifier()
    assert classifier.classify(points).trigger is True
    assert classifier.classify(points).trigger is False


def test_web_attachment_stays_latched_through_fist_pull_then_releases() -> None:
    classifier = WebGestureClassifier()
    fired = classifier.classify(web_hand(), 0.0)
    pulled = classifier.classify(fist_hand(0.55), 0.1)
    classifier.classify(neutral_hand(), 0.2)
    released = classifier.classify(neutral_hand(), 0.4)
    assert fired.trigger and fired.held
    assert pulled.held and pulled.fist and pulled.pull > 0.9
    assert not released.held


def test_pull_strength_is_frame_rate_independent() -> None:
    strengths: list[float] = []
    for fps in (10, 18, 30, 60):
        classifier = WebGestureClassifier()
        classifier.classify(web_hand(), 0.0)
        elapsed = 1.0 / fps
        strengths.append(classifier.classify(fist_hand(0.5 + 0.3 * elapsed), elapsed).pull)
    assert max(strengths) - min(strengths) < 0.01
    assert min(strengths) > 0.8


def test_missing_hand_resets_attachment_and_fist_becomes_a_new_shot() -> None:
    classifier = WebGestureClassifier()
    classifier.classify(web_hand(), 0.0)
    for _ in range(3):
        classifier.mark_missing()
    action = classifier.classify(fist_hand(0.8), 1.0)
    assert action.trigger and action.held and action.pull == 0.0
    assert action.gesture == "FIST_SHOT"


def test_calibration_waits_for_timeout_and_rejects_single_sample_profile() -> None:
    samples = [pose(center=0.8)]
    assert calibration_profile_when_ready(samples * 24, 1.0, 5.5, 24) is None
    fallback = calibration_profile_when_ready(samples, 5.5, 5.5, 24)
    assert fallback is not None and fallback.center_x == 0.5
    measured = calibration_profile_when_ready([pose(center=0.6)] * 8, 5.5, 5.5, 24)
    assert measured is not None and measured.center_x == 0.6
