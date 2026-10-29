"""Ganti `catch (_) {}` kosong menjadi laporan error yang bisa dilacak.

Dijalankan sekali dari root project: python tool/fix_silent_catches.py
"""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIB = ROOT / "lib"

IMPORT_LINE = "import 'package:tenmu/core/error_reporter.dart';"

PATTERN = re.compile(r"catch \(_\) \{\}")


def relative_import(path: Path) -> str:
    """Buat import relatif dari file ke lib/core/error_reporter.dart."""
    depth = len(path.relative_to(LIB).parts) - 1
    return f"import '{'../' * depth}core/error_reporter.dart';"


def main() -> None:
    total = 0
    for path in sorted(LIB.rglob("*.dart")):
        text = path.read_text(encoding="utf-8")
        if "catch (_) {}" not in text:
            continue

        # Ganti dari belakang supaya nomor baris tidak bergeser.
        matches = list(PATTERN.finditer(text))
        for match in reversed(matches):
            line_no = text[: match.start()].count("\n") + 1
            context = f"{path.stem}:{line_no}"
            replacement = (
                "catch (e, s) {\n"
                f"      ErrorReporter.reportCaught(e, s, '{context}');\n"
                "    }"
            )
            text = text[: match.start()] + replacement + text[match.end():]

        # Pastikan import tersedia.
        if "error_reporter.dart" not in text:
            lines = text.splitlines(keepends=True)
            last_import = max(
                (i for i, line in enumerate(lines) if line.startswith("import ")),
                default=-1,
            )
            if last_import >= 0:
                lines.insert(last_import + 1, relative_import(path) + "\n")
                text = "".join(lines)
            else:
                text = relative_import(path) + "\n" + text

        path.write_text(text, encoding="utf-8")
        total += len(matches)
        print(f"{path.relative_to(ROOT)}: {len(matches)} catch diganti")

    print(f"total: {total}")


if __name__ == "__main__":
    main()
