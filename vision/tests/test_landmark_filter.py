import pytest

from vision.landmark_filter import HysteresisGate, OneEuroLite


def test_filter_smooths_and_resets() -> None:
    filter_ = OneEuroLite(alpha=0.5)
    assert filter_.update(0.0) == 0.0
    assert 0.0 < filter_.update(1.0) < 1.0
    filter_.reset()
    assert filter_.update(0.75) == 0.75


def test_hysteresis_prevents_threshold_chatter() -> None:
    gate = HysteresisGate(enter=0.7, exit=0.4)
    assert gate.update(0.6) is False
    assert gate.update(0.8) is True
    assert gate.update(0.5) is True
    assert gate.update(0.3) is False
    with pytest.raises(ValueError):
        HysteresisGate(0.4, 0.5)
