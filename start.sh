#!/bin/bash
set -e

if [ -z "$GITLAB_URL" ]; then
  echo 1>&2 "error: missing GITLAB_URL environment variable"
  exit 1
fi

if [ -z "$GITLAB_TOKEN_FILE" ]; then
  if [ -z "$GITLAB_TOKEN" ]; then
    echo 1>&2 "error: missing GITLAB_TOKEN environment variable"
    exit 1
  fi

  GITLAB_TOKEN_FILE=/runner/.token
  echo -n "$GITLAB_TOKEN" > "$GITLAB_TOKEN_FILE"
fi

unset GITLAB_TOKEN

export AGENT_ALLOW_RUNASROOT="1"

cleanup() {
  print_header "Cleanup. Unregistering GitLab Runner..."
  
  # Unregister the runner
  if [ -n "$RUNNER_TOKEN" ]; then
    gitlab-runner unregister --all-runners || true
  fi
}

print_header() {
  lightcyan='\033[1;36m'
  nocolor='\033[0m'
  echo -e "${lightcyan}$1${nocolor}"
}

print_header "1. Registering GitLab Runner..."

# Register the runner
gitlab-runner register \
  --non-interactive \
  --url "$GITLAB_URL" \
  --token $(cat "$GITLAB_TOKEN_FILE") \
  --executor "${RUNNER_EXECUTOR:-docker}" \
  --docker-image "${RUNNER_DOCKER_IMAGE:-alpine:latest}" \
  --description "${RUNNER_NAME:-$(hostname)}" \
  --tag-list "${RUNNER_TAGS:-docker,linux}" \
  --run-untagged="${RUNNER_RUN_UNTAGGED:-false}" \
  --locked="${RUNNER_LOCKED:-false}" \
  --access-level="${RUNNER_ACCESS_LEVEL:-not_protected}"

print_header "2. Running GitLab Runner..."

trap 'cleanup; exit 0' EXIT
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

# Run the runner
gitlab-runner run --user=runner --working-directory=/runner
