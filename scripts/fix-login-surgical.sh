#!/usr/bin/env bash
# Fix login.html line 161 app_version '1.0.0' + all prior Jinja issues — validate before save
set -euo pipefail

LOGIN="/var/www/maxek-erp/templates/login.html"
cp -a "$LOGIN" "${LOGIN}.bak.surgical2.$(date +%Y%m%d%H%M%S)"

python3 <<'PY'
import re
from pathlib import Path
from jinja2 import Environment, FileSystemLoader, TemplateSyntaxError

path = Path("/var/www/maxek-erp/templates/login.html")
text = path.read_text()

# Logo
text = re.sub(
    r"^\s*src=.*maxek-logo\.png.*$",
    '              src="/static/images/maxek-logo.png"',
    text,
    flags=re.MULTILINE,
)

# onerror
text = re.sub(r'\s*onerror="[^"]*"', "", text)

# static url_for → /static/...
text = re.sub(
    r"\{\{\s*url_for\(\s*['\"]static['\"]\s*,\s*filename\s*=\s*['\"]([^'\"]+)['\"]\s*\)\s*\}\}",
    r"/static/\1",
    text,
)

# url_for('x') → url_for("x")
text = re.sub(r"url_for\('([^']+)'\)", r'url_for("\1")', text)

# FIX line 161: '1.0.0' parsed as float — use double quotes
text = re.sub(
    r"\{\{\s*app_version\s+or\s+'1\.0\.0'\s*\}\}",
    '{{ app_version or "1.0.0" }}',
    text,
)
text = re.sub(
    r"or\s+'(\d+\.\d+\.\d+)'",
    r'or "\1"',
    text,
)

# Validate BEFORE writing
env = Environment(loader=FileSystemLoader("/var/www/maxek-erp/templates"))
try:
    env.parse(text)  # compile without saving first
    print("Jinja2 parse: OK")
except TemplateSyntaxError as e:
    print(f"FAIL line {e.lineno}: {e.message}")
    for i, line in enumerate(text.splitlines(), 1):
        if e.lineno and abs(i - e.lineno) <= 3:
            print(f"  {i:4d}| {line}")
    raise SystemExit(1)

path.write_text(text)
print("Saved login.html")
PY

systemctl restart maxek-erp.service
sleep 3

if systemctl is-active --quiet maxek-erp.service; then
  echo "Service: RUNNING"
  curl -s -o /dev/null -w "Login → HTTP %{http_code}\n" http://127.0.0.1:8000/login
else
  echo "Service: FAILED"
  journalctl -u maxek-erp.service -n 15 --no-pager
  exit 1
fi
