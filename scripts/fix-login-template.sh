#!/usr/bin/env bash
# Fix login.html line 18 — use direct /static/ path (nginx serves static; avoids Jinja quote bug)
set -euo pipefail

LOGIN="/var/www/maxek-erp/templates/login.html"
SERVICE="maxek-erp.service"

echo "=== Fix login.html (direct static path) ==="

[ -f "$LOGIN" ] || { echo "ERROR: $LOGIN not found"; exit 1; }

cp -a "$LOGIN" "${LOGIN}.bak.$(date +%Y%m%d%H%M%S)"

python3 <<'PY'
from pathlib import Path
import re

path = Path("/var/www/maxek-erp/templates/login.html")
text = path.read_text()

# Replace any maxek-logo url_for line with plain static path
text = re.sub(
    r"^\s*src=.*maxek-logo\.png.*$",
    '              src="/static/images/maxek-logo.png"',
    text,
    flags=re.MULTILINE,
)

path.write_text(text)
print("Patched logo src → /static/images/maxek-logo.png")

# Validate template compiles
from jinja2 import Environment, FileSystemLoader
env = Environment(loader=FileSystemLoader("/var/www/maxek-erp/templates"))
try:
    env.get_template("login.html")
    print("Jinja2 compile: OK")
except Exception as e:
    print(f"Jinja2 compile: FAILED — {e}")
    raise SystemExit(1)
PY

echo ""
echo "Line 15-22:"
sed -n '15,22p' "$LOGIN"
echo ""

systemctl restart "$SERVICE"
sleep 2

code=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8000/login)
echo "GET /login → HTTP $code"

if [ "$code" = "200" ] || [ "$code" = "302" ]; then
  echo "SUCCESS"
else
  echo "FAILED — latest log:"
  journalctl -u "$SERVICE" -n 15 --no-pager
  exit 1
fi
