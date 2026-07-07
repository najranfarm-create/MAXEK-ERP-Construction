#!/usr/bin/env bash
# Aggressive login.html repair — removes ALL static url_for, fixes quotes
# Run on server: sudo bash fix-login-full.sh
set -euo pipefail

LOGIN="/var/www/maxek-erp/templates/login.html"
cp -a "$LOGIN" "${LOGIN}.bak.full.$(date +%Y%m%d%H%M%S)"

python3 <<'PY'
import re
from pathlib import Path
from jinja2 import Environment, FileSystemLoader, TemplateSyntaxError

path = Path("/var/www/maxek-erp/templates/login.html")
lines = path.read_text().splitlines()
out = []

for i, line in enumerate(lines):
    new = line

    # Replace any url_for('static', filename='...') with /static/...
    if "url_for" in line and "static" in line:
        m = re.search(r"filename\s*=\s*['\"]([^'\"]+)['\"]", line)
        if m:
            static_url = f"/static/{m.group(1)}"
            indent = line[: len(line) - len(line.lstrip())]
            if "href=" in line:
                new = re.sub(r'href\s*=\s*["\'][^"\']*["\']', f'href="{static_url}"', line)
                if new == line:
                    new = f'{indent}<link rel="stylesheet" href="{static_url}">'
            elif "src=" in line:
                new = re.sub(r'src\s*=\s*["\'][^"\']*["\']', f'src="{static_url}"', line)
            else:
                new = line.replace(line.strip(), f'"{static_url}"')

    # Fix onerror quotes
    new = new.replace("this.style.display='none'", "this.style.display=none")
    new = new.replace('this.style.display="none"', "this.style.display=none")

    # Fix broken Jinja: missing comma in url_for
    new = re.sub(r"url_for\(\s*['\"]static['\"]\s+filename", "url_for('static', filename", new)

    if new != line:
        print(f"  fixed line {i+1}")
    out.append(new)

path.write_text("\n".join(out) + "\n")

# Save numbered copy for debug
numbered = Path("/tmp/login-numbered.txt")
numbered.write_text("\n".join(f"{i+1:4d}| {l}" for i, l in enumerate(out)))
print(f"Saved {numbered}")

env = Environment(loader=FileSystemLoader("/var/www/maxek-erp/templates"))
try:
    env.get_template("login.html")
    print("Jinja2 compile: OK")
except TemplateSyntaxError as e:
    print(f"Jinja2 FAIL line {e.lineno}: {e.message}")
    for i in range(max(0, (e.lineno or 1) - 5), min(len(out), (e.lineno or 1) + 4)):
        print(f"  {i+1:4d}| {out[i]}")
    raise SystemExit(1)
PY

systemctl restart maxek-erp.service
sleep 2
curl -s http://127.0.0.1:8000/login > /dev/null
echo "--- journalctl (last error) ---"
journalctl -u maxek-erp.service -n 25 --no-pager | tail -20
echo ""
curl -s -o /dev/null -w "GET /login → HTTP %{http_code}\n" http://127.0.0.1:8000/login
