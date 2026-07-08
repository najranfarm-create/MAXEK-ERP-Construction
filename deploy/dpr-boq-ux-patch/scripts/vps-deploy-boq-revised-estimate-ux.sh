#!/usr/bin/env bash
# Deploy BOQ + Revised Estimate + DPR + Project Completion UX to live VPS.
set -euo pipefail

REPO_DIR="${REPO_DIR:-/var/www/maxek-erp}"
BACKUP_TAG="erp-ux-$(date +%Y%m%d%H%M%S)"
BRANCH="${BRANCH:-cursor/project-completion-0620}"
PATCH_REPO="${PATCH_REPO:-https://github.com/najranfarm-create/MAXEK-ERP-Construction}"

echo "==> MAXEK ERP — BOQ / Revised Estimate / DPR / Project Completion deploy"
echo "    Target: ${REPO_DIR}"
echo "    Branch: ${BRANCH}"

if [[ ! -d "${REPO_DIR}/.git" ]]; then
  echo "ERROR: ${REPO_DIR} is not a git repo. Set REPO_DIR to /var/www/maxek-erp"
  exit 1
fi

STAGING="/tmp/maxek-erp-ux-patch"
rm -rf "${STAGING}"
git clone --depth 1 --branch "${BRANCH}" "${PATCH_REPO}" "${STAGING}"

cd "${REPO_DIR}"
git stash push -m "pre-${BACKUP_TAG}" 2>/dev/null || true

PATCH_ROOT="${STAGING}/deploy/dpr-boq-ux-patch"
if [[ ! -d "${PATCH_ROOT}" ]]; then
  PATCH_ROOT="${STAGING}"
fi

FILES=(
  app.py
  boq_management_service.py
  boq_management_routes.py
  revised_estimate_service.py
  project_completion_service.py
  toc_extension_service.py
  templates/boq_management.html
  templates/revised_estimate.html
  templates/toc_extension.html
  templates/dpr.html
  templates/project_completion.html
  static/js/boq-management.js
  static/js/revised-estimate.js
  static/js/dpr-forms.js
  static/js/project-completion.js
  static/js/maxek-ui.js
  static/css/maxek-dashboard.css
)

for f in "${FILES[@]}"; do
  if [[ -f "${PATCH_ROOT}/${f}" ]]; then
    install -D -m 0644 "${PATCH_ROOT}/${f}" "${REPO_DIR}/${f}"
    echo "  patched ${f}"
  else
    echo "  WARN: missing ${f} in patch"
  fi
done

if [[ -f "${REPO_DIR}/templates/login.html.working-20260707" ]]; then
  cp "${REPO_DIR}/templates/login.html.working-20260707" "${REPO_DIR}/templates/login.html"
  echo "  restored login.html from working backup"
fi

mkdir -p "${REPO_DIR}/uploads/project_completion"
systemctl restart maxek-erp.service
echo "==> Deploy complete. Service restarted."
