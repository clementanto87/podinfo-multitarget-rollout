#!/bin/bash
# post_traffic_hook.sh — Runs on NEW instances AFTER traffic shift

set -euo pipefail

LOG_FILE="/var/log/podinfo-post-traffic.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "[$(date)] Starting post-traffic hook..."

# 1. Run deeper validation (e.g., metrics endpoint)
echo "Checking /metrics endpoint..."
if ! curl -sf http://localhost:9898/metrics > /dev/null; then
  echo "❌ /metrics endpoint failed."
  exit 1
fi

# 2. Optional: Send custom metric to CloudWatch
# aws cloudwatch put-metric-data \
#   --namespace "Podinfo/Deployments" \
#   --metric-name "PostTrafficSuccess" \
#   --value 1 \
#   --region "$AWS_REGION"

echo "✅ Post-traffic validation succeeded."
exit 0