#!/bin/bash
# pre_traffic_hook.sh — Runs on NEW instances BEFORE traffic shift

set -euo pipefail

LOG_FILE="/var/log/podinfo-pre-traffic.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "[$(date)] Starting pre-traffic hook..."

# 1. Ensure Docker is running
systemctl is-active --quiet docker || systemctl start docker

# 2. Pull the new image (in case userdata didn't)
# (Optional: skip if userdata already pulled it)
# docker pull "$IMAGE_URI"

# 3. Start podinfo container if not already running
if ! docker ps --format '{{.Names}}' | grep -q '^podinfo$'; then
  echo "Starting podinfo container..."
  docker run -d \
    --name podinfo \
    --restart unless-stopped \
    -p 9898:9898 \
    -e PORT=9898 \
    -e SUPER_SECRET_TOKEN_ARN="$SUPER_SECRET_TOKEN_ARN" \
    -e AWS_REGION="$AWS_REGION" \
    "$IMAGE_URI"
else
  echo "podinfo container already running."
fi

# 4. Wait for health check to pass (max 60s)
echo "Waiting for /healthz to become ready..."
for i in {1..12}; do
  if curl -sf http://localhost:9898/healthz; then
    echo "✅ Health check passed."
    exit 0
  fi
  sleep 5
done

echo "❌ Health check failed after 60 seconds."
exit 1