from __future__ import annotations

from copy import deepcopy
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import yaml


class ConfigurationError(ValueError):
    pass


def _merge(base: dict[str, Any], override: dict[str, Any]) -> dict[str, Any]:
    merged = deepcopy(base)
    for key, value in override.items():
        if isinstance(value, dict) and isinstance(merged.get(key), dict):
            merged[key] = _merge(merged[key], value)
        else:
            merged[key] = value
    return merged


def _load_yaml(path: Path, required: bool = True) -> dict[str, Any]:
    if not path.exists():
        if required:
            raise ConfigurationError(f"Missing configuration file: {path}")
        return {}
    try:
        loaded = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    except (OSError, yaml.YAMLError) as error:
        raise ConfigurationError(f"Cannot read {path}: {error}") from error
    if not isinstance(loaded, dict):
        raise ConfigurationError(f"Configuration root must be a mapping: {path}")
    return loaded


@dataclass(frozen=True, slots=True)
class ProjectConfig:
    root: Path
    values: dict[str, Any]

    @classmethod
    def load(cls, root: Path) -> ProjectConfig:
        values = _load_yaml(root / "config" / "shared.yaml")
        values = _merge(values, _load_yaml(root / "config" / "vision.yaml"))
        values = _merge(values, _load_yaml(root / "config" / "local.yaml", required=False))
        config = cls(root=root, values=values)
        config.validate()
        return config

    def validate(self) -> None:
        game = self.section("game")
        vision = self.section("vision")
        network = self.section("network")
        calibration = self.section("calibration")
        gestures = self.section("gestures")
        models = self.section("models")
        self._number(game, "session_seconds", 90.0, 90.0)
        self._number(vision, "camera_id", 0, 16)
        self._number(vision, "target_fps", 10, 60)
        self._number(vision, "capture_width", 320, 3840)
        self._number(vision, "capture_height", 180, 2160)
        self._number(vision, "inference_width", 160, 1920)
        self._number(vision, "inference_height", 90, 1080)
        self._number(vision, "pose_confidence", 0.1, 1.0)
        self._number(vision, "hand_confidence", 0.1, 1.0)
        self._number(vision, "stale_after_ms", 100, 2000)
        self._number(network, "snapshot_hz", 10, 60)
        self._number(network, "queue_size", 1, 8)
        self._number(calibration, "duration_seconds", 1.0, 10.0)
        self._number(calibration, "minimum_samples", 4, 300)
        self._number(calibration, "lean_threshold", 0.01, 0.5)
        self._number(calibration, "jump_threshold", 0.01, 0.5)
        self._number(calibration, "crouch_threshold", 0.01, 0.5)
        self._number(calibration, "dodge_velocity_threshold", 0.1, 5.0)
        self._number(gestures, "pull_threshold", 0.01, 1.0)
        for port_key, section in (("udp_port", game), ("health_port", game)):
            self._number(section, port_key, 1024, 65535)
        if game.get("udp_host") != "127.0.0.1":
            raise ConfigurationError("udp_host must be 127.0.0.1 for offline localhost operation")
        if int(game["udp_port"]) == int(game["health_port"]):
            raise ConfigurationError("udp_port and health_port must be different")
        for model_key in ("pose", "hands"):
            value = models.get(model_key)
            if not isinstance(value, str) or not value.strip():
                raise ConfigurationError(f"models.{model_key} must be a non-empty path")

    def section(self, name: str) -> dict[str, Any]:
        section = self.values.get(name)
        if not isinstance(section, dict):
            raise ConfigurationError(f"Missing configuration section: {name}")
        return section

    @staticmethod
    def _number(section: dict[str, Any], key: str, minimum: float, maximum: float) -> None:
        value = section.get(key)
        if not isinstance(value, int | float) or isinstance(value, bool):
            raise ConfigurationError(f"{key} must be numeric")
        if not minimum <= float(value) <= maximum:
            raise ConfigurationError(f"{key} must be between {minimum} and {maximum}")
