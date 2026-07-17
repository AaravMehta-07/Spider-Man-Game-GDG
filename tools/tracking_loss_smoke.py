from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path
from time import monotonic, sleep

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from vision.health_server import probe_health  # noqa: E402
from web_protocol.config import ProjectConfig  # noqa: E402


def terminate(process: subprocess.Popen[bytes] | None) -> None:
    if process is None or process.poll() is not None:
        return
    process.terminate()
    try:
        process.wait(timeout=3.0)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait(timeout=1.0)


def main() -> int:
    config = ProjectConfig.load(ROOT)
    game_config = config.section("game")
    executable = ROOT / str(game_config["executable"])
    report_dir = ROOT / "artifacts" / "test_reports"
    report_dir.mkdir(parents=True, exist_ok=True)
    runtime_log = report_dir / "tracking_loss_runtime.log"
    runtime_log.unlink(missing_ok=True)
    vision: subprocess.Popen[bytes] | None = None
    game: subprocess.Popen[bytes] | None = None
    started = monotonic()
    try:
        vision = subprocess.Popen([sys.executable, "-m", "vision.main", "--simulate"], cwd=ROOT)
        deadline = monotonic() + 5.0
        while monotonic() < deadline:
            health = probe_health(str(game_config["udp_host"]), int(game_config["health_port"]))
            if health and health.get("ready") and int(health.get("packets_sent", 0)) > 0:
                break
            sleep(0.05)
        else:
            raise RuntimeError("simulated vision did not become ready")

        game = subprocess.Popen(
            [
                str(executable),
                "--log-file",
                str(runtime_log),
                "--",
                "--capture-demo",
                "--windowed",
                "--vision-managed",
            ],
            cwd=ROOT,
        )
        sleep(3.0)
        terminate(vision)
        vision = None
        game_exit = game.wait(timeout=30.0)
        game = None
        log_text = runtime_log.read_text(encoding="utf-8", errors="replace")
        checks = {
            "vision_link_lost_observed": "VISION LINK LOST" in log_text,
            "results_reached": "FINISHER -> RESULTS" in log_text,
            "timeline_reset_reached": "RESETTING -> ATTRACT" in log_text,
            "game_exit_zero": game_exit == 0,
        }
        report = {
            "checks": checks,
            "passed": all(checks.values()),
            "elapsed_real_seconds": round(monotonic() - started, 3),
            "runtime_log": str(runtime_log),
        }
        (report_dir / "tracking_loss_smoke.json").write_text(
            json.dumps(report, indent=2), encoding="utf-8"
        )
        print(json.dumps(report, indent=2))
        return 0 if report["passed"] else 1
    finally:
        terminate(game)
        terminate(vision)


if __name__ == "__main__":
    raise SystemExit(main())
