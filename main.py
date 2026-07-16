from __future__ import annotations

import argparse
import json
import os
import signal
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from time import monotonic, sleep

ROOT = Path(__file__).resolve().parent
VENV_PYTHON = ROOT / ".venv" / "Scripts" / "python.exe"

if VENV_PYTHON.is_file() and Path(sys.executable).resolve() != VENV_PYTHON.resolve():
    environment = os.environ.copy()
    environment["WEB_PROTOCOL_REEXEC"] = "1"
    raise SystemExit(
        subprocess.call(
            [str(VENV_PYTHON), str(Path(__file__).resolve()), *sys.argv[1:]], env=environment
        )
    )

from tools.locate_godot import godot_version, locate_godot  # noqa: E402
from vision.health_server import probe_health  # noqa: E402
from web_protocol.config import ConfigurationError, ProjectConfig  # noqa: E402
from web_protocol.logging_setup import configure_logging  # noqa: E402


@dataclass(slots=True)
class LaunchOptions:
    debug: bool
    windowed: bool
    keyboard_only: bool
    simulate_vision: bool
    capture_demo: bool
    boss_test: bool
    camera: int | None
    skip_calibration: bool
    smoke_seconds: float | None


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description="Launch WEB//PROTOCOL: SPIDER-SENSE")
    result.add_argument("--setup-check", action="store_true")
    result.add_argument("--build", action="store_true")
    result.add_argument("--debug", action="store_true")
    result.add_argument("--windowed", action="store_true")
    result.add_argument("--keyboard-only", action="store_true")
    result.add_argument("--simulate-vision", action="store_true")
    result.add_argument("--capture-demo", action="store_true")
    result.add_argument("--boss-test", action="store_true")
    result.add_argument("--camera", type=int)
    result.add_argument("--skip-calibration", action="store_true")
    result.add_argument("--smoke-seconds", type=float)
    return result


def setup_report(config: ProjectConfig) -> dict[str, object]:
    local_game = config.section("game")
    configured = local_game.get("godot_executable")
    executable = locate_godot(str(configured)) if configured else locate_godot()
    templates = Path(os.environ.get("APPDATA", "")) / "Godot" / "export_templates" / "4.7.1.stable"
    exported = ROOT / str(local_game["executable"])
    return {
        "python": sys.version.split()[0],
        "python_ok": sys.version_info[:2] == (3, 11),
        "godot": str(executable) if executable else None,
        "godot_version": godot_version(executable) if executable else None,
        "export_templates": str(templates),
        "export_templates_ok": templates.is_dir(),
        "game_executable": str(exported),
        "game_executable_ok": exported.is_file(),
    }


def run_build(logger: object) -> int:
    command = [
        "powershell",
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        str(ROOT / "build.ps1"),
    ]
    return subprocess.run(command, cwd=ROOT, check=False).returncode


def wait_for_vision(
    config: ProjectConfig, process: subprocess.Popen[bytes], timeout: float = 8.0
) -> bool:  # noqa: E501
    game = config.section("game")
    deadline = monotonic() + timeout
    while monotonic() < deadline and process.poll() is None:
        health = probe_health(str(game["udp_host"]), int(game["health_port"]))
        if health and health.get("ready"):
            return True
        sleep(0.1)
    return False


def game_arguments(options: LaunchOptions) -> list[str]:
    arguments: list[str] = []
    for enabled, flag in (
        (options.debug, "--debug-mode"),
        (options.windowed, "--windowed"),
        (options.keyboard_only, "--keyboard-only"),
        (options.capture_demo, "--capture-demo"),
        (options.boss_test, "--boss-test"),
        (options.skip_calibration, "--skip-calibration"),
    ):
        if enabled:
            arguments.append(flag)
    return arguments


def terminate(process: subprocess.Popen[bytes] | None, timeout: float = 3.0) -> None:
    if process is None or process.poll() is not None:
        return
    process.terminate()
    try:
        process.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait(timeout=1.0)


def set_event_awake(active: bool) -> None:
    if os.name != "nt":
        return
    import ctypes

    continuous = 0x80000000
    display_required = 0x00000002
    system_required = 0x00000001
    flags = continuous | display_required | system_required if active else continuous
    ctypes.windll.kernel32.SetThreadExecutionState(flags)


def launch(config: ProjectConfig, options: LaunchOptions, logger: object) -> int:
    game_executable = ROOT / str(config.section("game")["executable"])
    if not game_executable.exists():
        build_code = run_build(logger)
        if build_code != 0 or not game_executable.exists():
            logger.error("game export missing and automatic build failed with code %s", build_code)
            return 12
    vision_command = [sys.executable, "-m", "vision.main"]
    if options.simulate_vision or options.keyboard_only:
        vision_command.append("--simulate")
    if options.capture_demo:
        vision_command.extend(("--time-scale", "8.0"))
    if options.camera is not None:
        vision_command.extend(("--camera", str(options.camera)))
    if options.debug:
        vision_command.append("--debug")
    vision: subprocess.Popen[bytes] | None = None
    game: subprocess.Popen[bytes] | None = None
    try:
        vision = subprocess.Popen(vision_command, cwd=ROOT)
        if not wait_for_vision(config, vision):
            logger.error("vision service did not become ready")
            return 21
        game = subprocess.Popen([str(game_executable), "--", *game_arguments(options)], cwd=ROOT)
        vision_restarted = False
        smoke_started = monotonic()
        while game.poll() is None:
            if options.smoke_seconds and monotonic() - smoke_started >= options.smoke_seconds:
                health = probe_health(
                    str(config.section("game")["udp_host"]),
                    int(config.section("game")["health_port"]),
                )
                report_name = (
                    "simulated_supervisor_smoke.json"
                    if options.simulate_vision
                    else "live_camera_smoke.json"
                )
                report_path = ROOT / "artifacts" / "test_reports" / report_name
                report_path.parent.mkdir(parents=True, exist_ok=True)
                report_path.write_text(json.dumps(health or {}, indent=2), encoding="utf-8")
                return 0 if health and int(health.get("packets_sent", 0)) > 0 else 22
            if vision.poll() is not None and not vision_restarted:
                logger.warning("vision exited; restarting once")
                vision = subprocess.Popen(vision_command, cwd=ROOT)
                vision_restarted = True
                if not wait_for_vision(config, vision):
                    logger.error("vision restart did not recover")
            sleep(0.25)
        return int(game.returncode or 0)
    finally:
        terminate(game)
        terminate(vision)


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(argv)
    logger = configure_logging(ROOT, args.debug)
    try:
        config = ProjectConfig.load(ROOT)
    except ConfigurationError as error:
        logger.error("configuration error: %s", error)
        return 10
    report = setup_report(config)
    if args.setup_check:
        print(json.dumps(report, indent=2))
        return 0 if report["python_ok"] and report["godot"] else 11
    if args.build:
        return run_build(logger)
    options = LaunchOptions(
        debug=args.debug,
        windowed=args.windowed,
        keyboard_only=args.keyboard_only,
        simulate_vision=args.simulate_vision,
        capture_demo=args.capture_demo,
        boss_test=args.boss_test,
        camera=args.camera,
        skip_calibration=args.skip_calibration,
        smoke_seconds=args.smoke_seconds,
    )
    set_event_awake(True)
    try:
        return launch(config, options, logger)
    finally:
        set_event_awake(False)


if __name__ == "__main__":
    signal.signal(signal.SIGINT, lambda *_: sys.exit(130))
    raise SystemExit(main())
