from vision.frame_buffer import LatestFrameBuffer


def test_latest_frame_replaces_old_data() -> None:
    buffer: LatestFrameBuffer[str] = LatestFrameBuffer()
    first = buffer.publish("old", 1.0)
    second = buffer.publish("new", 2.0)
    assert second.sequence == first.sequence + 1
    assert buffer.latest() == second
    assert second.value == "new"


def test_closed_buffer_rejects_publish() -> None:
    buffer: LatestFrameBuffer[int] = LatestFrameBuffer()
    buffer.close()
    try:
        buffer.publish(1)
    except RuntimeError as error:
        assert "closed" in str(error)
    else:
        raise AssertionError("publish should fail after close")
