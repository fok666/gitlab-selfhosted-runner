#!/bin/bash
set -e

# Azure VMSS Scheduled Events Monitor
# Monitors Azure VM Scale Set scheduled events for termination signals
# Reference: https://learn.microsoft.com/en-us/azure/virtual-machines/linux/scheduled-events

METADATA_ENDPOINT='http://169.254.169.254/metadata/scheduledevents?api-version=2020-07-01'
EVENTS_FILE='/tmp/scheduledevents.json'
STOP_SCRIPT='/opt/stop.sh'

echo "Checking for VMSS scheduled events..."

# Query Azure Instance Metadata Service for scheduled events
curl -sf "$METADATA_ENDPOINT" -H 'Metadata: true' > "$EVENTS_FILE"

# Check if termination event is scheduled
if grep -q "Terminate" "$EVENTS_FILE"; then
  echo "Terminate event detected! Initiating graceful shutdown..."
  
  # Start agent shutdown, if script exists and is executable
  if [ -x "$STOP_SCRIPT" ]; then
    echo "Executing stop script: $STOP_SCRIPT"
    "$STOP_SCRIPT"
  else
    echo "Warning: Stop script not found or not executable: $STOP_SCRIPT"
  fi

  # Acknowledge the event to Azure
  EventId=$(jq -r '.Events[] | select(.EventType == "Terminate") | .EventId' "$EVENTS_FILE")
  if [ -n "$EventId" ]; then
    echo "Acknowledging event: $EventId"
    # Use jq to safely construct JSON payload to handle special characters
    JSON_PAYLOAD=$(jq -n --arg eventId "$EventId" '{"StartRequests": [{"EventId": $eventId}]}')
    curl -sf -X POST "$METADATA_ENDPOINT" \
      -H 'Metadata: true' \
      -H 'Content-Type: application/json' \
      -d "$JSON_PAYLOAD"
    echo "Event acknowledged successfully"
  fi
else
  echo "No termination events scheduled"
fi

exit 0
