#!/usr/bin/env bash
# Check if /var/www/maxek-erp was overwritten or reverted to old version
set -euo pipefail

APP="/var/www/maxek-erp"

echo "=== MAXEK ERP version / integrity check ==="
echo ""

echo "--- Service points to ---"
systemctl show maxek-erp.service -p WorkingDirectory -p ExecStart --no-pager
echo ""

echo "--- App directory dates ---"
ls -la "$APP" | head -20
echo ""

echo "--- Key file sizes (detect overwrite) ---"
for f in app.py wsgi.py run.py; do
  [ -f "$APP/$f" ] && ls -la "$APP/$f" || echo "MISSING $f"
done
echo ""

echo "--- Git status (if repo) ---"
if [ -d "$APP/.git" ]; then
  git -C "$APP" log --oneline -3 2>/dev/null || true
  git -C "$APP" status -s 2>/dev/null | head -10 || true
  echo "WARNING: live ERP has .git — may have been cloned over"
else
  echo "No .git in live ERP (normal for production)"
fi
echo ""

echo "--- Templates ---"
ls -la "$APP/templates/" 2>/dev/null | head -15
echo ""

echo "--- Dashboard templates? ---"
find "$APP/templates" -name '*dashboard*' -o -name '*index*' 2>/dev/null | head -10
echo ""

echo "--- login.html backups (restore point) ---"
ls -lt "$APP/templates/login.html.bak"* 2>/dev/null | head -8 || echo "no backups"
echo ""

echo "--- Database ---"
find "$APP" -name '*.db' -ls 2>/dev/null | head -5
echo ""

echo "--- WRONG app folder? ---"
ls -la /var/www/maxek-erp-flask 2>/dev/null | head -5 || echo "maxek-erp-flask absent (good)"
