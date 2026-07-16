from __future__ import annotations

import importlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from tools.locate_godot import godot_version, locate_godot  # noqa: E402
from web_protocol.config import ProjectConfig  # noqa: E402


def main() -> int:
    checks: dict[str, object] = {}
    checks["python"] = sys.version.split()[0]
    checks["python_ok"] = sys.version_info[:2] == (3, 11)
    for module in ("cv2", "mediapipe", "numpy", "yaml", "psutil"):
        try:
            importlib.import_module(module)
            checks[f"import_{module}"] = True
        except Exception as error:
            checks[f"import_{module}"] = str(error)
    config = ProjectConfig.load(ROOT)
    checks["config_ok"] = config.section("game")["session_seconds"] == 90.0
    game_defaults = json.loads((ROOT / "game" / "config" / "game_defaults.json").read_text())
    checks["game_defaults_ok"] = (
        game_defaults["session"]["duration_seconds"] == 90.0
        and game_defaults["display"]["target_fps"] == 60
    )
    godot = locate_godot()
    checks["godot"] = str(godot) if godot else None
    checks["godot_version"] = godot_version(godot) if godot else None
    checks["models"] = {
        path.name: path.stat().st_size
        for path in (ROOT / "vision" / "models").glob("*.task")
        if path.stat().st_size > 1_000_000
    }
    checks["camera_probe_deferred"] = "Camera is tested at launch to avoid locking it during setup."
    print(json.dumps(checks, indent=2))
    required = [
        checks["python_ok"],
        checks["config_ok"],
        checks["game_defaults_ok"],
        bool(godot),
        len(checks["models"]) == 2,
    ]
    required.extend(
        checks[f"import_{name}"] is True for name in ("cv2", "mediapipe", "numpy", "yaml")
    )
    return 0 if all(required) else 1


if __name__ == "__main__":
    raise SystemExit(main())
