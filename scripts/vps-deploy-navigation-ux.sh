#!/usr/bin/env bash
# Deploy navigation UX patch to live MAXEK ERP on VPS (srv1704727).
# Preserves working login.html and production database.
set -euo pipefail

PATCH_ROOT="${PATCH_ROOT:-/tmp/navigation-ux-patch}"
LIVE_ROOT="${LIVE_ROOT:-/var/www/maxek-erp}"
LOGIN_BACKUP="${LOGIN_BACKUP:-${LIVE_ROOT}/templates/login.html.working-20260707}"
SERVICE="${SERVICE:-maxek-erp.service}"

if [[ ! -d "$PATCH_ROOT" ]]; then
  echo "Downloading patch from GitHub..."
  TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "$TMP_DIR"' EXIT
  git clone --depth 1 https://github.com/najranfarm-create/MAXEK-ERP-Construction.git "$TMP_DIR/repo"
  PATCH_ROOT="$TMP_DIR/repo/deploy/navigation-ux-patch"
fi

echo "==> Syncing navigation UX patch to ${LIVE_ROOT}"
sudo rsync -a "$PATCH_ROOT/navigation_service.py" "$LIVE_ROOT/"
sudo rsync -a "$PATCH_ROOT/app.py" "$LIVE_ROOT/"
sudo rsync -a "$PATCH_ROOT/templates/" "$LIVE_ROOT/templates/"
sudo rsync -a "$PATCH_ROOT/static/" "$LIVE_ROOT/static/"

if [[ -f "$LOGIN_BACKUP" ]]; then
  echo "==> Restoring working login.html"
  sudo cp "$LOGIN_BACKUP" "$LIVE_ROOT/templates/login.html"
fi

echo "==> Restarting ${SERVICE}"
sudo systemctl restart "$SERVICE"
sleep 2

echo "==> Health checks"
curl -s -o /dev/null -w "login: %{http_code}\n" http://127.0.0.1:8000/login
curl -s -o /dev/null -w "dpr-entry: %{http_code}\n" http://127.0.0.1:8000/dpr-entry
curl -s -o /dev/null -w "document-management: %{http_code}\n" http://127.0.0.1:8000/document-management

echo "Done. Hard-refresh browser (Ctrl+Shift+R) after deploy."
