#!/usr/bin/env bash
# One-command fix for /login HTTP 500 — Jinja2 quote error in login.html line 18
# Safe: backs up template, patches one line, restarts service, verifies.
set -euo pipefail

LOGIN="/var/www/maxek-erp/templates/login.html"
SERVICE="maxek-erp.service"

echo "=== MAXEK login.html direct patch ==="

if [ ! -f "$LOGIN" ]; then
  echo "ERROR: $LOGIN not found. Is this the correct server?"
  exit 1
fi

BACKUP="${LOGIN}.bak.$(date +%Y%m%d%H%M%S)"
cp -a "$LOGIN" "$BACKUP"
echo "Backup: $BACKUP"
echo "Line 18 before:"
sed -n '15,22p' "$LOGIN"
echo ""

python3 <<'PY'
from pathlib import Path

path = Path("/var/www/maxek-erp/templates/login.html")
lines = path.read_text().splitlines(keepends=True)
fixed = []
changed = False

GOOD = 'src="{{ url_for(\'static\', filename=\'images/maxek-logo.png\') }}"\n'

for i, line in enumerate(lines):
    if "maxek-logo.png" in line and "url_for" in line:
        # Preserve leading whitespace (indentation)
        indent = line[: len(line) - len(line.lstrip())]
        new_line = indent + GOOD.lstrip()
        if line != new_line:
            changed = True
            print(f"Fixed line {i + 1}")
        fixed.append(new_line)
    else:
        fixed.append(line)

if not changed:
    # Fallback: fix line 18 directly if it contains url_for + static
    for i, line in enumerate(lines):
        if i == 17 and "url_for" in line and "static" in line:
            indent = line[: len(line) - len(line.lstrip())]
            lines[i] = indent + GOOD.lstrip()
            changed = True
            print(f"Fixed line 18 (fallback)")
            break
    fixed = lines

path.write_text("".join(fixed))
print("Done.")
PY

echo ""
echo "Line 18 after:"
sed -n '15,22p' "$LOGIN"
echo ""

echo "Restarting $SERVICE ..."
systemctl restart "$SERVICE"
sleep 2

if ! systemctl is-active --quiet "$SERVICE"; then
  echo "ERROR: service failed to start. Restoring backup..."
  cp -a "$BACKUP" "$LOGIN"
  systemctl restart "$SERVICE"
  exit 1
fi

LOCAL=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8000/login || echo "000")
PUBLIC=$(curl -s -o /dev/null -w "%{http_code}" https://erp.maxekindia.com/login 2>/dev/null || echo "000")

echo ""
echo "Results:"
echo "  http://127.0.0.1:8000/login          → HTTP $LOCAL"
echo "  https://erp.maxekindia.com/login     → HTTP $PUBLIC"

if [ "$LOCAL" = "200" ] || [ "$LOCAL" = "302" ]; then
  echo ""
  echo "SUCCESS — login page is working."
  exit 0
else
  echo ""
  echo "Still failing. Restoring backup and showing logs:"
  cp -a "$BACKUP" "$LOGIN"
  systemctl restart "$SERVICE"
  journalctl -u "$SERVICE" -n 20 --no-pager
  exit 1
fi
