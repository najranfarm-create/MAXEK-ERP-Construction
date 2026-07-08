#!/usr/bin/env bash
# Fix-forward: add missing navigation_service.py (if you want to keep the new app.py)
set -euo pipefail

LIVE="${LIVE:-/var/www/maxek-erp}"
PATCH_REPO="${PATCH_REPO:-https://raw.githubusercontent.com/najranfarm-create/MAXEK-ERP-Construction}"
BRANCH="${BRANCH:-cursor/navigation-ux-0620}"
NAV_PY="${PATCH_REPO}/${BRANCH}/deploy/navigation-ux-patch/navigation_service.py"

echo "==> Installing navigation_service.py"
curl -fsSL "${NAV_PY}" -o "${LIVE}/navigation_service.py"
wc -l "${LIVE}/navigation_service.py"

systemctl restart maxek-erp.service
sleep 4
systemctl is-active maxek-erp.service
journalctl -u maxek-erp.service -n 15 --no-pager
