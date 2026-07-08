#!/usr/bin/env bash
# Hotfix: Revised Estimate 500 — sqlite3.Row has no .get()
# Run on VPS as root:
#   curl -fsSL https://raw.githubusercontent.com/najranfarm-create/MAXEK-ERP-Construction/main/deploy/hotfix-revised-estimate-sqlite-row.sh | sudo bash
# Or after git clone:
#   sudo bash deploy/hotfix-revised-estimate-sqlite-row.sh
set -euo pipefail

LIVE="${LIVE:-/var/www/maxek-erp}"
TS="$(date +%Y%m%d%H%M%S)"
SERVICE_FILE="${LIVE}/revised_estimate_service.py"
PATCH_SRC="${PATCH_SRC:-}"

echo "==> MAXEK ERP — Revised Estimate sqlite3.Row hotfix"
echo "    Target: ${LIVE}"

if [[ -z "${PATCH_SRC}" ]]; then
  STAGING="/tmp/maxek-re-hotfix-${TS}"
  rm -rf "${STAGING}"
  git clone --depth 1 --branch main \
    https://github.com/najranfarm-create/MAXEK-ERP-Construction.git "${STAGING}" 2>/dev/null \
    || git clone --depth 1 \
      https://github.com/najranfarm-create/MAXEK-ERP-Construction.git "${STAGING}"
  PATCH_SRC="${STAGING}/deploy/dpr-boq-ux-patch/revised_estimate_service.py"
fi

if [[ ! -f "${PATCH_SRC}" ]]; then
  echo "ERROR: patch file not found: ${PATCH_SRC}"
  exit 1
fi

if [[ ! -f "${SERVICE_FILE}" ]]; then
  echo "ERROR: ${SERVICE_FILE} not found"
  exit 1
fi

cp -a "${SERVICE_FILE}" "${SERVICE_FILE}.bak-${TS}"
install -m 0644 "${PATCH_SRC}" "${SERVICE_FILE}"
echo "==> Installed fixed revised_estimate_service.py (backup: revised_estimate_service.py.bak-${TS})"

systemctl restart maxek-erp.service
sleep 3

STATUS="$(systemctl is-active maxek-erp.service || true)"
echo "==> Service: ${STATUS}"

if [[ "${STATUS}" != "active" ]]; then
  journalctl -u maxek-erp.service -n 30 --no-pager
  exit 1
fi

HTTP_LOGIN="$(curl -s -o /dev/null -w '%{http_code}' 'http://127.0.0.1:8000/login' || echo 000)"
HTTP_REV="$(curl -s -o /dev/null -w '%{http_code}' 'http://127.0.0.1:8000/revised-estimate' || echo 000)"
echo "==> HTTP /login => ${HTTP_LOGIN}"
echo "==> HTTP /revised-estimate => ${HTTP_REV} (302 = redirect to login, expected without session)"
echo "==> Done. Sign in via browser, then open Revised Estimate."
