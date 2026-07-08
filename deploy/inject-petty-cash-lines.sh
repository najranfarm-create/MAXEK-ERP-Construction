#!/usr/bin/env bash
# Inject petty cash multi-line purpose/amount partial into production petty_cash.html.
set -euo pipefail

LIVE="${LIVE:-/var/www/maxek-erp}"
PC_TPL="${LIVE}/templates/petty_cash.html"
MARKER="petty_cash_line_items"

if [[ ! -f "${PC_TPL}" ]]; then
  echo "  SKIP inject-petty-cash-lines (no petty_cash.html on server)"
  exit 0
fi

if grep -q "${MARKER}" "${PC_TPL}"; then
  echo "  OK petty_cash.html already has purpose/amount line grid"
  exit 0
fi

python3 - "${PC_TPL}" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
include = "{% include 'partials/petty_cash_line_items.html' %}\n"
marker = "petty_cash_line_items"

if marker in text:
    print("  OK petty_cash.html already patched")
    raise SystemExit(0)

anchors = [
    'name="description"',
    'name="purpose"',
    'name="required_amount"',
    'form_action" value="save_draft"',
    'form_action" value="submit_request"',
    "<!-- priority -->",
    'name="priority"',
    'name="remarks"',
]

inserted = False
for anchor in anchors:
    pos = text.find(anchor)
    if pos == -1:
        continue
    line_start = text.rfind("\n", 0, pos)
    if line_start == -1:
        line_start = 0
    else:
        line_start += 1
    text = text[:line_start] + include + text[line_start:]
    inserted = True
    break

if not inserted:
    form_match = re.search(r"<form[^>]*method=[\"']post[\"'][^>]*>", text, re.I)
    if form_match:
        end = form_match.end()
        text = text[:end] + "\n" + include + text[end:]
        inserted = True

if not inserted:
    print("  WARN petty_cash.html — could not find injection point")
    raise SystemExit(0)

path.write_text(text, encoding="utf-8")
print("  OK injected petty cash purpose/amount line grid into petty_cash.html")
PY
