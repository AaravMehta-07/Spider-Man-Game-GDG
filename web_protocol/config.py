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
        self._number(game, "session_seconds", 60.0, 90.0)
        self._number(vision, "camera_id", 0, 16)
        self._number(vision, "target_fps", 10, 60)
        self._number(network, "snapshot_hz", 10, 60)
        for port_key, section in (("udp_port", game), ("health_port", game)):
            self._number(section, port_key, 1024, 65535)

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
