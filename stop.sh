#!/bin/bash
set -e

# GitLab Runner Stop Script
# Gracefully stops and removes all GitLab runner containers

echo "Stopping GitLab runners..."
echo ""

# Get list of running runner containers
RUNNER_CONTAINERS=$(docker ps --filter "name=gitlab-runner-" --format "{{.Names}}" | sort)

if [ -z "$RUNNER_CONTAINERS" ]; then
  echo "No running GitLab runner containers found."
  exit 0
fi

CONTAINER_COUNT=$(echo "$RUNNER_CONTAINERS" | wc -l | tr -d ' ')
echo "Found $CONTAINER_COUNT runner container(s)"
echo ""

# Stop each runner gracefully
for CONTAINER_NAME in $RUNNER_CONTAINERS; do
  echo "Stopping $CONTAINER_NAME..."
  
  # Try graceful shutdown first (runner will unregister itself via start.sh cleanup)
  docker stop -t 30 "$CONTAINER_NAME" > /dev/null 2>&1 || true
  
  # Remove the container
  docker rm "$CONTAINER_NAME" > /dev/null 2>&1 || true
  
  echo "  $CONTAINER_NAME stopped and removed"
done

echo ""
echo "All GitLab runners stopped successfully!"
exit 0
