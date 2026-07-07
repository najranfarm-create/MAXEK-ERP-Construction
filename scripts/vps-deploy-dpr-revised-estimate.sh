#!/usr/bin/env bash
# One-shot VPS deploy: DPR corrections + Revised Estimate
# Run ON THE SERVER (srv1704727) as a user with sudo:
#   curl -fsSL https://raw.githubusercontent.com/najranfarm-create/MAXEK-ERP-Construction/main/scripts/vps-deploy-dpr-revised-estimate.sh | bash

set -euo pipefail

REPO="https://github.com/najranfarm-create/MAXEK-ERP-Construction.git"
BRANCH="${BRANCH:-main}"
WORKDIR="/tmp/maxek-dpr-deploy-$$"
LIVE="/var/www/maxek-erp"
PATCH_SUB="deploy/dpr-revised-estimate-patch"

cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

echo "==> Cloning ${REPO} (branch ${BRANCH})"
git clone --depth 1 --branch "$BRANCH" "$REPO" "$WORKDIR"

PATCH="${WORKDIR}/${PATCH_SUB}"
if [[ ! -d "$PATCH" ]]; then
  echo "ERROR: Patch folder missing: ${PATCH_SUB}"
  exit 1
fi

echo "==> Rsync to ${LIVE}"
sudo rsync -av "${PATCH}/"*.py "${LIVE}/"
sudo rsync -av "${PATCH}/templates/" "${LIVE}/templates/"
sudo rsync -av "${PATCH}/static/" "${LIVE}/static/"

if [[ -f "${LIVE}/templates/login.html.working-20260707" ]]; then
  echo "==> Restore working login.html"
  sudo cp "${LIVE}/templates/login.html.working-20260707" "${LIVE}/templates/login.html"
fi

echo "==> Restart maxek-erp"
sudo systemctl restart maxek-erp.service
sleep 2

echo "==> Health check"
curl -sI http://127.0.0.1:8000/login | head -3
curl -sI http://127.0.0.1:8000/dpr-entry | head -3
curl -sI http://127.0.0.1:8000/revised-estimate | head -3
echo "Deploy complete."
