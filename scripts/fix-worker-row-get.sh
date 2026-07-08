#!/usr/bin/env bash
# Fix AttributeError: sqlite3.Row has no attribute 'get' in worker_master_service.py
# Delegates to deploy/hotfix-worker-master-sqlite-row.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "${SCRIPT_DIR}/../deploy/hotfix-worker-master-sqlite-row.sh"
