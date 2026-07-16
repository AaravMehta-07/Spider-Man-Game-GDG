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
    digest = hashlib.sha256(executable.read_bytes()).hexdigest()
    result = {
        "ok": size > 50_000_000,
        "path": str(executable),
        "size_bytes": size,
        "sha256": digest,
    }
    print(json.dumps(result, indent=2))
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
