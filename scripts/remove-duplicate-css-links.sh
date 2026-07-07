#!/usr/bin/env bash
# Remove duplicate <link> stylesheet tags outside <head> in login.html
set -euo pipefail

LOGIN="/var/www/maxek-erp/templates/login.html"
cp -a "$LOGIN" "${LOGIN}.bak.dedup.$(date +%Y%m%d%H%M%S)"

python3 <<'PY'
from pathlib import Path
import re

path = Path("/var/www/maxek-erp/templates/login.html")
text = path.read_text()

# Split at </head> — only keep <link> tags in head section
m = re.search(r"(</head>)", text, re.I)
if not m:
    print("No </head> found")
    raise SystemExit(1)

head_part = text[: m.end()]
body_part = text[m.end() :]

# Remove all <link ...> from body
cleaned_body, n = re.subn(r"\s*<link[^>]+>\s*", "\n", body_part, flags=re.I)
print(f"Removed {n} duplicate <link> tag(s) from body")

path.write_text(head_part + cleaned_body)
print("Saved.")

# Show link lines in file
for i, line in enumerate(path.read_text().splitlines(), 1):
    if "<link" in line.lower():
        print(f"  line {i}: {line.strip()[:90]}")
PY

systemctl restart maxek-erp.service
sleep 2

echo ""
echo "--- Rendered page: link tags (should be 0 in body) ---"
curl -s http://127.0.0.1:8000/login | grep -n link

echo ""
echo "--- Form content present? ---"
curl -s http://127.0.0.1:8000/login | grep -iE 'form|password|Sign In|login-submit' | head -8
