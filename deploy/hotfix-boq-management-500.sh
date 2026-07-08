#!/usr/bin/env bash
# Hotfix: BOQ Management 500 — missing url_for('boq_library') endpoint
# Run on VPS as root:
#   curl -fsSL https://raw.githubusercontent.com/najranfarm-create/MAXEK-ERP-Construction/cursor/boq-management-hotfix-f9eb/deploy/hotfix-boq-management-500.sh | sudo bash
set -euo pipefail

LIVE="${LIVE:-/var/www/maxek-erp}"
TS="$(date +%Y%m%d%H%M%S)"
TEMPLATE="${LIVE}/templates/boq_management.html"
APP_PY="${LIVE}/app.py"
STAGING="/tmp/maxek-boq-hotfix-${TS}"
BRANCH="${BRANCH:-cursor/boq-management-hotfix-f9eb}"
REPO="${REPO:-https://github.com/najranfarm-create/MAXEK-ERP-Construction.git}"

echo "==> MAXEK ERP — BOQ Management 500 hotfix"
echo "    Target: ${LIVE}"

if [[ ! -d "${LIVE}" ]]; then
  echo "ERROR: ${LIVE} not found"
  exit 1
fi

rm -rf "${STAGING}"
git clone --depth 1 --branch "${BRANCH}" "${REPO}" "${STAGING}" 2>/dev/null \
  || git clone --depth 1 "${REPO}" "${STAGING}"

PATCH_ROOT="${STAGING}/deploy/dpr-boq-ux-patch"

# 1) Template: point BOQ Library link at boq_legacy if boq_library route missing
if [[ -f "${TEMPLATE}" ]]; then
  cp -a "${TEMPLATE}" "${TEMPLATE}.bak-${TS}"
  if grep -q "url_for('boq_library')" "${TEMPLATE}"; then
    if grep -q "def boq_library" "${APP_PY}" 2>/dev/null; then
      install -m 0644 "${PATCH_ROOT}/templates/boq_management.html" "${TEMPLATE}"
      echo "==> Updated boq_management.html (boq_library route exists in app.py)"
    else
      sed -i "s/url_for('boq_library')/url_for('boq_legacy')/g" "${TEMPLATE}"
      echo "==> Patched template: boq_library -> boq_legacy (backup: boq_management.html.bak-${TS})"
    fi
  else
    echo "==> Template already patched"
  fi
fi

# 2) Optional: install boq_library route + document import guard from patch app.py snippet
if [[ -f "${PATCH_ROOT}/app.py" ]] && [[ -f "${APP_PY}" ]]; then
  if ! grep -q "def boq_library" "${APP_PY}"; then
    echo "==> WARN: app.py on VPS has no boq_library route."
    echo "    Template sed fix above is sufficient. To add the route, redeploy app.py from the hotfix branch."
  fi
fi

# 3) Ensure boq_management_service has _row_dict helper (sqlite3.Row safety)
SERVICE="${LIVE}/boq_management_service.py"
PATCH_SERVICE="${PATCH_ROOT}/boq_management_service.py"
if [[ -f "${SERVICE}" ]] && [[ -f "${PATCH_SERVICE}" ]]; then
  if ! grep -q "def _row_dict" "${SERVICE}"; then
    cp -a "${SERVICE}" "${SERVICE}.bak-${TS}"
    install -m 0644 "${PATCH_SERVICE}" "${SERVICE}"
    echo "==> Installed boq_management_service.py with _row_dict helper"
  fi
fi

systemctl restart maxek-erp.service
sleep 3

STATUS="$(systemctl is-active maxek-erp.service || true)"
echo "==> Service: ${STATUS}"

if [[ "${STATUS}" != "active" ]]; then
  journalctl -u maxek-erp.service -n 40 --no-pager
  exit 1
fi

HTTP_LOGIN="$(curl -s -o /dev/null -w '%{http_code}' 'http://127.0.0.1:8000/login' || echo 000)"
HTTP_BOQ="$(curl -s -o /dev/null -w '%{http_code}' 'http://127.0.0.1:8000/boq-management' || echo 000)"
echo "==> HTTP /login => ${HTTP_LOGIN}"
echo "==> HTTP /boq-management => ${HTTP_BOQ} (302 = redirect to login, expected without session)"
echo "==> Done. Sign in via browser, then open BOQ Management."
