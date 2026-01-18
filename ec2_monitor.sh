#!/bin/bash
set -e

# AWS EC2 Spot Instance Termination Monitor
# Monitors EC2 spot instance termination notices
# Reference: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/spot-instance-termination-notices.html

METADATA_ENDPOINT='http://169.254.169.254/latest/meta-data/spot/instance-action'
STOP_SCRIPT='/opt/stop.sh'

echo "Checking for EC2 spot instance termination notice..."

# Query EC2 Instance Metadata Service for spot termination notice
# Returns HTTP 404 if no termination notice is present
RESPONSE=$(curl -sf "$METADATA_ENDPOINT" 2>/dev/null || echo "")

# Check if termination notice exists
if [ -n "$RESPONSE" ]; then
  echo "Spot instance termination notice detected!"
  echo "Termination details: $RESPONSE"
  
  # Parse termination time
  TERMINATION_TIME=$(echo "$RESPONSE" | jq -r '.time' 2>/dev/null || echo "Unknown")
  ACTION=$(echo "$RESPONSE" | jq -r '.action' 2>/dev/null || echo "terminate")
  
  echo "Action: $ACTION"
  echo "Termination time: $TERMINATION_TIME"
  echo "Initiating graceful shutdown..."
  
  # Start agent shutdown, if script exists and is executable
  if [ -x "$STOP_SCRIPT" ]; then
    echo "Executing stop script: $STOP_SCRIPT"
    "$STOP_SCRIPT"
  else
    echo "Warning: Stop script not found or not executable: $STOP_SCRIPT"
  fi
  
  echo "Agents shutdown complete. Instance will terminate at: $TERMINATION_TIME"
else
  echo "No spot instance termination notice"
fi

exit 0
