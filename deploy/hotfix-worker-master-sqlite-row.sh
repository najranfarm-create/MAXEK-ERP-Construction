#!/usr/bin/env bash
# Hotfix: worker_master_service.py — sqlite3.Row has no .get()
# Run on VPS as root from any directory:
#   curl -fsSL https://raw.githubusercontent.com/najranfarm-create/MAXEK-ERP-Construction/cursor/revised-estimate-row-hotfix-f9eb/deploy/hotfix-worker-master-sqlite-row.sh | sudo bash
set -euo pipefail

FILE="${LIVE:-/var/www/maxek-erp}/worker_master_service.py"
TS="$(date +%Y%m%d%H%M%S)"

echo "==> MAXEK ERP — worker_master_service sqlite3.Row hotfix"
echo "    Target: ${FILE}"

if [[ ! -f "${FILE}" ]]; then
  echo "ERROR: ${FILE} not found"
  exit 1
fi

cp -a "${FILE}" "${FILE}.bak-rowfix-${TS}"
echo "==> Backup: worker_master_service.py.bak-rowfix-${TS}"

python3 <<'PY'
import re
from pathlib import Path

path = Path("/var/www/maxek-erp/worker_master_service.py")
text = path.read_text()
original = text

helper = '''

def _row_dict(row):
    """sqlite3.Row -> dict (Row supports [] but not .get())."""
    if row is None:
        return {}
    if isinstance(row, dict):
        return row
    if hasattr(row, "keys"):
        return dict(row)
    return {}
'''

if "def _row_dict(row):" not in text:
    marker = 'from __future__ import annotations\n'
    if marker in text:
        text = text.replace(marker, marker + helper + "\n", 1)
    else:
        text = helper + "\n" + text

# Pattern: (row[2] if isinstance(row, tuple) else row.get("joining_date"))
text = re.sub(
    r"isinstance\((\w+), tuple\) else \1\.get\(",
    r"isinstance(\1, tuple) else dict(\1).get(",
    text,
)

# Bare row.get("col") in migration loops — only safe rewrites for common row vars
for var in ("row", "wrow", "grow", "arow", "rec", "record"):
    text = re.sub(
        rf"(?<![\w.]){var}\.get\(",
        rf"dict({var}).get(",
        text,
    )

# Undo double dict(dict(row)) if script re-run
text = text.replace("dict(dict(", "dict(")

if text == original:
    print("WARN: no patterns changed — file may already be patched")
else:
    path.write_text(text)
    print("Patched worker_master_service.py")
PY

systemctl restart maxek-erp.service
sleep 3

STATUS="$(systemctl is-active maxek-erp.service || true)"
echo "==> Service: ${STATUS}"

if [[ "${STATUS}" != "active" ]]; then
  journalctl -u maxek-erp.service -n 25 --no-pager
  exit 1
fi

HTTP="$(curl -s -o /dev/null -w '%{http_code}' 'http://127.0.0.1:8000/login' || echo 000)"
echo "==> HTTP /login => ${HTTP}"

ERRS="$(journalctl -u maxek-erp.service -n 20 --no-pager | grep -c "sqlite3.Row" || true)"
if [[ "${ERRS}" -gt 0 ]]; then
  echo "==> WARNING: sqlite3.Row errors still in recent logs — paste journalctl output"
  journalctl -u maxek-erp.service -n 20 --no-pager
  exit 1
fi

echo "==> Hotfix complete. Hard-refresh browser and sign in."
