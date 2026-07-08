#!/usr/bin/env bash
# Hotfix: DPR white-on-white UI, header badge, Revised Estimate boq_units — no full app.py swap
set -euo pipefail

LIVE="${LIVE:-/var/www/maxek-erp}"
PATCH_DIR="${PATCH_DIR:-$(cd "$(dirname "$0")/dpr-boq-ux-patch" && pwd)}"
TS="$(date +%Y%m%d%H%M%S)"

echo "==> MAXEK ERP — DPR UI + Revised Estimate hotfix"
echo "    Live: ${LIVE}"
echo "    Patch: ${PATCH_DIR}"

FILES=(
  templates/dpr.html
  templates/revised_estimate.html
  static/css/maxek-dashboard.css
  static/js/dpr-forms.js
  static/js/maxek-ui.js
)

for f in "${FILES[@]}"; do
  src="${PATCH_DIR}/${f}"
  dst="${LIVE}/${f}"
  if [[ ! -f "${src}" ]]; then
    echo "WARN: missing patch file ${src}"
    continue
  fi
  if [[ -f "${dst}" ]]; then
    cp -a "${dst}" "${dst}.bak-${TS}"
  fi
  install -D -m 0644 "${src}" "${dst}"
  echo "  patched ${f}"
done

# Revised Estimate boq_units fallback (idempotent)
RE_TPL="${LIVE}/templates/revised_estimate.html"
if [[ -f "${RE_TPL}" ]] && ! grep -q "set boq_units = boq_units|default" "${RE_TPL}"; then
  sed -i "/{% set active_tab = active_tab|default('register') %}/a {% set boq_units = boq_units|default(['Nos', 'Sqm', 'Sqft', 'Rmt', 'Kg', 'MT', 'Ltr', 'Cum', 'Hour', 'Day', 'LS', 'Set', 'Bag']) %}" "${RE_TPL}"
  echo "  added boq_units default to revised_estimate.html"
fi

systemctl restart maxek-erp.service
sleep 3
STATUS="$(systemctl is-active maxek-erp.service || true)"
echo "==> Service: ${STATUS}"
if [[ "${STATUS}" != "active" ]]; then
  journalctl -u maxek-erp.service -n 25 --no-pager
  exit 1
fi

for path in /login /dpr_entry /revised-estimate; do
  code="$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:8000${path}" || echo 000)"
  echo "==> HTTP ${path} => ${code}"
done
echo "==> Hotfix complete — hard-refresh browser (Ctrl+Shift+R)"
