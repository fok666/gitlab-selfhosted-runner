#!/bin/bash

AZP_IMAGE="$1"
AZP_URL="$2"
AZP_TOKEN="$3"
AZP_POOL="$4"

USAGE_HELP="Usage: $0 <AZP_IMAGE> <AZP_URL> <AZP_TOKEN> <AZP_POOL>"

# Test if AZP_IMAGE is empty, exit with error if true
if [ -z "$AZP_IMAGE" ]; then
  echo $USAGE_HELP
  exit 1
fi

# Test if AZP_URL is empty, exit with error if true
if [ -z "$AZP_URL" ]; then
  echo $USAGE_HELP
  exit 1
fi

# Test if AZP_TOKEN is empty, exit with error if true
if [ -z "$AZP_TOKEN" ]; then
  echo $USAGE_HELP
  exit 1
fi

# Test if AZP_POOL is empty, exit with error if true
if [ -z "$AZP_POOL" ]; then
  echo $USAGE_HELP
  exit 1
fi

# Get total CPU count from the system
CPU_COUNT=$(lscpu -p=CPU | grep -v "^#" | wc -l)
# Limit the number of vCPU count per agent to 2 when there are more than 1 vCPU is available, cap it to 1 vCPU otherwise
MAX_CPU=$(($CPU_COUNT>1 ? 2 : 1))
# Get the Docker socket endpoint from current context
DOCKER_SOCK_ENDPOINT=$(docker context inspect | jq -r '.[]|.Endpoints.docker.Host')

for R in `seq 1 $CPU_COUNT`; do
  sudo mkdir -p /mnt/agent${R}/w
  sudo docker run \
  --privileged \
  --tty \
  --detach \
  --cpus="${MAX_CPU}" \
  -e AZP_URL="$AZP_URL" \
  -e AZP_TOKEN="$AZP_TOKEN" \
  -e AZP_POOL="$AZP_POOL" \
  -e AZP_AGENT_NAME=sha-`hostname`-$R \
  -v ${DOCKER_SOCK_ENDPOINT#unix://*}:/var/run/docker.sock \
  -v /mnt/agent${R}/w:/_work \
  --restart always \
  --name agent$R \
  $AZP_IMAGE
done
