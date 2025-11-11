#!/bin/bash

# Minecraft Server Spot Instance Deployment Script
# This script sets up the file structure and user as expected by the helper scripts

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    log_error "Please run as root (use sudo)"
    exit 1
fi

log_info "Starting deployment of Minecraft Server Spot Instance helpers..."

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Create minecraft user and group ---
log_info "Creating minecraft user and group..."
if id "minecraft" &>/dev/null; then
    log_warn "User 'minecraft' already exists, skipping creation"
else
    useradd -r -s /bin/bash -d /opt/minecraft -m minecraft
    log_info "Created minecraft user"
fi

# --- Create directory structure ---
log_info "Creating directory structure..."
mkdir -p /opt/minecraft/scripts
mkdir -p /opt/minecraft/server-files
mkdir -p /var/log

# --- Copy scripts to their expected locations ---
log_info "Installing scripts..."
cp "$SCRIPT_DIR/check_idle.sh" /opt/minecraft/scripts/check_idle.sh
cp "$SCRIPT_DIR/mc-check.sh" /opt/minecraft/scripts/mc-check.sh

# Make scripts executable
chmod +x /opt/minecraft/scripts/check_idle.sh
chmod +x /opt/minecraft/scripts/mc-check.sh

# Set ownership
chown -R minecraft:minecraft /opt/minecraft

# --- Create log files ---
log_info "Creating log files..."
touch /var/log/minecraft_idle_check.log
touch /var/log/minecraft_watchdog.log
chmod 644 /var/log/minecraft_idle_check.log
chmod 644 /var/log/minecraft_watchdog.log

# --- Create timestamp file ---
log_info "Creating timestamp file..."
touch /opt/minecraft/last_player.timestamp
chown minecraft:minecraft /opt/minecraft/last_player.timestamp

# --- Install systemd services and timers ---
log_info "Installing systemd services and timers..."
cp "$SCRIPT_DIR/services/minecraft.service" /etc/systemd/system/
cp "$SCRIPT_DIR/services/mc-idle-check.service" /etc/systemd/system/
cp "$SCRIPT_DIR/services/mc-idle-check.timer" /etc/systemd/system/
cp "$SCRIPT_DIR/services/mc-watchdog.service" /etc/systemd/system/
cp "$SCRIPT_DIR/services/mc-watchdog.timer" /etc/systemd/system/

# Reload systemd
systemctl daemon-reload

log_info "Systemd services and timers installed"

# --- Check for mcrcon ---
log_info "Checking for mcrcon..."
if command -v mcrcon &> /dev/null; then
    log_info "mcrcon is already installed"
else
    log_warn "mcrcon is not installed. You need to install it for the idle check to work."
    log_warn "Installation options:"
    log_warn "  Debian/Ubuntu: apt-get install mcrcon"
    log_warn "  Or build from source: https://github.com/Tiiffi/mcrcon"
    log_warn ""
    log_warn "The deployment will continue, but idle checking will fail until mcrcon is installed."
fi

# --- Summary ---
log_info ""
log_info "=== Deployment Summary ==="
log_info "✓ User 'minecraft' created"
log_info "✓ Directory structure created:"
log_info "  - /opt/minecraft/scripts/"
log_info "  - /opt/minecraft/server-files/"
log_info "✓ Scripts installed:"
log_info "  - /opt/minecraft/scripts/check_idle.sh"
log_info "  - /opt/minecraft/scripts/mc-check.sh"
log_info "✓ Systemd services installed:"
log_info "  - minecraft.service"
log_info "  - mc-idle-check.service + timer"
log_info "  - mc-watchdog.service + timer"
log_info ""
log_warn "IMPORTANT: Before enabling services, ensure:"
log_warn "  1. mcrcon is installed (if not already)"
log_warn "  2. /opt/minecraft/server-files/run.sh exists and is executable"
log_warn "  3. RCON is configured in your server.properties"
log_warn "  4. Update RCON_PASS in /opt/minecraft/scripts/check_idle.sh"
log_warn ""
log_info "To enable and start services:"
log_info "  systemctl enable minecraft.service"
log_info "  systemctl enable mc-idle-check.timer"
log_info "  systemctl enable mc-watchdog.timer"
log_info "  systemctl start minecraft.service"
log_info "  systemctl start mc-idle-check.timer"
log_info "  systemctl start mc-watchdog.timer"
log_info ""
log_info "Deployment complete!"

