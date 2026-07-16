from vision.protocol import InputSnapshot, decode_snapshot, encode_snapshot


def test_snapshot_round_trip_and_clamping() -> None:
    source = InputSnapshot(
        sequence=7,
        session_id="demo",
        move=2.0,
        aim_x=-0.5,
        pull=1.4,
        web_right=True,
    )
    decoded = decode_snapshot(encode_snapshot(source))
    assert decoded.sequence == 7
    assert decoded.move == 1.0
    assert decoded.aim_x == 0.0
    assert decoded.pull == 1.0
    assert decoded.web_right is True
