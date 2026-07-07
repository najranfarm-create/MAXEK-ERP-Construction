#!/usr/bin/env bash
# Capture /login 500 traceback from original ERP — writes to /tmp/maxek-login-error.txt
# Run: sudo bash scripts/capture-login-error.sh
set -euo pipefail

APP_DIR="/var/www/maxek-erp"
OUT="/tmp/maxek-login-error.txt"
SERVICE="maxek-erp.service"

{
  echo "=== MAXEK login error capture $(date -u) ==="
  echo ""

  echo "--- journalctl (last 120 lines) ---"
  journalctl -u "$SERVICE" -n 120 --no-pager 2>&1 || true
  echo ""

  echo "--- test_client GET /login ---"
  cd "$APP_DIR"
  .venv/bin/python <<'PY' 2>&1 || true
import sys, traceback
sys.path.insert(0, ".")
try:
    from wsgi import app
except ImportError:
    from run import app

app.config["PROPAGATE_EXCEPTIONS"] = True
app.config["TESTING"] = True

with app.test_client() as c:
    try:
        r = c.get("/login")
        print("status:", r.status_code)
        print(r.get_data(as_text=True)[:2000])
    except Exception:
        traceback.print_exc()
PY
  echo ""

  echo "--- curl local ---"
  curl -s -D - http://127.0.0.1:8000/login -o /tmp/login-body.html 2>&1 || true
  head -30 /tmp/login-body.html 2>/dev/null || true

} | tee "$OUT"

echo ""
echo "Saved to: $OUT"
echo "Paste contents: cat $OUT"
