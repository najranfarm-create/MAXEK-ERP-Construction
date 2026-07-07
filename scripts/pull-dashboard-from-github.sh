#!/usr/bin/env bash
# Safely pull dashboard templates from GitHub — does NOT overwrite full live ERP
#
# Usage:
#   GITHUB_BRANCH=main bash scripts/pull-dashboard-from-github.sh
#   GITHUB_BRANCH=your-dashboard-branch bash scripts/pull-dashboard-from-github.sh
#
# NEVER: git clone into /var/www/maxek-erp (overwrites 23k-line app.py)

set -euo pipefail

REPO="https://github.com/najranfarm-create/MAXEK-ERP-Construction.git"
BRANCH="${GITHUB_BRANCH:-main}"
LIVE="/var/www/maxek-erp"
TMP="/tmp/maxek-github-pull"

echo "=== Pull dashboard files from GitHub (safe) ==="
echo "Branch: $BRANCH"
echo "Live ERP: $LIVE (app.py will NOT be replaced)"
echo ""

rm -rf "$TMP"
git clone --depth 1 --branch "$BRANCH" "$REPO" "$TMP" 2>&1 || {
  echo "ERROR: clone failed. Check branch name exists on GitHub."
  exit 1
}

echo "--- GitHub repo contents ---"
wc -l "$TMP/app.py" 2>/dev/null || echo "No app.py on GitHub (stub repo)"
ls "$TMP/templates" 2>/dev/null | head -10 || echo "No templates/ on GitHub"
echo ""

if [ -f "$TMP/app.py" ] && [ "$(wc -l < "$TMP/app.py")" -lt 1000 ]; then
  echo "WARNING: GitHub app.py is small ($(wc -l < "$TMP/app.py") lines)."
  echo "This is NOT your full ERP. Copy TEMPLATES ONLY, not app.py."
fi

# Copy only dashboard-related templates if they exist
mkdir -p "$LIVE/templates"
COPIED=0
for pattern in super platform dashboard base_maxek; do
  for f in "$TMP/templates"/*${pattern}*; do
    [ -f "$f" ] || continue
    base=$(basename "$f")
    cp -a "$LIVE/templates/$base" "$LIVE/templates/$base.bak.github.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
    cp -a "$f" "$LIVE/templates/$base"
    echo "Copied: templates/$base"
    COPIED=$((COPIED + 1))
  done
done

if [ "$COPIED" -eq 0 ]; then
  echo ""
  echo "No dashboard templates found on GitHub branch '$BRANCH'."
  echo "Push your corrected ERP templates to GitHub first, then re-run."
  echo ""
  echo "On your dev PC:"
  echo "  git add templates/super_admin_dashboard.html  # your file names"
  echo "  git commit -m 'feat: updated platform dashboard layout'"
  echo "  git push origin main"
  exit 1
fi

# Keep working login.html
if [ -f "$LIVE/templates/login.html.working-20260707" ]; then
  echo "Keeping login.html.working-20260707 (do not overwrite login)"
fi

systemctl restart maxek-erp.service
echo ""
echo "Done. Copied $COPIED file(s). Hard-refresh browser: Ctrl+Shift+R"
