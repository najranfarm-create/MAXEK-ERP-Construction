#!/usr/bin/env bash
# Deploy TOC Extension tool to live MAXEK ERP on VPS.
set -euo pipefail

PATCH_ROOT="${PATCH_ROOT:-/tmp/toc-extension-patch}"
LIVE_ROOT="${LIVE_ROOT:-/var/www/maxek-erp}"
LOGIN_BACKUP="${LOGIN_BACKUP:-${LIVE_ROOT}/templates/login.html.working-20260707}"
SERVICE="${SERVICE:-maxek-erp.service}"

if [[ ! -d "$PATCH_ROOT" ]]; then
  echo "Downloading patch from GitHub..."
  TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "$TMP_DIR"' EXIT
  git clone --depth 1 --branch cursor/toc-extension-0620 https://github.com/najranfarm-create/MAXEK-ERP-Construction.git "$TMP_DIR/repo" 2>/dev/null || \
    git clone --depth 1 https://github.com/najranfarm-create/MAXEK-ERP-Construction.git "$TMP_DIR/repo"
  PATCH_ROOT="$TMP_DIR/repo/deploy/toc-extension-patch"
fi

echo "==> Syncing TOC extension patch to ${LIVE_ROOT}"
sudo rsync -a "$PATCH_ROOT/toc_extension_service.py" "$LIVE_ROOT/"
sudo rsync -a "$PATCH_ROOT/app.py" "$LIVE_ROOT/"
sudo rsync -a "$PATCH_ROOT/ui_shell_config.py" "$LIVE_ROOT/"
sudo rsync -a "$PATCH_ROOT/templates/" "$LIVE_ROOT/templates/"
sudo rsync -a "$PATCH_ROOT/static/" "$LIVE_ROOT/static/"

if [[ -f "$LOGIN_BACKUP" ]]; then
  echo "==> Restoring working login.html"
  sudo cp "$LOGIN_BACKUP" "$LIVE_ROOT/templates/login.html"
fi

echo "==> Restarting ${SERVICE}"
sudo systemctl restart "$SERVICE"
sleep 2

curl -s -o /dev/null -w "login: %{http_code}\n" http://127.0.0.1:8000/login
curl -s -o /dev/null -w "toc-extension: %{http_code}\n" http://127.0.0.1:8000/toc-extension
echo "TOC Extension patch deployed."
