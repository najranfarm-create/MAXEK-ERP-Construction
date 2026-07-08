#!/usr/bin/env bash
# Inject attendance sub-tab partial into production attendance.html (idempotent).
set -euo pipefail

LIVE="${LIVE:-/var/www/maxek-erp}"
ATT_TPL="${LIVE}/templates/attendance.html"
MARKER="attendance_module_tabs"

if [[ ! -f "${ATT_TPL}" ]]; then
  echo "  SKIP inject-attendance-tabs (no attendance.html on server)"
  exit 0
fi

if grep -q "${MARKER}" "${ATT_TPL}"; then
  echo "  OK attendance.html already has sub-tab header"
  exit 0
fi

python3 - "${ATT_TPL}" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
include = "{% include 'partials/attendance_module_tabs.html' %}\n"
marker = "attendance_module_tabs"

if marker in text:
    print("  OK attendance.html already patched")
    raise SystemExit(0)

needle = "{% block content %}"
if needle not in text:
    print("  WARN attendance.html has no {% block content %} — manual include required")
    raise SystemExit(0)

text = text.replace(needle, needle + "\n" + include, 1)
path.write_text(text, encoding="utf-8")
print("  OK injected attendance sub-tab header into attendance.html")
PY
