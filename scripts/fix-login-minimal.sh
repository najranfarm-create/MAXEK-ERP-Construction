#!/usr/bin/env bash
# Minimal login.html fix — only known-bad lines, no global url_for replacement
set -euo pipefail

LOGIN="/var/www/maxek-erp/templates/login.html"
BAK="/var/www/maxek-erp/templates/login.html.bak.20260707215039"

[ -f "$BAK" ] || BAK="${LOGIN}.bak.20260707215039"
cp -a "$BAK" "$LOGIN"
cp -a "$LOGIN" "${LOGIN}.bak.minimal.$(date +%Y%m%d%H%M%S)"
echo "Restored from backup, applying minimal fixes only..."

python3 <<'PY'
import re
from pathlib import Path
from jinja2 import Environment, FileSystemLoader, TemplateSyntaxError

path = Path("/var/www/maxek-erp/templates/login.html")
lines = path.read_text().splitlines()
out = []

for i, line in enumerate(lines):
    n = i + 1
    new = line

    # Line ~18: logo src
    if "maxek-logo.png" in line and ("src=" in line or "url_for" in line):
        indent = line[: len(line) - len(line.lstrip())]
        new = indent + 'src="/static/images/maxek-logo.png"'
        print(f"fix {n}: logo src")

    # Remove onerror (none breaks Jinja)
    if "onerror=" in line:
        print(f"fix {n}: remove onerror")
        continue  # drop line

    # Static CSS link only (line ~9)
    if "<link" in line and "maxek-login.css" in line and "url_for" in line:
        indent = line[: len(line) - len(line.lstrip())]
        m = re.search(r"filename\s*=\s*['\"]([^'\"]+)['\"]", line)
        ver = m.group(1) if m else "css/maxek-login.css"
        new = f'{indent}<link rel="stylesheet" href="/static/{ver}">'
        print(f"fix {n}: css link")

    # forgot_password link only (line ~153)
    if "forgot_password" in line and "url_for" in line:
        new = re.sub(
            r"href\s*=\s*['\"][^'\"]*['\"]",
            'href="{{ url_for(\"forgot_password\") }}"',
            line,
        )
        print(f"fix {n}: forgot_password")

    # app_version (line ~161)
    if "app_version" in line and "1.0.0" in line:
        new = re.sub(
            r"\{\{[^}]+\}\}",
            '{{ app_version or "1.0.0" }}',
            line,
        )
        print(f"fix {n}: app_version")

    out.append(new)

text = "\n".join(out) + "\n"
env = Environment(loader=FileSystemLoader("/var/www/maxek-erp/templates"))

try:
    env.parse(text)
    print("Jinja2: OK")
except TemplateSyntaxError as e:
    print(f"FAIL line {e.lineno}: {e.message}")
    fixed_lines = text.splitlines()
    ln = e.lineno or 1
    for j in range(max(0, ln - 5), min(len(fixed_lines), ln + 4)):
        print(f"  {j+1:4d}| {fixed_lines[j]}")
    raise SystemExit(1)

path.write_text(text)
print("Saved.")
PY

systemctl restart maxek-erp.service
sleep 3
curl -s -o /dev/null -w "Login → HTTP %{http_code}\n" http://127.0.0.1:8000/login || journalctl -u maxek-erp.service -n 10 --no-pager
