#!/bin/bash

# --- Configuration ---
RCON_HOST="127.0.0.1"
RCON_PORT="25575"
RCON_PASS="<YOUR_SECURE_PASSWORD>"
TIMESTAMP_FILE="/opt/minecraft/last_player.timestamp"
IDLE_MINUTES=5

# --- Helper Function for Logging ---
# This prepends a standard timestamp to every log message
log() {
    # Logs to stdout, which cron redirects to /var/log/minecraft_idle_check.log
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# --- Script ---
log "--- CheckIdle script started ---"

# Send the "/list" command via mcrcon and capture the output
log "Pinging RCON at $RCON_HOST:$RCON_PORT for player list..."
PLAYER_INFO=$(mcrcon -H $RCON_HOST -P $RCON_PORT -p $RCON_PASS "list")
RCON_STATUS=$? # Capture the exit code of the mcrcon command

# Check if the mcrcon command failed
if [ $RCON_STATUS -ne 0 ]; then
  log "ERROR: RCON command failed (Exit Code: $RCON_STATUS). Server might be offline or starting."
  log "Resetting idle timer to be safe..."
  touch $TIMESTAMP_FILE
  log "Timestamp file reset. Exiting."
  log "--- CheckIdle script finished ---"
  exit 0
fi

log "RCON Success. Raw output: $PLAYER_INFO"

# Extract just the player count
PLAYER_COUNT=$(echo "$PLAYER_INFO" | grep -oP 'There are \K[0-9]+' | head -n1)

# Handle cases where grep fails (e.g., unexpected RCON output)
if [ -z "$PLAYER_COUNT" ]; then
    log "WARNING: Could not parse player count from RCON output. Assuming 0 players to be safe."
    PLAYER_COUNT=0
fi

log "Parsed player count: $PLAYER_COUNT"

if [ "$PLAYER_COUNT" -gt 0 ]; then
  log "RESULT: Players are ONLINE. Resetting idle timer."
  touch $TIMESTAMP_FILE
else
  log "RESULT: Server is EMPTY. Checking idle timer..."

  # Find the timestamp file if it's older than IDLE_MINUTES
  # The -n flag checks if the output of 'find' is non-empty
  if [ -n "$(find "$TIMESTAMP_FILE" -mmin +$IDLE_MINUTES)" ]; then
    log "Idle time ($IDLE_MINUTES min) has EXPIRED. Initiating shutdown sequence."

    log "Sending 'stop' command to Minecraft server..."
    mcrcon -H $RCON_HOST -P $RCON_PORT -p $RCON_PASS "stop"

    log "Waiting 30 seconds for server to save..."
    sleep 30

    log "Shutting down the GCP instance NOW."
    /usr/sbin/shutdown -h now
  else
    log "Idle time has NOT expired. No action taken."
  fi
fi

log "--- CheckIdle script finished ---"
