#!/bin/bash
# smoke_tests.sh — Basic validation after code is installed

set -euo pipefail

LOG_FILE="/var/log/podinfo-smoke-tests.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "[$(date)] Running smoke tests..."

# Just confirm files are present (since BeforeInstall may not have run yet)
if [ ! -f /opt/podinfo-deploy/scripts/pre_traffic_hook.sh ]; then
  echo "❌ Deployment files missing!"
  exit 1
fi

echo "✅ Smoke tests passed: files deployed correctly."
exit 0