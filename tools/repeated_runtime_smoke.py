from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path
from time import monotonic

ROOT = Path(__file__).resolve().parents[1]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sessions", type=int, default=3)
    args = parser.parse_args()
    sessions = max(1, min(args.sessions, 20))
    results: list[dict[str, object]] = []
    for index in range(sessions):
        started = monotonic()
        completed = subprocess.run(
            [
                sys.executable,
                str(ROOT / "main.py"),
                "--simulate-vision",
                "--capture-demo",
                "--windowed",
            ],
            cwd=ROOT,
            check=False,
        )
        timing_path = ROOT / "artifacts" / "test_reports" / "capture_timing.json"
        timing = json.loads(timing_path.read_text(encoding="utf-8"))
        results.append(
            {
                "session": index + 1,
                "return_code": completed.returncode,
                "elapsed_real_seconds": round(monotonic() - started, 3),
                "returned_to_attract": timing.get("returned_to_attract") is True,
                "effective_session_seconds": timing.get("effective_session_seconds"),
                "screenshot_count": timing.get("screenshot_count"),
                "average_fps": timing.get("average_fps"),
                "minimum_fps": timing.get("minimum_fps"),
            }
        )
    passed = all(
        result["return_code"] == 0
        and result["returned_to_attract"]
        and result["effective_session_seconds"] == 90.0
        and result["screenshot_count"] == 13
        for result in results
    )
    report = {"passed": passed, "sessions": results}
    output = ROOT / "artifacts" / "test_reports" / "repeated_runtime_smoke.json"
    output.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
