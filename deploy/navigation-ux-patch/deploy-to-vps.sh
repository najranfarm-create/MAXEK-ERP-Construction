#!/usr/bin/env bash
# Run on VPS as root or with sudo.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_ROOT="$SCRIPT_DIR"
LIVE_ROOT="${LIVE_ROOT:-/var/www/maxek-erp}"
LOGIN_BACKUP="${LOGIN_BACKUP:-${LIVE_ROOT}/templates/login.html.working-20260707}"
SERVICE="${SERVICE:-maxek-erp.service}"

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

curl -s -o /dev/null -w "login: %{http_code}\n" http://127.0.0.1:8000/login
curl -s -o /dev/null -w "dpr-entry: %{http_code}\n" http://127.0.0.1:8000/dpr-entry
echo "Navigation UX patch deployed."
