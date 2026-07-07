#!/usr/bin/env bash
# Fix production Nginx static routing + systemd for ORIGINAL ERP at /var/www/maxek-erp
#
# SAFE: Does NOT modify application code under /var/www/maxek-erp
# Does NOT touch /var/www/maxek-erp-flask
#
# Run on the VPS as root:
#   curl -fsSL .../scripts/fix-production-routing.sh | bash
# Or copy deploy/ files and run locally:
#   bash scripts/fix-production-routing.sh

set -euo pipefail

APP_DIR="/var/www/maxek-erp"
STATIC_DIR="${APP_DIR}/static"
SERVICE_NAME="maxek-erp.service"
NGINX_SITE="erp.maxekindia.com"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "=== MAXEK ERP production routing fix ==="
echo "App directory (read-only check): ${APP_DIR}"
echo ""

# ── Preconditions ──────────────────────────────────────────────────────────
if [ ! -d "${APP_DIR}" ]; then
  echo "ERROR: ${APP_DIR} does not exist. This script only fixes routing for the original ERP."
  exit 1
fi

if [ ! -f "${APP_DIR}/wsgi.py" ] && [ ! -f "${APP_DIR}/run.py" ]; then
  echo "WARNING: No wsgi.py or run.py in ${APP_DIR} — verify this is the correct ERP tree."
fi

if [ ! -d "${STATIC_DIR}" ]; then
  echo "ERROR: ${STATIC_DIR} not found. Static routing cannot be fixed."
  exit 1
fi

if [ ! -f "${STATIC_DIR}/css/maxek-login.css" ]; then
  echo "WARNING: ${STATIC_DIR}/css/maxek-login.css not found — static path may differ."
  ls -la "${STATIC_DIR}/" 2>/dev/null || true
else
  echo "OK  Found ${STATIC_DIR}/css/maxek-login.css"
fi

if [ ! -x "${APP_DIR}/.venv/bin/gunicorn" ]; then
  echo "ERROR: ${APP_DIR}/.venv/bin/gunicorn not found."
  exit 1
fi
echo "OK  Gunicorn venv present"
echo ""

# ── Systemd ──────────────────────────────────────────────────────────────────
echo "==> Installing systemd unit: /etc/systemd/system/${SERVICE_NAME}"
cp "${REPO_ROOT}/deploy/systemd/maxek-erp.service" "/etc/systemd/system/${SERVICE_NAME}"
chmod 644 "/etc/systemd/system/${SERVICE_NAME}"

echo "==> systemd daemon-reload"
systemctl daemon-reload

echo "==> Restart ${SERVICE_NAME}"
systemctl enable "${SERVICE_NAME}" 2>/dev/null || true
systemctl restart "${SERVICE_NAME}"
systemctl --no-pager status "${SERVICE_NAME}" || true
echo ""

# ── Nginx ────────────────────────────────────────────────────────────────────
NGINX_AVAILABLE="/etc/nginx/sites-available/${NGINX_SITE}"
NGINX_ENABLED="/etc/nginx/sites-enabled/${NGINX_SITE}"

echo "==> Backing up existing Nginx config (if any)"
if [ -f "${NGINX_AVAILABLE}" ]; then
  cp -a "${NGINX_AVAILABLE}" "${NGINX_AVAILABLE}.bak.$(date +%Y%m%d%H%M%S)"
fi

echo "==> Installing Nginx site config"
cp "${REPO_ROOT}/deploy/nginx/erp.maxekindia.com.conf" "${NGINX_AVAILABLE}"
ln -sf "${NGINX_AVAILABLE}" "${NGINX_ENABLED}"

echo "==> nginx -t"
nginx -t

echo "==> Reload Nginx"
systemctl reload nginx
echo ""

# ── Verify ───────────────────────────────────────────────────────────────────
echo "=== Verification ==="
echo ""
echo "--- systemd WorkingDirectory / ExecStart ---"
systemctl show "${SERVICE_NAME}" -p WorkingDirectory -p ExecStart --no-pager
echo ""

check() {
  local label="$1"
  local url="$2"
  local code
  code=$(curl -s -o /dev/null -w "%{http_code}" -I "$url" 2>/dev/null || echo "000")
  printf "%-50s HTTP %s\n" "$label" "$code"
}

check "Local login"        "http://127.0.0.1:8000/login"
check "Local static CSS"   "http://127.0.0.1:8000/static/css/maxek-login.css"
check "Public login"       "https://erp.maxekindia.com/login"
check "Public static CSS"  "https://erp.maxekindia.com/static/css/maxek-login.css"
echo ""

echo "=== Done ==="
echo "Changes made:"
echo "  • /etc/systemd/system/${SERVICE_NAME}  → WorkingDirectory=${APP_DIR}"
echo "  • ${NGINX_AVAILABLE}  → location /static/ alias ${STATIC_DIR}/"
echo ""
echo "NOT modified: ${APP_DIR} application files"
