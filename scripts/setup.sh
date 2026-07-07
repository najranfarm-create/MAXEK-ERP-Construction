#!/usr/bin/env bash
# MAXEK ERP Flask — first-time server setup
# Run from /var/www/maxek-erp-flask as root or deploy user:
#   bash scripts/setup.sh

set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$APP_DIR"

echo "==> MAXEK ERP setup in $APP_DIR"

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 is not installed."
  echo "Install with: apt update && apt install -y python3 python3-venv python3-pip"
  exit 1
fi

# Debian/Ubuntu: venv needs python3-venv (or python3-full)
if ! python3 -m venv --help >/dev/null 2>&1; then
  echo "ERROR: python3-venv is not installed."
  echo "Install with: apt update && apt install -y python3-venv"
  exit 1
fi

if [ ! -f requirements.txt ]; then
  echo "ERROR: requirements.txt not found."
  echo "Clone the repo first, e.g.:"
  echo "  git clone https://github.com/najranfarm-create/MAXEK-ERP-Construction.git /var/www/maxek-erp-flask"
  echo "  cd /var/www/maxek-erp-flask && git checkout cursor/auth-setup-flask-0620"
  exit 1
fi

echo "==> Creating virtual environment (.venv)"
python3 -m venv .venv

echo "==> Installing Python packages (inside venv — not system-wide)"
.venv/bin/pip install --upgrade pip
.venv/bin/pip install -r requirements.txt

if [ ! -f .env ]; then
  if [ -f .env.example ]; then
    cp .env.example .env
    echo "==> Created .env from .env.example — edit SECRET_KEY and ADMIN_PASSWORD before production"
  else
    echo "ERROR: .env.example missing. Pull the latest code from git."
    exit 1
  fi
else
  echo "==> .env already exists, leaving unchanged"
fi

echo "==> Initializing database"
.venv/bin/flask --app run init-db

echo ""
echo "Setup complete."
echo ""
echo "Start development server:"
echo "  cd $APP_DIR"
echo "  .venv/bin/flask --app run run --host 0.0.0.0 --port 5000"
echo ""
echo "Or production (gunicorn):"
echo "  .venv/bin/gunicorn -w 4 -b 127.0.0.1:8000 run:app"
echo ""
echo "Sign in at /auth/login with ADMIN_EMAIL / ADMIN_PASSWORD from .env"
