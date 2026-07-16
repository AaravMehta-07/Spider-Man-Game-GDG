from __future__ import annotations

import argparse
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--lines", type=int, default=80)
    args = parser.parse_args()
    for path in sorted((ROOT / "logs").glob("*.log")):
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
        print(f"\n== {path.name} ==")
        print("\n".join(lines[-args.lines :]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
