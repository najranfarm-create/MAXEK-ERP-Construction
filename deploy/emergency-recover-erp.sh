#!/usr/bin/env bash
# Emergency recovery — restore ERP after bad app.py deploy (502 / ModuleNotFoundError)
set -euo pipefail

LIVE="${LIVE:-/var/www/maxek-erp}"
PATCH_REPO="${PATCH_REPO:-https://raw.githubusercontent.com/najranfarm-create/MAXEK-ERP-Construction}"
ROLLBACK_BRANCH="${ROLLBACK_BRANCH:-cursor/dpr-revised-estimate-0620}"
ROLLBACK_APP="${PATCH_REPO}/${ROLLBACK_BRANCH}/deploy/dpr-revised-estimate-patch/app.py"
TS="$(date +%Y%m%d%H%M%S)"

echo "==> MAXEK ERP emergency recovery"
echo "    Live path: ${LIVE}"

if [[ ! -f "${LIVE}/app.py" ]]; then
  echo "ERROR: ${LIVE}/app.py not found"
  exit 1
fi

cd "${LIVE}"

# 1) Try git reflog if this is a git checkout
if [[ -d .git ]]; then
  echo "==> Checking git history for app.py..."
  git log --oneline -3 -- app.py 2>/dev/null || true
  PREV="$(git rev-list -n 1 HEAD -- app.py 2>/dev/null || true)"
  if [[ -n "${PREV}" ]]; then
    echo "    Latest commit touching app.py: ${PREV}"
  fi
fi

# 2) Backup broken app.py
cp -a "${LIVE}/app.py" "${LIVE}/app.py.broken-${TS}"
echo "==> Backed up broken app.py -> app.py.broken-${TS}"
wc -l "${LIVE}/app.py.broken-${TS}"

# 3) Roll back app.py to last known-good patch (no navigation_service / toc / project_completion imports)
echo "==> Downloading rollback app.py..."
curl -fsSL "${ROLLBACK_APP}" -o "${LIVE}/app.py.rollback-tmp"
wc -l "${LIVE}/app.py.rollback-tmp"
mv "${LIVE}/app.py.rollback-tmp" "${LIVE}/app.py"
echo "==> app.py rolled back"

# 4) Restore login if working backup exists
if [[ -f "${LIVE}/templates/login.html.working-20260707" ]]; then
  cp "${LIVE}/templates/login.html.working-20260707" "${LIVE}/templates/login.html"
  echo "==> login.html restored from working backup"
fi

# 5) Restart and verify
systemctl restart maxek-erp.service
sleep 4

STATUS="$(systemctl is-active maxek-erp.service || true)"
echo "==> Service status: ${STATUS}"

if [[ "${STATUS}" != "active" ]]; then
  echo "==> Still failing — last log lines:"
  journalctl -u maxek-erp.service -n 30 --no-pager || true
  echo ""
  echo "Try June backup if available:"
  echo "  tar -tzf /root/maxek-erp-backup-2026-06-29-1535.tar.gz | grep 'app.py'"
  exit 1
fi

HTTP="$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8000/login || echo 000)"
echo "==> HTTP /login => ${HTTP}"

if [[ "${HTTP}" == "200" || "${HTTP}" == "302" ]]; then
  echo "==> RECOVERY OK — site should load (refresh browser)"
else
  echo "WARN: Service active but HTTP=${HTTP} — check nginx / journalctl"
fi
