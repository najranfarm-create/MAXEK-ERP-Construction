#!/usr/bin/env bash
# One-shot VPS recovery: remove stale clone, re-apply UI patch, restart, verify.
# Run on server:
#   curl -fsSL "https://raw.githubusercontent.com/najranfarm-create/MAXEK-ERP-Construction/cursor/project-completion-0620/deploy/vps-recover-and-patch.sh" | bash
set -euo pipefail

LIVE="${LIVE:-/var/www/maxek-erp}"
BRANCH="cursor/project-completion-0620"
REPO="https://github.com/najranfarm-create/MAXEK-ERP-Construction.git"
STAGING="/tmp/maxek-patch"
PATCH="${STAGING}/deploy/dpr-boq-ux-patch"
TS="$(date +%Y%m%d%H%M%S)"

echo "==> MAXEK ERP recover + UI patch"
echo "    Live: ${LIVE}"

cd "${LIVE}"

# 1) If service down, try restore latest CSS/JS backups from bad curl
for f in static/css/maxek-dashboard.css static/js/maxek-ui.js templates/base_maxek.html; do
  if [[ -f "${f}" ]] && [[ "$(wc -c < "${f}")" -lt 500 ]]; then
    echo "WARN: ${f} looks too small — restoring from newest .bak"
    latest="$(ls -t "${f}".bak-* 2>/dev/null | head -1 || true)"
    if [[ -n "${latest}" ]]; then
      cp -a "${latest}" "${f}"
      echo "    restored from ${latest}"
    fi
  fi
done

# 2) Fresh clone (remove stale /tmp/maxek-patch)
echo "==> Fresh git clone"
rm -rf "${STAGING}"
if ! git clone --depth 1 --branch "${BRANCH}" "${REPO}" "${STAGING}"; then
  echo "ERROR: git clone failed."
  echo "Wait 5 min and retry, or use manual curl below."
  exit 1
fi

if [[ ! -f "${PATCH}/templates/base_maxek.html" ]]; then
  echo "ERROR: patch files missing in clone. Listing:"
  ls -la "${PATCH}/templates/" 2>/dev/null || ls -la "${STAGING}/deploy/" 2>/dev/null
  exit 1
fi

# 3) Copy UI files
echo "==> Copying patch files"

# Restore production settings.html if a UI patch backup exists (fixes /settings 500 after template overwrite)
SETTINGS_TPL="${LIVE}/templates/settings.html"
SETTINGS_BAK="$(ls -t "${SETTINGS_TPL}".bak-* 2>/dev/null | head -1 || true)"
if [[ -n "${SETTINGS_BAK}" ]]; then
  cp -a "${SETTINGS_BAK}" "${SETTINGS_TPL}"
  echo "  OK restored settings.html from backup"
fi

# Optional: restore production approvals.html when RESTORE_APPROVALS_TEMPLATE=1
APPROVALS_TPL="${LIVE}/templates/approvals.html"
APPROVALS_BAK="$(ls -t "${APPROVALS_TPL}".bak-* 2>/dev/null | head -1 || true)"
if [[ -n "${APPROVALS_BAK}" ]] && [[ "${RESTORE_APPROVALS_TEMPLATE:-0}" == "1" ]]; then
  cp -a "${APPROVALS_BAK}" "${APPROVALS_TPL}"
  echo "  OK restored approvals.html from backup"
fi

for f in \
  static/css/maxek-dashboard.css \
  static/css/maxek-pro-dashboard.css \
  static/js/maxek-ui.js \
  static/js/maxek-pro-dashboard.js \
  static/js/dpr-forms.js \
  templates/base_maxek.html \
  templates/dpr.html \
  templates/revised_estimate.html \
  templates/partials/header_utility_cluster.html \
  templates/partials/dashboard_shell_header.html \
  templates/partials/dashboard_shell_module_header.html \
  templates/partials/dashboard_shell_sidebar.html \
  templates/partials/shell_flash_and_title.html \
  templates/partials/attendance_module_tabs.html \
  templates/approvals.html \
  static/js/approvals-bulk.js \
  static/js/attendance-module-tabs.js
do
  src="${PATCH}/${f}"
  dst="${LIVE}/${f}"
  if [[ ! -f "${src}" ]]; then
    echo "  SKIP missing ${f}"
    continue
  fi
  if [[ -f "${dst}" ]]; then
    cp -a "${dst}" "${dst}.bak-${TS}"
  fi
  install -D -m 0644 "${src}" "${dst}"
  echo "  OK ${f} ($(wc -c < "${dst}") bytes)"
done

# 4) Revised Estimate boq_units safety
RE_TPL="${LIVE}/templates/revised_estimate.html"
if [[ -f "${RE_TPL}" ]] && ! grep -q "set boq_units = boq_units|default" "${RE_TPL}"; then
  sed -i "/{% set active_tab = active_tab|default('register') %}/a {% set boq_units = boq_units|default(['Nos', 'Sqm', 'Sqft', 'Rmt', 'Kg', 'MT', 'Ltr', 'Cum', 'Hour', 'Day', 'LS', 'Set', 'Bag']) %}" "${RE_TPL}"
  echo "  OK boq_units default added"
fi

if [[ -f "${LIVE}/templates/login.html.working-20260707" ]]; then
  cp "${LIVE}/templates/login.html.working-20260707" "${LIVE}/templates/login.html"
fi

if [[ -f "${STAGING}/deploy/inject-attendance-tabs.sh" ]]; then
  LIVE="${LIVE}" bash "${STAGING}/deploy/inject-attendance-tabs.sh"
fi

# 5) Restart + diagnose
echo "==> Restarting service"
systemctl restart maxek-erp.service
sleep 5

STATUS="$(systemctl is-active maxek-erp.service 2>/dev/null || echo failed)"
echo "==> Service status: ${STATUS}"

if [[ "${STATUS}" != "active" ]]; then
  echo "==> SERVICE FAILED — last log lines:"
  journalctl -u maxek-erp.service -n 40 --no-pager
  echo ""
  echo "If ModuleNotFoundError, run: bash ${STAGING}/deploy/emergency-recover-erp.sh"
  exit 1
fi

for path in /login /revised-estimate; do
  code="$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:8000${path}" 2>/dev/null || echo 000)"
  echo "==> HTTP ${path} => ${code}"
done

echo "==> Done. Hard-refresh browser (Ctrl+Shift+R)."
