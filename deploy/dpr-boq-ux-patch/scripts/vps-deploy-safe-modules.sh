#!/usr/bin/env bash
# Safe deploy: Revised Estimate + TOC Extension + Project Completion
# Uses app.py with optional navigation_service (won't crash if missing).
set -euo pipefail

REPO_DIR="${REPO_DIR:-/var/www/maxek-erp}"
BRANCH="${BRANCH:-cursor/project-completion-0620}"
PATCH_REPO="${PATCH_REPO:-https://github.com/najranfarm-create/MAXEK-ERP-Construction}"
TS="$(date +%Y%m%d%H%M%S)"

echo "==> MAXEK ERP — Safe module deploy (Revised Estimate / TOC / Completion)"
echo "    Target: ${REPO_DIR}"
echo "    Branch: ${BRANCH}"

if [[ ! -d "${REPO_DIR}" ]]; then
  echo "ERROR: ${REPO_DIR} not found"
  exit 1
fi

STAGING="/tmp/maxek-safe-modules-patch"
rm -rf "${STAGING}"
git clone --depth 1 --branch "${BRANCH}" "${PATCH_REPO}" "${STAGING}"

PATCH_ROOT="${STAGING}/deploy/dpr-boq-ux-patch"
if [[ ! -d "${PATCH_ROOT}" ]]; then
  PATCH_ROOT="${STAGING}"
fi

cd "${REPO_DIR}"
if [[ -f app.py ]]; then
  cp -a app.py "app.py.bak-${TS}"
  echo "==> Backed up app.py -> app.py.bak-${TS}"
fi

FILES=(
  app.py
  navigation_service.py
  revised_estimate_service.py
  toc_extension_service.py
  project_completion_service.py
  boq_management_service.py
  boq_management_routes.py
  templates/dpr.html
  templates/revised_estimate.html
  templates/toc_extension.html
  templates/project_completion.html
  static/css/maxek-dashboard.css
  static/js/revised-estimate.js
  static/js/toc-extension.js
  static/js/project-completion.js
  static/js/dpr-forms.js
  static/js/maxek-ui.js
)

for f in "${FILES[@]}"; do
  if [[ -f "${PATCH_ROOT}/${f}" ]]; then
    install -D -m 0644 "${PATCH_ROOT}/${f}" "${REPO_DIR}/${f}"
    echo "  patched ${f}"
  else
    echo "  WARN: missing ${f}"
  fi
done

mkdir -p "${REPO_DIR}/uploads/project_completion"
if [[ -f "${REPO_DIR}/templates/login.html.working-20260707" ]]; then
  cp "${REPO_DIR}/templates/login.html.working-20260707" "${REPO_DIR}/templates/login.html"
fi

python3 -m py_compile "${REPO_DIR}/app.py" \
  "${REPO_DIR}/revised_estimate_service.py" \
  "${REPO_DIR}/toc_extension_service.py" \
  "${REPO_DIR}/project_completion_service.py"

systemctl restart maxek-erp.service
sleep 4
STATUS="$(systemctl is-active maxek-erp.service || true)"
echo "==> Service: ${STATUS}"
if [[ "${STATUS}" != "active" ]]; then
  journalctl -u maxek-erp.service -n 25 --no-pager
  exit 1
fi
HTTP="$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8000/login || echo 000)"
echo "==> HTTP /login => ${HTTP}"
echo "==> Deploy complete. Test:"
echo "    /revised-estimate"
echo "    /toc-extension"
echo "    /project-completion"
