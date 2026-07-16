from __future__ import annotations

import json
import subprocess
from pathlib import Path
from time import monotonic, sleep

import psutil

ROOT = Path(__file__).resolve().parents[1]


def _vision_children(process: psutil.Process) -> list[psutil.Process]:
    result: list[psutil.Process] = []
    for child in process.children(recursive=True):
        try:
            command = " ".join(child.cmdline())
        except (psutil.AccessDenied, psutil.NoSuchProcess):
            continue
        if "vision.main" in command:
            result.append(child)
    return result

def _game_is_running(process: psutil.Process) -> bool:
    for child in process.children(recursive=True):
        try:
            if child.name().lower() == "webprotocol.exe":
                return True
        except (psutil.AccessDenied, psutil.NoSuchProcess):
            continue
    return False

def main() -> int:
    command = [
        str(ROOT / ".venv" / "Scripts" / "python.exe"),
        str(ROOT / "main.py"),
        "--simulate-vision",
        "--windowed",
        "--smoke-seconds",
        "12",
    ]
    launcher = subprocess.Popen(command, cwd=ROOT)
    parent = psutil.Process(launcher.pid)
    killed_pid: int | None = None
    replacement_pid: int | None = None
    started = monotonic()
    try:
        deadline = monotonic() + 12.0
        while monotonic() < deadline and not _game_is_running(parent):
            sleep(0.1)
        while monotonic() < deadline and killed_pid is None:
            children = _vision_children(parent)
            if children:
                killed_pid = children[0].pid
                children[0].terminate()
                children[0].wait(timeout=3.0)
                break
            sleep(0.1)
        deadline = monotonic() + 8.0
        while monotonic() < deadline and replacement_pid is None:
            for child in _vision_children(parent):
                if child.pid != killed_pid:
                    replacement_pid = child.pid
                    break
            sleep(0.1)
        return_code = launcher.wait(timeout=25.0)
        report = {
            "launcher_return_code": return_code,
            "killed_vision_pid": killed_pid,
            "replacement_vision_pid": replacement_pid,
            "restart_detected": replacement_pid is not None,
            "elapsed_seconds": round(monotonic() - started, 2),
        }
        output = ROOT / "artifacts" / "test_reports" / "vision_restart_smoke.json"
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(report, indent=2), encoding="utf-8")
        print(json.dumps(report))
        return 0 if return_code == 0 and replacement_pid is not None else 1
    finally:
        if launcher.poll() is None:
            launcher.terminate()
            launcher.wait(timeout=5.0)


if __name__ == "__main__":
    raise SystemExit(main())