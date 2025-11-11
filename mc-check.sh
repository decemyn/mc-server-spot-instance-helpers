#!/bin/bash
SERVICE_NAME="minecraft.service"
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [WATCHDOG] $1"
}
log "--- Periodic Service Watchdog Started ---"
SERVICE_STATUS=$(systemctl is-active "$SERVICE_NAME")
if [ "$SERVICE_STATUS" = "active" ]; then
    log "INFO: Service '$SERVICE_NAME' is active. All clear."
else
    log "FATAL: Service '$SERVICE_NAME' is NOT active (status: $SERVICE_STATUS)."
    log "ACTION: Service has crashed. Initiating VM shutdown."
    systemctl status "$SERVICE_NAME" >> /var/log/minecraft_watchdog.log 2>&1
    /usr/sbin/shutdown -h now
fi
log "--- Periodic Service Watchdog Finished ---"

