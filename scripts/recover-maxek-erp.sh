#!/usr/bin/env bash
# Recover maxek-erp.service when port 8000 is down + fix login template
set -euo pipefail

APP_DIR="/var/www/maxek-erp"
LOGIN="${APP_DIR}/templates/login.html"
SERVICE="maxek-erp.service"

echo "=== MAXEK ERP recovery ==="

echo "--- Service status ---"
systemctl status "$SERVICE" --no-pager || true
echo ""

echo "--- Last 40 log lines ---"
journalctl -u "$SERVICE" -n 40 --no-pager || true
echo ""

echo "--- Port 8000 ---"
ss -tlnp | grep 8000 || echo "Nothing listening on 8000"
echo ""

echo "--- Test wsgi import ---"
cd "$APP_DIR"
if .venv/bin/python -c "from wsgi import app; print('wsgi OK')" 2>&1; then
  echo "Import: OK"
else
  echo "Import: FAILED (see above)"
fi
echo ""

echo "--- login.html line 15-22 ---"
sed -n '15,22p' "$LOGIN" 2>/dev/null || echo "login.html missing"
echo ""

# Restore latest backup if import failed or service inactive
if ! systemctl is-active --quiet "$SERVICE" 2>/dev/null; then
  LATEST_BAK=$(ls -t "${LOGIN}.bak."* 2>/dev/null | head -1 || true)
  if [ -n "$LATEST_BAK" ]; then
    echo "Service down — restoring latest backup: $LATEST_BAK"
    cp -a "$LATEST_BAK" "$LOGIN"
  fi
fi

# Apply known-good logo line
if [ -f "$LOGIN" ]; then
  cp -a "$LOGIN" "${LOGIN}.bak.recovery.$(date +%Y%m%d%H%M%S)"
  python3 <<'PY'
from pathlib import Path
path = Path("/var/www/maxek-erp/templates/login.html")
lines = path.read_text().splitlines(keepends=True)
good_inner = "src=\"{{ url_for('static', filename='images/maxek-logo.png') }}\""
out = []
for line in lines:
    if "maxek-logo.png" in line and "url_for" in line:
        indent = line[: len(line) - len(line.lstrip())]
        out.append(indent + good_inner + "\n")
    else:
        out.append(line)
path.write_text("".join(out))
print("login.html patched")
PY
fi

echo ""
echo "--- Restarting service ---"
systemctl daemon-reload
systemctl restart "$SERVICE"
sleep 3

if systemctl is-active --quiet "$SERVICE"; then
  echo "Service: RUNNING"
  curl -s -o /dev/null -w "GET /login → HTTP %{http_code}\n" http://127.0.0.1:8000/login || true
else
  echo "Service: STILL FAILED"
  journalctl -u "$SERVICE" -n 25 --no-pager
  exit 1
fi
