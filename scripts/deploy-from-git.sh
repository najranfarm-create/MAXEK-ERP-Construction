#!/usr/bin/env bash
# Clone or update MAXEK ERP on a Linux server
# Usage: bash scripts/deploy-from-git.sh

set -euo pipefail

TARGET_DIR="${1:-/var/www/maxek-erp-flask}"
REPO_URL="https://github.com/najranfarm-create/MAXEK-ERP-Construction.git"
BRANCH="${2:-cursor/auth-setup-flask-0620}"

if [ -d "$TARGET_DIR/.git" ]; then
  echo "==> Updating existing repo in $TARGET_DIR"
  git -C "$TARGET_DIR" fetch origin
  git -C "$TARGET_DIR" checkout "$BRANCH"
  git -C "$TARGET_DIR" pull origin "$BRANCH"
else
  echo "==> Cloning into $TARGET_DIR"
  mkdir -p "$(dirname "$TARGET_DIR")"
  git clone --branch "$BRANCH" "$REPO_URL" "$TARGET_DIR"
fi

echo "==> Running setup"
bash "$TARGET_DIR/scripts/setup.sh"
