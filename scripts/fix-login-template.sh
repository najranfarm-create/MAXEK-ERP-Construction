#!/usr/bin/env bash
# Fix Jinja2 TemplateSyntaxError on login.html line 18 (quote conflict in url_for)
# ONLY patches /var/www/maxek-erp/templates/login.html — backs up first.
set -euo pipefail

LOGIN_TEMPLATE="/var/www/maxek-erp/templates/login.html"

if [ ! -f "$LOGIN_TEMPLATE" ]; then
  echo "ERROR: $LOGIN_TEMPLATE not found"
  exit 1
fi

cp -a "$LOGIN_TEMPLATE" "${LOGIN_TEMPLATE}.bak.$(date +%Y%m%d%H%M%S)"
echo "Backup created."

echo "Before (line 18 area):"
grep -n "url_for" "$LOGIN_TEMPLATE" | head -5 || true

# Fix: use double quotes inside url_for when HTML attr uses double quotes
# Handles common broken patterns with nested single quotes
python3 <<'PY'
from pathlib import Path
import re

path = Path("/var/www/maxek-erp/templates/login.html")
text = path.read_text()

# Pattern 1: single-quoted attr wrapping single-quoted url_for (broken)
text = re.sub(
    r"src='(\{\{\s*)url_for\('static',\s*filename='([^']+)'\)\s*(\}\})'",
    r'src="\1url_for(\'static\', filename=\'\2\')\3"',
    text,
)

# Pattern 2: normalize logo line to known-good form
text = re.sub(
    r'src="?\{\{\s*url_for\([^)]*maxek-logo\.png[^)]*\)\s*\}\}"?',
    r'src="{{ url_for(\'static\', filename=\'images/maxek-logo.png\') }}"',
    text,
)
text = re.sub(
    r"src='?\{\{\s*url_for\([^)]*maxek-logo\.png[^)]*\)\s*\}\}'?",
    r'src="{{ url_for(\'static\', filename=\'images/maxek-logo.png\') }}"',
    text,
)

path.write_text(text)
print("Patched login.html")
PY

echo ""
echo "After:"
grep -n "maxek-logo" "$LOGIN_TEMPLATE" || true

echo ""
echo "Restarting gunicorn..."
systemctl restart maxek-erp.service
sleep 2

code=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8000/login)
echo "GET /login → HTTP $code"
if [ "$code" = "200" ] || [ "$code" = "302" ]; then
  echo "SUCCESS"
else
  echo "Still failing — run: journalctl -u maxek-erp.service -n 30 --no-pager"
fi
