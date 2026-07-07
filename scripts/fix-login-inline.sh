#!/usr/bin/env bash
# Paste and run directly on server — no curl needed
# sudo bash /tmp/fix-login-inline.sh
set -euo pipefail

LOGIN="/var/www/maxek-erp/templates/login.html"
cp -a "$LOGIN" "${LOGIN}.bak.$(date +%Y%m%d%H%M%S)"

python3 <<'PY'
import re
from pathlib import Path
from jinja2 import Environment, FileSystemLoader, TemplateSyntaxError

path = Path("/var/www/maxek-erp/templates/login.html")
lines = path.read_text().splitlines()
print(f"File: {path} ({len(lines)} lines)")
print("Lines containing 'none' or 'url_for':")
for i, line in enumerate(lines, 1):
    if "none" in line.lower() or "url_for" in line:
        print(f"  {i:4d}| {line}")

text = "\n".join(lines) + ("\n" if lines else "")

# Fix logo
text = re.sub(
    r"^\s*src=.*maxek-logo\.png.*$",
    '              src="/static/images/maxek-logo.png"',
    text,
    flags=re.MULTILINE,
)

# Fix onerror (all variants)
text = text.replace("onerror=\"this.style.display='none'\"", 'onerror="this.style.display=none"')
text = text.replace("onerror='this.style.display=\"none\"'", 'onerror="this.style.display=none"')
text = text.replace("this.style.display='none'", "this.style.display=none")

# Convert ALL url_for static to direct paths
text = re.sub(
    r"\{\{\s*url_for\(\s*['\"]static['\"]\s*,\s*filename\s*=\s*['\"]([^'\"]+)['\"]\s*\)\s*\}\}",
    r'"/static/\1"',
    text,
)

# Fix broken url_for missing commas: url_for('static' filename= -> url_for('static', filename=
text = re.sub(
    r"url_for\(\s*['\"]static['\"]\s+filename\s*=",
    "url_for('static', filename=",
    text,
)

path.write_text(text)
print("\nApplied fixes.")

env = Environment(loader=FileSystemLoader("/var/www/maxek-erp/templates"))
try:
    env.get_template("login.html")
    print("Jinja2 compile: OK")
except TemplateSyntaxError as e:
    print(f"\nJinja2 STILL FAILING line {e.lineno}: {e.message}")
    fixed = path.read_text().splitlines()
    if e.lineno:
        for i in range(max(0, e.lineno - 4), min(len(fixed), e.lineno + 3)):
            print(f"  {i+1:4d}| {fixed[i]}")
    raise SystemExit(1)
PY

systemctl restart maxek-erp.service
sleep 2
code=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8000/login)
echo "GET /login → HTTP $code"
[ "$code" = "200" ] || [ "$code" = "302" ] && echo SUCCESS || journalctl -u maxek-erp.service -n 15 --no-pager
