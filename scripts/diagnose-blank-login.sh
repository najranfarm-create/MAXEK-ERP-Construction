#!/usr/bin/env bash
# Diagnose blank/white login page — check HTML, CSS, images
set -euo pipefail

echo "=== Login page blank screen diagnostics ==="
echo ""

echo "--- 1. Fetch login HTML, show head + css links ---"
curl -s http://127.0.0.1:8000/login | head -40
echo ""
curl -s http://127.0.0.1:8000/login | grep -iE 'link|stylesheet|css|script|src=|href=' | head -20
echo ""

echo "--- 2. Test static assets ---"
for path in \
  /static/css/maxek-login.css \
  /static/css/login.css \
  /static/css/style.css \
  /static/images/maxek-logo.png
do
  code=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:8000${path}")
  pub=$(curl -s -o /dev/null -w "%{http_code}" "https://erp.maxekindia.com${path}" 2>/dev/null || echo "skip")
  echo "  ${path}  local=${code}  public=${pub}"
done
echo ""

echo "--- 3. List static/css on disk ---"
ls -la /var/www/maxek-erp/static/css/ 2>/dev/null | head -15 || echo "no static/css dir"
echo ""

echo "--- 4. login.html stylesheet lines ---"
grep -n -iE 'link|stylesheet|css|maxek-login' /var/www/maxek-erp/templates/login.html | head -15
echo ""

echo "--- 5. HTML size ---"
curl -s http://127.0.0.1:8000/login | wc -c
echo "bytes (expect ~6000+)"
