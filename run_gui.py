from __future__ import annotations

import sys


if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8")

from jarvis.gui import main  # noqa: E402


if __name__ == "__main__":
    raise SystemExit(main())
