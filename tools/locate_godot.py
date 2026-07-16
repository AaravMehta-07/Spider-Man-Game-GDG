from __future__ import annotations

import json
import os
import shutil
import subprocess
from pathlib import Path


def candidate_paths() -> list[Path]:
    local = Path(os.environ.get("LOCALAPPDATA", ""))
    candidates: list[Path] = []
    for command in ("godot", "godot_console", "godot4"):
        resolved = shutil.which(command)
        if resolved:
            candidates.append(Path(resolved))
    packages = local / "Microsoft" / "WinGet" / "Packages"
    if packages.exists():
        candidates.extend(packages.glob("GodotEngine.GodotEngine_*/*Godot*.exe"))
    candidates.extend(
        Path(path)
        for path in (
            "C:/Godot/Godot.exe",
            "C:/Tools/Godot/Godot.exe",
            "C:/Program Files/Godot/Godot.exe",
        )
    )
    return candidates


def locate_godot(configured: str | None = None) -> Path | None:
    candidates = ([Path(configured)] if configured else []) + candidate_paths()
    for candidate in candidates:
        if candidate.is_file() and "console" not in candidate.name.lower():
            return candidate.resolve()
    return None


def godot_version(executable: Path) -> str:
    completed = subprocess.run(
        [str(executable), "--version"], capture_output=True, text=True, timeout=10, check=False
    )
    return (completed.stdout or completed.stderr).strip()


if __name__ == "__main__":
    found = locate_godot()
    print(
        json.dumps(
            {
                "path": str(found) if found else None,
                "version": godot_version(found) if found else None,
            }
        )
    )  # noqa: E501
