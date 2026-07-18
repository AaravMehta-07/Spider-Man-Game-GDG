from vision.protocol import InputSnapshot, decode_snapshot, encode_snapshot


def test_snapshot_round_trip_and_clamping() -> None:
    source = InputSnapshot(
        sequence=7,
        session_id="demo",
        move=2.0,
        aim_x=-0.5,
        aim_left_x=1.4,
        aim_right_y=-0.2,
        pull=1.4,
        web_right=True,
        web_right_trigger=True,
        fist_right=True,
        palm_open_left=True,
        gesture_right="FIST",
    )
    decoded = decode_snapshot(encode_snapshot(source))
    assert decoded.sequence == 7
    assert decoded.move == 1.0
    assert decoded.aim_x == 0.0
    assert decoded.aim_left_x == 1.0
    assert decoded.aim_right_y == 0.0
    assert decoded.pull == 1.0
    assert decoded.web_right is True
    assert decoded.web_right_trigger is True
    assert decoded.fist_right is True
    assert decoded.palm_open_left is True
    assert decoded.gesture_right == "FIST"


def test_snapshot_rejects_unknown_gesture_labels() -> None:
    source = InputSnapshot(sequence=1, session_id="gesture", gesture_left="UNBOUNDED")
    assert decode_snapshot(encode_snapshot(source)).gesture_left == "OPEN"
