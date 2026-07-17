from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main() -> int:
    executable = ROOT / "Build" / "WebProtocol.exe"
    if not executable.is_file():
        print(json.dumps({"ok": False, "error": f"missing {executable}"}))
        return 1
    size = executable.stat().st_size
    payload = executable.read_bytes()
    digest = hashlib.sha256(payload).hexdigest().upper()
    metadata_path = ROOT / "artifacts" / "build_reports" / "latest_build.json"
    metadata = (
        json.loads(metadata_path.read_text(encoding="utf-8"))
        if metadata_path.is_file()
        else {}
    )
    checks = {
        "portable_executable": payload[:2] == b"MZ",
        "minimum_size": size > 50_000_000,
        "metadata_size_matches": int(metadata.get("size_bytes", -1)) == size,
        "metadata_hash_matches": str(metadata.get("sha256", "")).upper() == digest,
        "import_passed": metadata.get("import") == "passed",
        "gdscript_tests_passed": metadata.get("gdscript_tests") == "passed",
        "python_tests_passed": metadata.get("python_tests") == "passed",
        "python_lint_passed": metadata.get("python_lint") == "passed",
        "export_passed": metadata.get("export") == "passed",
    }
    result = {
        "ok": all(checks.values()),
        "path": str(executable),
        "size_bytes": size,
        "sha256": digest,
        "checks": checks,
    }
    print(json.dumps(result, indent=2))
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
