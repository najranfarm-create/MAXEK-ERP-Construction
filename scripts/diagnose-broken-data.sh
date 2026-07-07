#!/usr/bin/env bash
# Diagnose broken/missing ERP data after deploy — NO code changes
set -euo pipefail
APP="/var/www/maxek-erp"

echo "=== MAXEK ERP data diagnostic ==="
echo ""

echo "--- .env database setting ---"
grep -iE 'DATABASE|SQLITE|DB_' "$APP/.env" 2>/dev/null || echo "No .env or no DATABASE line"
echo ""

echo "--- All .db files (size + date) ---"
find "$APP" -name '*.db' -printf '%TY-%Tm-%Td %TH:%TM %10s %p\n' 2>/dev/null | sort -r
echo ""

echo "--- instance/ folder ---"
ls -la "$APP/instance/" 2>/dev/null || echo "no instance/"
echo ""

echo "--- Recent rsync may have copied empty dev DB ---"
for db in "$APP"/*.db "$APP/instance"/*.db; do
  [ -f "$db" ] || continue
  echo "File: $db"
  sqlite3 "$db" "SELECT name FROM sqlite_master WHERE type='table' LIMIT 5;" 2>/dev/null || echo "  (not sqlite or locked)"
  sqlite3 "$db" "SELECT COUNT(*) AS users FROM users;" 2>/dev/null || true
  sqlite3 "$db" "SELECT COUNT(*) AS companies FROM companies;" 2>/dev/null || true
done
echo ""

echo "--- Backups with database ---"
ls -la /root/*maxek*.tar.gz /var/www/backups/*.tar.gz 2>/dev/null | head -5
echo ""

echo "If live .db is small/empty, restore DB from backup ONLY (do not touch code):" 
echo "  sudo cp /var/www/maxek-erp/instance/maxek_erp.db /var/www/maxek-erp/instance/maxek_erp.db.bak"
echo "  # extract .db from tar backup, then restart service"
