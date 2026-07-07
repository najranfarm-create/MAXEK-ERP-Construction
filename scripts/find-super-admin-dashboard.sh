#!/usr/bin/env bash
# Find super-admin dashboard template (old vs new layout)
set -euo pipefail
APP="/var/www/maxek-erp"

echo "=== Super Admin Dashboard files ==="
grep -n -i "super.admin\|super_admin\|/super-admin" "$APP/app.py" 2>/dev/null | head -20
echo ""

echo "--- Templates matching super / dashboard / platform ---"
find "$APP/templates" -iname '*super*' -o -iname '*platform*dashboard*' -o -iname '*department*' 2>/dev/null | head -20
ls -la "$APP/templates"/super* "$APP/templates"/platform* 2>/dev/null || true
echo ""

echo "--- Route dashboard render_template ---"
grep -n -i "render_template.*dashboard\|super.admin.dashboard" "$APP/app.py" 2>/dev/null | head -15
echo ""

echo "--- File dates (newest dashboard-related) ---"
find "$APP/templates" \( -iname '*dashboard*' -o -iname '*super*' -o -iname '*base_maxek*' \) -printf '%TY-%Tm-%Td %TH:%TM %s %p\n' 2>/dev/null | sort -r | head -15
echo ""

echo "--- Backups with super-admin template ---"
for tar in /root/maxek-erp-backup-*.tar.gz /var/www/backups/*.tar.gz; do
  [ -f "$tar" ] || continue
  echo "== $tar"
  tar -tzf "$tar" 2>/dev/null | grep -iE 'super.*dashboard|platform.*dashboard|base_maxek' | head -5
done
