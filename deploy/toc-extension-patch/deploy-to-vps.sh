#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIVE_ROOT="${LIVE_ROOT:-/var/www/maxek-erp}"
LOGIN_BACKUP="${LOGIN_BACKUP:-${LIVE_ROOT}/templates/login.html.working-20260707}"
SERVICE="${SERVICE:-maxek-erp.service}"

sudo rsync -a "$SCRIPT_DIR/toc_extension_service.py" "$LIVE_ROOT/"
sudo rsync -a "$SCRIPT_DIR/app.py" "$LIVE_ROOT/"
sudo rsync -a "$SCRIPT_DIR/ui_shell_config.py" "$LIVE_ROOT/"
sudo rsync -a "$SCRIPT_DIR/templates/" "$LIVE_ROOT/templates/"
sudo rsync -a "$SCRIPT_DIR/static/" "$LIVE_ROOT/static/"

if [[ -f "$LOGIN_BACKUP" ]]; then
  sudo cp "$LOGIN_BACKUP" "$LIVE_ROOT/templates/login.html"
fi

sudo systemctl restart "$SERVICE"
sleep 2
curl -s -o /dev/null -w "toc-extension: %{http_code}\n" http://127.0.0.1:8000/toc-extension
echo "Done."
