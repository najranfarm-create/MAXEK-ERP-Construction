#!/usr/bin/env bash
# Fix remaining login.html issues: line 22 onerror + line 153 forgot_password url_for
set -euo pipefail

LOGIN="/var/www/maxek-erp/templates/login.html"
cp -a "$LOGIN" "${LOGIN}.bak.final.$(date +%Y%m%d%H%M%S)"

python3 <<'PY'
import re
from pathlib import Path
from jinja2 import Environment, FileSystemLoader, TemplateSyntaxError

path = Path("/var/www/maxek-erp/templates/login.html")
text = path.read_text()

# Remove onerror entirely (line 22 — "none" breaks Jinja lexer)
text = re.sub(r'\s*onerror="[^"]*"', "", text)

# Fix forgot_password link — use double quotes inside url_for
text = re.sub(
    r"href=\"\{\{\s*url_for\('forgot_password'\)\s*\}\}\"",
    'href="{{ url_for("forgot_password") }}"',
    text,
)
text = re.sub(
    r"href='\{\{\s*url_for\('forgot_password'\)\s*\}\}'",
    'href="{{ url_for("forgot_password") }}"',
    text,
)

# Catch-all: any remaining url_for with single quotes → double quotes
text = re.sub(
    r"url_for\('([^']+)'\)",
    r'url_for("\1")',
    text,
)

path.write_text(text)
print("Fixed: removed onerror, fixed forgot_password url_for")

env = Environment(loader=FileSystemLoader("/var/www/maxek-erp/templates"))
try:
    env.get_template("login.html")
    print("Jinja2 compile: OK")
except TemplateSyntaxError as e:
    lines = path.read_text().splitlines()
    print(f"FAIL line {e.lineno}: {e.message}")
    for i in range(max(0,(e.lineno or 1)-4), min(len(lines),(e.lineno or 1)+3)):
        print(f"  {i+1:4d}| {lines[i]}")
    raise SystemExit(1)
PY

systemctl restart maxek-erp.service
sleep 2
curl -s -o /dev/null -w "GET /login → HTTP %{http_code}\n" http://127.0.0.1:8000/login
curl -s -o /dev/null -w "GET /login (public) → HTTP %{http_code}\n" https://erp.maxekindia.com/login
