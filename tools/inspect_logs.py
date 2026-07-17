from __future__ import annotations

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read_log(path: Path) -> str:
    payload = path.read_bytes()
    encoding = "utf-16" if payload.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-8"
    return payload.decode(encoding, errors="replace")


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(errors="replace")
    parser = argparse.ArgumentParser()
    parser.add_argument("--lines", type=int, default=80)
    args = parser.parse_args()
    for path in sorted((ROOT / "logs").glob("*.log")):
        lines = read_log(path).splitlines()
        print(f"\n== {path.name} ==")
        print("\n".join(lines[-args.lines :]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
