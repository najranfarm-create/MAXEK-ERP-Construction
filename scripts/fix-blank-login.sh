#!/usr/bin/env bash
# Fix blank white login page — ensure CSS link exists in login.html
set -euo pipefail

LOGIN="/var/www/maxek-erp/templates/login.html"
CSS_FILE="/var/www/maxek-erp/static/css/maxek-login.css"
CSS_LINK='    <link rel="stylesheet" href="/static/css/maxek-login.css">'

echo "=== Fix blank login page ==="

echo "--- CSS file on disk ---"
ls -la "$CSS_FILE" 2>/dev/null || ls -la /var/www/maxek-erp/static/css/ 2>/dev/null

echo ""
echo "--- Current stylesheet refs in login.html ---"
grep -n -i 'stylesheet\|maxek-login\|<link\|<head' "$LOGIN" | head -15 || echo "(none found)"

cp -a "$LOGIN" "${LOGIN}.bak.css.$(date +%Y%m%d%H%M%S)"

python3 <<'PY'
from pathlib import Path
import re

login = Path("/var/www/maxek-erp/templates/login.html")
text = login.read_text()
css_link = '    <link rel="stylesheet" href="/static/css/maxek-login.css">'

# Remove broken orphan static path lines
text = re.sub(r'^\s*["\']/static/css/[^"\']+["\']\s*\n', '', text, flags=re.MULTILINE)

if "maxek-login.css" not in text:
    if re.search(r'<head[^>]*>', text, re.I):
        text = re.sub(r'(<head[^>]*>)', r'\1\n' + css_link, text, count=1, flags=re.I)
        print("Inserted CSS link after <head>")
    elif re.search(r'<!DOCTYPE', text, re.I):
        text = re.sub(r'(<!DOCTYPE[^>]*>)', r'\1\n<html>\n<head>\n' + css_link + '\n</head>\n<body>', text, count=1, flags=re.I)
        print("Added head block with CSS")
    else:
        text = css_link + "\n" + text
        print("Prepended CSS link")
else:
    text = re.sub(
        r'<link[^>]*maxek-login\.css[^>]*>',
        css_link.strip(),
        text,
        flags=re.I,
    )
    print("Normalized CSS link")

login.write_text(text)

# Also fix base.html if login extends it
for name in ("base.html", "layout.html", "main.html"):
    base = Path(f"/var/www/maxek-erp/templates/{name}")
    if base.exists() and "maxek-login.css" not in base.read_text():
        print(f"Note: {name} exists — check if login extends it")
PY

# Check if login extends another template
echo ""
echo "--- Template extends ---"
grep -n "extends" "$LOGIN" | head -3

systemctl restart maxek-erp.service
sleep 2

echo ""
echo "--- Verify ---"
curl -s http://127.0.0.1:8000/login | grep -iE 'link|stylesheet|css' || echo "STILL NO CSS IN HTML!"
curl -s -o /dev/null -w "CSS file → HTTP %{http_code}\n" http://127.0.0.1:8000/static/css/maxek-login.css
curl -s -o /dev/null -w "Login page → HTTP %{http_code}\n" http://127.0.0.1:8000/login
