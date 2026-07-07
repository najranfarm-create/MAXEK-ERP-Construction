#!/usr/bin/env bash
# Clean corrupted url_for remnants in login.html (line 9 mashup)
set -euo pipefail

LOGIN="/var/www/maxek-erp/templates/login.html"
cp -a "$LOGIN" "${LOGIN}.bak.clean.$(date +%Y%m%d%H%M%S)"

python3 <<'PY'
import re
from pathlib import Path

path = Path("/var/www/maxek-erp/templates/login.html")
lines = path.read_text().splitlines()
out = []
css_line = '    <link rel="stylesheet" href="/static/css/maxek-login.css?v=20260707">'
fa_line = '    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css" />'
has_css = False
has_fa = False

for i, line in enumerate(lines):
    # Drop corrupted mashup lines
    if "static', filename=" in line or "url_for" in line and "static" in line:
        print(f"REMOVED corrupted line {i+1}: {line[:80]}...")
        continue
    # Drop broken link tags with garbage
    if "<link" in line and ("static'" in line or 'filename=' in line):
        print(f"REMOVED broken link {i+1}: {line[:80]}...")
        continue
    if "maxek-login.css" in line:
        if not has_css:
            out.append(css_line)
            has_css = True
        continue
    if "font-awesome" in line:
        if not has_fa:
            out.append(fa_line)
            has_fa = True
        continue
    out.append(line)

if not has_css:
    # insert after head
    for j, line in enumerate(out):
        if re.search(r"<head", line, re.I):
            out.insert(j + 1, css_line)
            has_css = True
            break

path.write_text("\n".join(out) + "\n")
print("Cleaned login.html")

from jinja2 import Environment, FileSystemLoader
env = Environment(loader=FileSystemLoader("/var/www/maxek-erp/templates"))
env.get_template("login.html")
print("Jinja2: OK")
PY

echo ""
echo "Lines 1-15:"
sed -n '1,15p' "$LOGIN"

systemctl restart maxek-erp.service
sleep 2
curl -s http://127.0.0.1:8000/login | grep -i link
