#!/usr/bin/env bash
# Deploy DPR corrections + Revised Estimate to live MAXEK ERP (/var/www/maxek-erp)
set -euo pipefail

PATCH_DIR="$(cd "$(dirname "$0")" && pwd)"
LIVE="/var/www/maxek-erp"

echo "Deploying from ${PATCH_DIR} to ${LIVE}"

sudo rsync -av "${PATCH_DIR}/"*.py "${LIVE}/"
sudo rsync -av "${PATCH_DIR}/templates/" "${LIVE}/templates/"
sudo rsync -av "${PATCH_DIR}/static/" "${LIVE}/static/"

if [[ -f "${LIVE}/templates/login.html.working-20260707" ]]; then
  sudo cp "${LIVE}/templates/login.html.working-20260707" "${LIVE}/templates/login.html"
fi

sudo systemctl restart maxek-erp.service
echo "Done. Verify: curl -I http://127.0.0.1:8000/dpr-entry"
