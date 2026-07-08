#!/usr/bin/env bash
# Apply UI + module patches on production VPS (no placeholder paths).
# Run on server as root:
#   bash /tmp/vps-apply-patch.sh
#
# Or one-liner (downloads script then runs):
#   git clone --depth 1 --branch cursor/project-completion-0620 \
#     https://github.com/najranfarm-create/MAXEK-ERP-Construction.git /tmp/maxek-patch \
#     && bash /tmp/maxek-patch/deploy/vps-apply-patch.sh
set -euo pipefail

LIVE="${LIVE:-/var/www/maxek-erp}"
BRANCH="${BRANCH:-cursor/project-completion-0620}"
REPO_URL="${REPO_URL:-https://github.com/najranfarm-create/MAXEK-ERP-Construction.git}"
STAGING="${STAGING:-/tmp/maxek-patch-$$}"
TS="$(date +%Y%m%d%H%M%S)"
MODE="${1:-ui}"  # ui | full | hotfix-re

echo "==> MAXEK ERP patch apply (mode: ${MODE})"
echo "    Live site: ${LIVE}"

if [[ ! -d "${LIVE}" ]]; then
  echo "ERROR: ${LIVE} not found"
  exit 1
fi

# Locate patch files: from cloned repo, or same directory as this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_ROOT="${SCRIPT_DIR}/dpr-boq-ux-patch"

if [[ ! -f "${PATCH_ROOT}/static/css/maxek-dashboard.css" ]]; then
  echo "==> Cloning patch repo to ${STAGING}"
  if [[ "${STAGING}" == "/tmp/maxek-patch" ]] && [[ -d "${STAGING}" ]]; then
    echo "    Removing stale ${STAGING}"
    rm -rf "${STAGING}"
  fi
  rm -rf "${STAGING}"
  if ! git clone --depth 1 --branch "${BRANCH}" "${REPO_URL}" "${STAGING}"; then
    echo "ERROR: git clone failed (rate limit?). Try again in a few minutes or copy files manually."
    exit 1
  fi
  PATCH_ROOT="${STAGING}/deploy/dpr-boq-ux-patch"
fi

if [[ ! -d "${PATCH_ROOT}" ]]; then
  echo "ERROR: patch folder not found: ${PATCH_ROOT}"
  exit 1
fi

echo "==> Using patch from: ${PATCH_ROOT}"

copy_file() {
  local rel="$1"
  local src="${PATCH_ROOT}/${rel}"
  local dst="${LIVE}/${rel}"
  if [[ ! -f "${src}" ]]; then
    echo "  SKIP (missing): ${rel}"
    return 0
  fi
  mkdir -p "$(dirname "${dst}")"
  if [[ -f "${dst}" ]]; then
    cp -a "${dst}" "${dst}.bak-${TS}"
  fi
  install -m 0644 "${src}" "${dst}"
  echo "  OK ${rel}"
}

UI_FILES=(
  static/css/maxek-dashboard.css
  static/js/maxek-ui.js
  static/js/dpr-forms.js
  static/js/accounts-expenses.js
  templates/base_maxek.html
  templates/dpr.html
  templates/revised_estimate.html
  templates/accounts_expenses.html
)

WORKFLOW_FILES=(
  app.py
)

FULL_FILES=(
  app.py
  navigation_service.py
  revised_estimate_service.py
  toc_extension_service.py
  project_completion_service.py
  templates/toc_extension.html
  templates/project_completion.html
  static/js/revised-estimate.js
  static/js/toc-extension.js
  static/js/project-completion.js
)

case "${MODE}" in
  ui)
    for f in "${UI_FILES[@]}"; do copy_file "${f}"; done
    ;;
  workflow)
    for f in "${UI_FILES[@]}" "${WORKFLOW_FILES[@]}"; do copy_file "${f}"; done
    ;;
  full)
    for f in "${UI_FILES[@]}" "${FULL_FILES[@]}"; do copy_file "${f}"; done
    mkdir -p "${LIVE}/uploads/project_completion"
    ;;
  hotfix-re)
    copy_file templates/revised_estimate.html
  ;;
  *)
    echo "Usage: $0 [ui|workflow|full|hotfix-re]"
    exit 1
    ;;
esac

# Revised Estimate boq_units safety (idempotent)
RE_TPL="${LIVE}/templates/revised_estimate.html"
if [[ -f "${RE_TPL}" ]] && ! grep -q "set boq_units = boq_units|default" "${RE_TPL}"; then
  sed -i "/{% set active_tab = active_tab|default('register') %}/a {% set boq_units = boq_units|default(['Nos', 'Sqm', 'Sqft', 'Rmt', 'Kg', 'MT', 'Ltr', 'Cum', 'Hour', 'Day', 'LS', 'Set', 'Bag']) %}" "${RE_TPL}"
  echo "  OK boq_units default in revised_estimate.html"
fi

if [[ -f "${LIVE}/templates/login.html.working-20260707" ]]; then
  cp "${LIVE}/templates/login.html.working-20260707" "${LIVE}/templates/login.html"
  echo "  OK login.html restored from working backup"
fi

echo "==> Restarting maxek-erp.service"
systemctl restart maxek-erp.service
sleep 4

STATUS="$(systemctl is-active maxek-erp.service || true)"
echo "==> Service: ${STATUS}"
if [[ "${STATUS}" != "active" ]]; then
  journalctl -u maxek-erp.service -n 30 --no-pager
  exit 1
fi

for path in /login /revised-estimate /toc-extension /project-completion /dpr_entry; do
  code="$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:8000${path}" 2>/dev/null || echo 000)"
  echo "==> HTTP ${path} => ${code}"
done

echo ""
echo "==> Done. Hard-refresh browser (Ctrl+Shift+R)."
echo "    Backups: *.bak-${TS} next to each patched file."
