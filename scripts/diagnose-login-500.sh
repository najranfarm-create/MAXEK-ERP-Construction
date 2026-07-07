#!/usr/bin/env bash
# Diagnose /login HTTP 500 on the ORIGINAL ERP at /var/www/maxek-erp
# Does NOT modify application code.
set -euo pipefail

APP_DIR="/var/www/maxek-erp"
SERVICE_NAME="maxek-erp.service"

echo "=== MAXEK ERP — /login 500 diagnostics ==="
echo "App: ${APP_DIR}"
echo ""

if [ ! -d "${APP_DIR}" ]; then
  echo "ERROR: ${APP_DIR} not found"
  exit 1
fi

cd "${APP_DIR}"

echo "--- 1. Service status ---"
systemctl is-active "${SERVICE_NAME}" && echo "Service: active" || echo "Service: INACTIVE"
echo ""

echo "--- 2. Recent Gunicorn / app errors (journalctl) ---"
journalctl -u "${SERVICE_NAME}" -n 80 --no-pager 2>/dev/null || echo "(no journal access)"
echo ""

echo "--- 3. Key files ---"
for f in wsgi.py run.py app.py .env requirements.txt; do
  [ -f "$f" ] && echo "OK  $f" || echo "MISSING  $f"
done
echo ""

echo "--- 4. Python import test ---"
if [ -x .venv/bin/python ]; then
  .venv/bin/python <<'PY' 2>&1 || true
import traceback
import sys
sys.path.insert(0, ".")

print("Attempting to import wsgi:app ...")
try:
    from wsgi import app
    print("OK  wsgi:app imported")
    print("DEBUG:", app.debug)
    print("SECRET_KEY set:", bool(app.config.get("SECRET_KEY")))
except Exception:
    traceback.print_exc()
    print("\nTrying run:app ...")
    try:
        from run import app
        print("OK  run:app imported")
    except Exception:
        traceback.print_exc()
PY
else
  echo "MISSING .venv/bin/python"
fi
echo ""

echo "--- 5. In-app request test (/login) ---"
if [ -x .venv/bin/python ]; then
  .venv/bin/python <<'PY' 2>&1 || true
import traceback
import sys
sys.path.insert(0, ".")

try:
    from wsgi import app
except ImportError:
    from run import app

with app.test_client() as client:
    try:
        resp = client.get("/login", follow_redirects=False)
        print(f"GET /login → HTTP {resp.status_code}")
        if resp.status_code >= 500:
            body = resp.get_data(as_text=True)
            print("Response body (first 800 chars):")
            print(body[:800])
    except Exception:
        traceback.print_exc()
PY
else
  echo "SKIP (no venv)"
fi
echo ""

echo "--- 6. Database / env hints ---"
if [ -f .env ]; then
  echo ".env exists. Keys (values hidden):"
  grep -E '^[A-Z_]+=' .env | cut -d= -f1 | sed 's/^/  /'
else
  echo "WARNING: .env missing"
fi

for db in *.db instance/*.db; do
  [ -f "$db" ] && echo "DB file: $db ($(du -h "$db" | cut -f1))"
done 2>/dev/null
echo ""

echo "--- 7. Live curl ---"
curl -s -o /dev/null -w "http://127.0.0.1:8000/login → HTTP %{http_code}\n" http://127.0.0.1:8000/login || true
curl -s -o /dev/null -w "https://erp.maxekindia.com/login → HTTP %{http_code}\n" https://erp.maxekindia.com/login || true
curl -s -o /dev/null -w "https://erp.maxekindia.com/static/css/maxek-login.css → HTTP %{http_code}\n" \
  https://erp.maxekindia.com/static/css/maxek-login.css || true
echo ""

echo "=== Next steps if /login still 500 ==="
echo "  sudo journalctl -u ${SERVICE_NAME} -f"
echo "  # In another terminal, run: curl http://127.0.0.1:8000/login"
echo ""
echo "  # Or run Flask debug (temporary, port 5001):"
echo "  cd ${APP_DIR} && .venv/bin/flask --app wsgi:app run --host 127.0.0.1 --port 5001 --debug"
echo "  # Then: curl http://127.0.0.1:5001/login"
echo ""
echo "Paste journalctl traceback here for app-level fix."
