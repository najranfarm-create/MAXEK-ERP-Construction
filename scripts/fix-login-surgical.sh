#!/usr/bin/env bash
# Surgical login.html fix — preserves original ERP login/dashboard; fixes only Jinja 500 errors
set -euo pipefail

LOGIN="/var/www/maxek-erp/templates/login.html"
cp -a "$LOGIN" "${LOGIN}.bak.surgical.$(date +%Y%m%d%H%M%S)"

python3 <<'PY'
import re
from pathlib import Path
from jinja2 import Environment, FileSystemLoader, TemplateSyntaxError

path = Path("/var/www/maxek-erp/templates/login.html")
text = path.read_text()
original_len = len(text)

# 1) Logo: direct static path (nginx serves /static/)
text = re.sub(
    r"^\s*src=.*maxek-logo\.png.*$",
    '              src="/static/images/maxek-logo.png"',
    text,
    flags=re.MULTILINE,
)

# 2) Remove onerror (Jinja parses 'none')
text = re.sub(r'\s*onerror="[^"]*"', "", text)

# 3) Static url_for → direct /static/ path (preserve query string if present)
def static_href(m):
    return f'/static/{m.group(1)}'

text = re.sub(
    r'\{\{\s*url_for\(\s*[\'"]static[\'"]\s*,\s*filename\s*=\s*[\'"]([^\'"]+)[\'"]\s*\)\s*\}\}',
    static_href,
    text,
)

# 4) Non-static url_for: single → double quotes inside
text = re.sub(r"url_for\('([^']+)'\)", r'url_for("\1")', text)

# 5) Remove corrupted mashup fragments only
text = re.sub(r'"static\',\s*filename=\'[^\']*\'?\s*"?\s*/>', "", text)
text = re.sub(r"[\'\"]static\',\s*filename=[^\n]+", "", text)

path.write_text(text)

env = Environment(loader=FileSystemLoader("/var/www/maxek-erp/templates"))
try:
    env.get_template("login.html")
    print(f"Jinja2 compile: OK ({original_len} → {len(text)} bytes)")
except TemplateSyntaxError as e:
    lines = path.read_text().splitlines()
    print(f"FAIL line {e.lineno}: {e.message}")
    for i in range(max(0, (e.lineno or 1) - 4), min(len(lines), (e.lineno or 1) + 3)):
        print(f"  {i+1:4d}| {lines[i]}")
    raise SystemExit(1)
PY

systemctl restart maxek-erp.service
sleep 2

echo ""
echo "Login: $(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8000/login)"
echo "CSS:   $(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8000/static/css/maxek-login.css)"
echo ""
echo "Dashboard/app.py UNCHANGED — $(wc -l < /var/www/maxek-erp/app.py) lines"
echo "Sign in to verify dashboard tools. Do NOT restore .tar unless login still fails."
