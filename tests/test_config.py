from pathlib import Path

import pytest

from web_protocol.config import ConfigurationError, ProjectConfig


def test_project_configuration_loads() -> None:
    root = Path(__file__).resolve().parents[1]
    config = ProjectConfig.load(root)
    assert config.section("game")["session_seconds"] == 90.0


def test_invalid_configuration_is_rejected(tmp_path: Path) -> None:
    (tmp_path / "config").mkdir()
    (tmp_path / "config" / "shared.yaml").write_text(
        "game: {session_seconds: 100, udp_port: 42420, health_port: 42421}\n"
        "vision: {camera_id: 0, target_fps: 30}\n"
        "network: {snapshot_hz: 30}\n",
        encoding="utf-8",
    )
    (tmp_path / "config" / "vision.yaml").write_text("{}\n", encoding="utf-8")
    with pytest.raises(ConfigurationError):
        ProjectConfig.load(tmp_path)
