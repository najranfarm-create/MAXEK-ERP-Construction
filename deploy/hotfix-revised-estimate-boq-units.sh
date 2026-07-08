#!/usr/bin/env bash
# Hotfix: Revised Estimate 500 — boq_units Undefined in template JSON boot block
# Safe on rolled-back app.py (dpr-revised-estimate-patch). No GitHub required.
set -euo pipefail

LIVE="${LIVE:-/var/www/maxek-erp}"
TS="$(date +%Y%m%d%H%M%S)"
TEMPLATE="${LIVE}/templates/revised_estimate.html"

echo "==> MAXEK ERP — Revised Estimate boq_units hotfix"
echo "    Target: ${LIVE}"

if [[ ! -f "${TEMPLATE}" ]]; then
  echo "ERROR: ${TEMPLATE} not found"
  exit 1
fi

cp -a "${TEMPLATE}" "${TEMPLATE}.bak-${TS}"
echo "==> Backed up template -> revised_estimate.html.bak-${TS}"

# Idempotent: add default boq_units after active_tab default if missing
if grep -q "set boq_units = boq_units|default" "${TEMPLATE}"; then
  echo "==> Template already has boq_units default — skipping sed"
else
  sed -i "/{% set active_tab = active_tab|default('register') %}/a {% set boq_units = boq_units|default(['Nos', 'Sqm', 'Sqft', 'Rmt', 'Kg', 'MT', 'Ltr', 'Cum', 'Hour', 'Day', 'LS', 'Set', 'Bag']) %}" "${TEMPLATE}"
  echo "==> Added boq_units default to template"
fi

# Fallback: fix raw tojson line if template lacks block-level default
if grep -q "units: {{ boq_units|tojson }}" "${TEMPLATE}"; then
  sed -i 's/units: {{ boq_units|tojson }}/units: {{ (boq_units|default([]))|tojson }}/' "${TEMPLATE}"
  echo "==> Patched REVISED_ESTIMATE_BOOT units line"
fi

systemctl restart maxek-erp.service
sleep 3

STATUS="$(systemctl is-active maxek-erp.service || true)"
echo "==> Service: ${STATUS}"

if [[ "${STATUS}" != "active" ]]; then
  journalctl -u maxek-erp.service -n 20 --no-pager
  exit 1
fi

HTTP="$(curl -s -o /dev/null -w '%{http_code}' 'http://127.0.0.1:8000/revised-estimate' || echo 000)"
echo "==> HTTP /revised-estimate => ${HTTP}"
echo "==> Hotfix complete. Refresh Revised Estimate in browser."
