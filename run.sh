#!/bin/bash
set -e

# GitLab Self-Hosted Runner Script
# Reference: https://docs.gitlab.com/runner/

RUNNER_IMAGE="$1"
GITLAB_URL="$2"
GITLAB_TOKEN="$3"
RUNNER_TAGS="${4:-docker,linux}"
RUNNER_COUNT="${5}"

USAGE_HELP="Usage: $0 <RUNNER_IMAGE> <GITLAB_URL> <GITLAB_TOKEN> [RUNNER_TAGS] [RUNNER_COUNT]

Parameters:
  RUNNER_IMAGE    - Docker image name for GitLab runner
  GITLAB_URL      - GitLab instance URL
                    Examples:
                      - GitLab.com: https://gitlab.com
                      - Self-hosted: https://gitlab.example.com
  GITLAB_TOKEN    - GitLab runner registration token
                    Can be found in:
                      - Project: Settings > CI/CD > Runners
                      - Group: Settings > CI/CD > Runners
                      - Instance: Admin Area > CI/CD > Runners
  RUNNER_TAGS     - Comma-separated tags for runner (default: 'docker,linux')
  RUNNER_COUNT    - Number of runner instances (default: auto-detect from CPU count)

Example:
  $0 gitlab-runner:18.7.1 https://gitlab.com glrt-xxxxxxxxxxxx \"docker,linux,production\" 4
"

# Validate required parameters
if [ -z "$RUNNER_IMAGE" ]; then
  echo "Error: RUNNER_IMAGE is required"
  echo "$USAGE_HELP"
  exit 1
fi

if [ -z "$GITLAB_URL" ]; then
  echo "Error: GITLAB_URL is required"
  echo "$USAGE_HELP"
  exit 1
fi

if [ -z "$GITLAB_TOKEN" ]; then
  echo "Error: GITLAB_TOKEN is required"
  echo "$USAGE_HELP"
  exit 1
fi

# Validate GitLab URL format
if [[ ! "$GITLAB_URL" =~ ^https?://[^/]+/?$ ]]; then
  echo "Error: Invalid GITLAB_URL format. Must be https://gitlab.com or https://gitlab.example.com"
  exit 1
fi

# Get total CPU count from the system
CPU_COUNT=$(lscpu -p=CPU | grep -v "^#" | wc -l 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo "2")

# Set runner count (use provided value or default to CPU count)
RUNNER_COUNT=${RUNNER_COUNT:-$CPU_COUNT}

# Limit the number of vCPU count per runner to 2 when there are more than 1 vCPU available, cap it to 1 vCPU otherwise
MAX_CPU=$((CPU_COUNT > 1 ? 2 : 1))

# Get the Docker socket endpoint from current context
DOCKER_SOCK_ENDPOINT=$(docker context inspect 2>/dev/null | jq -r '.[]|.Endpoints.docker.Host' || echo "unix:///var/run/docker.sock")

# Extract socket path
DOCKER_SOCK_PATH=${DOCKER_SOCK_ENDPOINT#unix://}
DOCKER_SOCK_PATH=${DOCKER_SOCK_PATH:-/var/run/docker.sock}

echo "Starting $RUNNER_COUNT GitLab runner(s)..."
echo "Image: $RUNNER_IMAGE"
echo "GitLab URL: $GITLAB_URL"
echo "Tags: $RUNNER_TAGS"
echo "CPUs per runner: $MAX_CPU"
echo ""

# Launch runners
for R in $(seq 1 "$RUNNER_COUNT"); do
  RUNNER_NAME="gitlab-runner-$(hostname)-$R"
  CONFIG_DIR="/mnt/gitlab-runner${R}/config"
  DATA_DIR="/mnt/gitlab-runner${R}/data"
  CONTAINER_NAME="gitlab-runner-$R"
  
  # Create config and data directories
  sudo mkdir -p "$CONFIG_DIR"
  sudo mkdir -p "$DATA_DIR"
  
  echo "Starting runner $R/$RUNNER_COUNT: $RUNNER_NAME"
  
  # Check if container already exists
  if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "  Removing existing container: $CONTAINER_NAME"
    docker rm -f "$CONTAINER_NAME" > /dev/null 2>&1 || true
  fi
  
  # Run GitLab runner container
  # SECURITY NOTE: --privileged mode grants extended privileges to the container.
  # This is required for Docker-in-Docker but poses security risks.
  # Consider using rootless Docker or Docker socket mounting as alternatives.
  # If --privileged is not needed for your use case, remove this flag.
  docker run \
    --privileged \
    --tty \
    --detach \
    --cpus="${MAX_CPU}" \
    -e GITLAB_URL="$GITLAB_URL" \
    -e GITLAB_TOKEN="$GITLAB_TOKEN" \
    -e RUNNER_NAME="$RUNNER_NAME" \
    -e RUNNER_TAGS="$RUNNER_TAGS" \
    -e RUNNER_EXECUTOR="docker" \
    -e RUNNER_DOCKER_IMAGE="alpine:latest" \
    -e RUNNER_RUN_UNTAGGED="false" \
    -e RUNNER_LOCKED="false" \
    -e RUNNER_ACCESS_LEVEL="not_protected" \
    -v "$CONFIG_DIR":/etc/gitlab-runner \
    -v "$DATA_DIR":/runner \
    -v "$DOCKER_SOCK_PATH":/var/run/docker.sock \
    --restart unless-stopped \
    --name "$CONTAINER_NAME" \
    "$RUNNER_IMAGE"
  
  echo "  Container $CONTAINER_NAME started successfully"
done

echo ""
echo "All runners started successfully!"
echo ""
echo "To check runner status:"
echo "  docker ps --filter name=gitlab-runner"
echo ""
echo "To view runner logs:"
echo "  docker logs -f gitlab-runner-1"
echo ""
echo "To verify runner registration in GitLab:"
echo "  Go to your project/group/instance Settings > CI/CD > Runners"
echo ""
echo "To stop all runners:"
echo "  ./stop.sh"
