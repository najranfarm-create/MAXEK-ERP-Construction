#!/usr/bin/env bash
# Fix ALL Jinja2 quote errors in login.html (logo url_for + onerror + other static url_for)
set -euo pipefail

LOGIN="/var/www/maxek-erp/templates/login.html"
SERVICE="maxek-erp.service"

echo "=== Fix login.html (full template quote repair) ==="

[ -f "$LOGIN" ] || { echo "ERROR: $LOGIN not found"; exit 1; }

cp -a "$LOGIN" "${LOGIN}.bak.$(date +%Y%m%d%H%M%S)"

python3 <<'PY'
import re
from pathlib import Path

from jinja2 import Environment, FileSystemLoader, TemplateSyntaxError

path = Path("/var/www/maxek-erp/templates/login.html")
text = path.read_text()

# 1) Logo: direct static path (nginx serves /static/)
text = re.sub(
    r"^\s*src=.*maxek-logo\.png.*$",
    '              src="/static/images/maxek-logo.png"',
    text,
    flags=re.MULTILINE,
)

# 2) onerror: remove single quotes around 'none' (causes Jinja "got 'none'" error)
text = re.sub(
    r'onerror="this\.style\.display=\'none\'"',
    'onerror="this.style.display=none"',
    text,
)
text = re.sub(
    r"onerror='this\.style\.display=\"none\"'",
    'onerror="this.style.display=none"',
    text,
)

# 3) Convert remaining static url_for to direct paths
def static_path(m: re.Match) -> str:
    filename = m.group(1)
    return f'"/static/{filename}"'

text = re.sub(
    r'\{\{\s*url_for\([\'"]static[\'"],\s*filename=[\'"]([^\'"]+)[\'"]\)\s*\}\}',
    static_path,
    text,
)

path.write_text(text)
print("Applied fixes: logo path, onerror, static url_for → /static/...")

# Validate — report exact line on failure
tpl_dir = "/var/www/maxek-erp/templates"
env = Environment(loader=FileSystemLoader(tpl_dir))
try:
    env.get_template("login.html")
    print("Jinja2 compile: OK")
except TemplateSyntaxError as e:
    print(f"Jinja2 compile: FAILED — {e.message}")
    if e.lineno:
        lines = path.read_text().splitlines()
        start = max(0, e.lineno - 3)
        end = min(len(lines), e.lineno + 2)
        print(f"--- Context around line {e.lineno} ---")
        for i in range(start, end):
            print(f"{i+1:4d}| {lines[i]}")
    raise SystemExit(1)
PY

echo ""
sed -n '14,25p' "$LOGIN"
echo ""

systemctl restart "$SERVICE"
sleep 2

code=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8000/login)
echo "GET /login → HTTP $code"

if [ "$code" = "200" ] || [ "$code" = "302" ]; then
  echo "SUCCESS — https://erp.maxekindia.com/login should work now"
else
  journalctl -u "$SERVICE" -n 20 --no-pager
  exit 1
fi
