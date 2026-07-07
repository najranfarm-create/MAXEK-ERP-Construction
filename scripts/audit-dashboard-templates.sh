#!/usr/bin/env bash
# Find dashboard / project-tab templates and compare with backups
set -euo pipefail

APP="/var/www/maxek-erp"
echo "=== Dashboard / navigation file audit ==="
echo ""

echo "--- Recently modified templates (last 14 days) ---"
find "$APP/templates" -name '*.html' -mtime -14 -printf '%TY-%Tm-%Td %TH:%TM %p\n' 2>/dev/null | sort -r | head -25
echo ""

echo "--- Dashboard / base / nav templates ---"
ls -la "$APP/templates"/{base_maxek.html,base.html,dashboard*.html,index.html,accounts_hub.html,project*.html} 2>/dev/null || true
find "$APP/templates" -iname '*dashboard*' -o -iname '*project*hub*' -o -iname '*main*' 2>/dev/null | head -20
echo ""

echo "--- Search: project tab / department / boq in templates ---"
grep -rl -i 'project.*tab\|department\|boq\|costing' "$APP/templates" 2>/dev/null | head -15
echo ""

echo "--- Search in app.py (menu/nav routes) ---"
grep -n -i 'dashboard\|department\|project.*tab\|boq\|main.*tab\|nav' "$APP/app.py" 2>/dev/null | head -25
echo ""

echo "--- Static JS for tabs/nav ---"
find "$APP/static" -name '*.js' -printf '%TY-%Tm-%Td %p\n' 2>/dev/null | sort -r | head -15
grep -rl -i 'project.*tab\|department\|dashboard' "$APP/static" 2>/dev/null | head -10
echo ""

echo "--- Available backups ---"
ls -la /var/www/backups/*.tar.gz /root/maxek*.tar.gz /root/maxek-backups/*.tar.gz 2>/dev/null
echo ""

echo "--- login.html backups (we only changed this) ---"
ls -lt "$APP/templates/login.html.bak"* 2>/dev/null | head -5
echo ""

echo "NEXT: If base_maxek.html or dashboard template date is OLD, extract newer copy from tar:"
echo "  tar -tzf /root/maxek-erp-backup-2026-06-29-1535.tar.gz | grep -i 'base_maxek\|dashboard'"
