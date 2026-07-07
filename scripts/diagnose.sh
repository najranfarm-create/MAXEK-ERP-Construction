#!/usr/bin/env bash
# Print common failure causes for Internal Server Error
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$APP_DIR"

echo "=== MAXEK ERP diagnostics ==="
echo "App dir: $APP_DIR"
echo "PWD: $(pwd)"
echo ""

echo "--- Files ---"
for f in run.py wsgi.py requirements.txt .env .env.example; do
  if [ -f "$f" ]; then echo "OK  $f"; else echo "MISSING  $f"; fi
done
echo ""

echo "--- Virtualenv ---"
if [ -x .venv/bin/python ]; then
  .venv/bin/python --version
else
  echo "MISSING .venv — run: bash scripts/setup.sh"
  exit 1
fi
echo ""

echo "--- App import & database ---"
.venv/bin/python <<'PY'
from sqlalchemy import text
from run import app
from app.extensions import db
from app.models.user import User

with app.app_context():
    print("DB URI:", db.engine.url)
    try:
        db.session.execute(text("SELECT 1"))
        print("DB connection: OK")
    except Exception as e:
        print("DB connection: FAILED —", e)
        print("Fix: .venv/bin/flask --app run init-db")
    try:
        count = User.query.count()
        print(f"Users in DB: {count}")
    except Exception as e:
        print("Users query: FAILED —", e)
        print("Fix: .venv/bin/flask --app run init-db")
PY
echo ""

echo "--- HTTP smoke test (start server separately if needed) ---"
echo "Run: .venv/bin/flask --app run run --host 127.0.0.1 --port 5000 --debug"
echo "Then: curl -v http://127.0.0.1:5000/health"
