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
from uuid import uuid4

ROOT = Path(__file__).resolve().parent
VENV_PYTHON = ROOT / ".venv" / "Scripts" / "python.exe"

if (
    __name__ == "__main__"
    and VENV_PYTHON.is_file()
    and Path(sys.executable).resolve() != VENV_PYTHON.resolve()
):
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
    failure_demo: bool
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
    result.add_argument("--failure-demo", action="store_true")
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
    pose_model = ROOT / str(config.section("models")["pose"])
    hand_model = ROOT / str(config.section("models")["hands"])
    detected_version = godot_version(executable) if executable else None
    return {
        "python": sys.version.split()[0],
        "python_ok": sys.version_info[:2] == (3, 11),
        "godot": str(executable) if executable else None,
        "godot_version": detected_version,
        "godot_version_ok": bool(detected_version and detected_version.startswith("4.7")),
        "export_templates": str(templates),
        "export_templates_ok": templates.is_dir(),
        "game_executable": str(exported),
        "game_executable_ok": exported.is_file(),
        "pose_model_ok": pose_model.is_file() and pose_model.stat().st_size > 1_000_000,
        "hand_model_ok": hand_model.is_file() and hand_model.stat().st_size > 1_000_000,
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
    config: ProjectConfig,
    process: subprocess.Popen[bytes],
    timeout: float = 20.0,
    expected_instance_id: str | None = None,
) -> bool:  # noqa: E501
    game = config.section("game")
    deadline = monotonic() + timeout
    while monotonic() < deadline and process.poll() is None:
        health = probe_health(str(game["udp_host"]), int(game["health_port"]))
        if (
            health
            and (
                expected_instance_id is None
                or health.get("instance_id") == expected_instance_id
            )
            and health.get("ready")
            and int(health.get("packets_sent", 0)) > 0
            and int(health.get("inference_frames", 0)) > 0
            and 0.0 <= float(health.get("packet_age_ms", -1.0)) < 1000.0
        ):
            return True
        sleep(0.1)
    return False


def game_arguments(options: LaunchOptions, config: ProjectConfig) -> list[str]:
    arguments: list[str] = []
    for enabled, flag in (
        (options.debug, "--debug-mode"),
        (options.windowed, "--windowed"),
        (options.keyboard_only, "--keyboard-only"),
        (options.capture_demo, "--capture-demo"),
        (options.failure_demo, "--failure-demo"),
        (options.boss_test, "--boss-test"),
        (options.skip_calibration, "--skip-calibration"),
        (True, "--vision-managed"),
    ):
        if enabled:
            arguments.append(flag)
    game = config.section("game")
    arguments.extend(
        (
            f"--udp-port={int(game['udp_port'])}",
            f"--health-port={int(game['health_port'])}",
        )
    )
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


def vision_command(
    options: LaunchOptions, instance_id: str, force_simulate: bool = False
) -> list[str]:
    command = [
        sys.executable,
        "-m",
        "vision.main",
        "--instance-id",
        instance_id,
    ]
    if force_simulate or options.simulate_vision or options.keyboard_only:
        command.append("--simulate")
    if options.capture_demo:
        command.extend(("--time-scale", "8.0"))
    if options.camera is not None and not force_simulate:
        command.extend(("--camera", str(options.camera)))
    if options.debug:
        command.append("--debug")
    return command


def launch(config: ProjectConfig, options: LaunchOptions, logger: object) -> int:
    game_executable = ROOT / str(config.section("game")["executable"])
    if not game_executable.exists():
        build_code = run_build(logger)
        if build_code != 0 or not game_executable.exists():
            logger.error("game export missing and automatic build failed with code %s", build_code)
            return 12
    instance_id = uuid4().hex
    current_vision_command = vision_command(options, instance_id)
    vision: subprocess.Popen[bytes] | None = None
    game: subprocess.Popen[bytes] | None = None
    try:
        vision = subprocess.Popen(current_vision_command, cwd=ROOT)
        if not wait_for_vision(config, vision, expected_instance_id=instance_id):
            health = probe_health(
                str(config.section("game")["udp_host"]),
                int(config.section("game")["health_port"]),
            )
            if health and health.get("instance_id") != instance_id:
                detail = "vision health port is already owned by another process"
            else:
                detail = str((health or {}).get("last_error", "camera service unavailable"))
            logger.error("vision service did not become ready: %s", detail)
            same_instance = not health or health.get("instance_id") == instance_id
            if not options.simulate_vision and not options.keyboard_only and same_instance:
                terminate(vision)
                options.keyboard_only = True
                instance_id = uuid4().hex
                current_vision_command = vision_command(options, instance_id, force_simulate=True)
                vision = subprocess.Popen(current_vision_command, cwd=ROOT)
                if not wait_for_vision(config, vision, expected_instance_id=instance_id):
                    logger.error("keyboard fallback service did not become ready")
                    return 21
                print(
                    "\nCAMERA STARTUP FAILED - KEYBOARD MODE ACTIVE\n"
                    f"{detail}\n"
                    "Close other camera apps and check Windows camera privacy settings "
                    "before the next launch.\n",
                    file=sys.stderr,
                )
            else:
                print(f"\nVISION STARTUP FAILED\n{detail}\n", file=sys.stderr)
                return 21
        runtime_log = ROOT / "logs" / "godot_runtime.log"
        game = subprocess.Popen(
            [
                str(game_executable),
                "--log-file",
                str(runtime_log),
                "--",
                *game_arguments(options, config),
            ],
            cwd=ROOT,
        )
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
                    if options.simulate_vision or options.keyboard_only
                    else "live_camera_smoke.json"
                )
                report_path = ROOT / "artifacts" / "test_reports" / report_name
                report_path.parent.mkdir(parents=True, exist_ok=True)
                report_path.write_text(json.dumps(health or {}, indent=2), encoding="utf-8")
                healthy = bool(
                    health
                    and health.get("instance_id") == instance_id
                    and health.get("ready")
                    and 0.0 <= float(health.get("packet_age_ms", -1.0)) < 1000.0
                    and int(health.get("packets_sent", 0)) > 0
                )
                return 0 if healthy else 22
            if vision.poll() is not None and not vision_restarted:
                logger.warning("vision exited; restarting once")
                vision = subprocess.Popen(current_vision_command, cwd=ROOT)
                vision_restarted = True
                if not wait_for_vision(config, vision, expected_instance_id=instance_id):
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
        required_checks = (
            "python_ok",
            "godot_version_ok",
            "export_templates_ok",
            "game_executable_ok",
            "pose_model_ok",
            "hand_model_ok",
        )
        return 0 if all(bool(report[key]) for key in required_checks) else 11
    if args.build:
        return run_build(logger)
    options = LaunchOptions(
        debug=args.debug,
        windowed=args.windowed,
        keyboard_only=args.keyboard_only,
        simulate_vision=args.simulate_vision,
        capture_demo=args.capture_demo,
        failure_demo=args.failure_demo,
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
