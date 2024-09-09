#!/bin/bash

CPU_COUNT=$(lscpu -p=CPU | grep -v "^#" | wc -l)
MAX_CPU=$(($CPU_COUNT>1 ? 2 : 1))

# Get URL and PAT from first running instance:
eval $(sudo docker inspect agent1 | jq -r '. [] | . | .Config.Env[]' | grep "AZP_TOKEN\|AZP_URL")

# Graceful agent shutdown
for R in `seq 1 $MAX_CPU`; do
  sudo docker exec -ti \
    -e VSTS_AGENT_INPUT_AUTH="pat" \
    -e VSTS_AGENT_INPUT_URL="$AZP_URL" \
    -e VSTS_AGENT_INPUT_TOKEN="$AZP_TOKEN" \
    agent$R \
    ./config.sh remove --unattended \
  && sudo docker stop agent$R \
  && sudo docker rm agent$R &
done

wait

exit 0
