#!/usr/bin/env bash
# Fix AttributeError: sqlite3.Row has no attribute 'get' in worker_master_service.py line ~415
set -euo pipefail

FILE="/var/www/maxek-erp/worker_master_service.py"
cp -a "$FILE" "${FILE}.bak.rowfix.$(date +%Y%m%d%H%M%S)"

python3 <<'PY'
from pathlib import Path
path = Path("/var/www/maxek-erp/worker_master_service.py")
text = path.read_text()

old = 'start = (row[2] if isinstance(row, tuple) else row.get("joining_date")) or ""'
new = 'start = (row[2] if isinstance(row, tuple) else row["joining_date"]) or ""'

if old not in text:
    # try alternate patterns
    import re
    if 'row.get("joining_date")' in text:
        text = text.replace('row.get("joining_date")', 'row["joining_date"]')
        path.write_text(text)
        print("Fixed row.get(joining_date) -> row[joining_date]")
    else:
        print("Pattern not found — show line 410-420:")
        for i, line in enumerate(text.splitlines(), 1):
            if 410 <= i <= 420:
                print(f"{i}|{line}")
        raise SystemExit(1)
else:
    path.write_text(text.replace(old, new))
    print("Fixed line 415 pattern")
PY

systemctl restart maxek-erp.service
sleep 3
curl -s -o /dev/null -w "Login → HTTP %{http_code}\n" http://127.0.0.1:8000/login
echo "Also fix this in GitHub repo and git pull on VPS"
