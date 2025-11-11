# Minecraft Server Spot Instance Helpers

A collection of scripts and systemd services for running a Minecraft server on cloud spot/preemptible instances with automatic shutdown when idle or when the server crashes.

## Overview

This project provides automation for running Minecraft servers on cost-effective spot/preemptible cloud instances. Spot instances are significantly cheaper than regular instances but can be terminated by the cloud provider at any time. These scripts ensure your server shuts down gracefully when idle, saving costs while maintaining a good player experience.

## Why These Scripts Are Needed

### The Problem with Spot Instances

1. **Cost Savings**: Spot instances can be 60-90% cheaper than regular instances, making them ideal for game servers that don't need 24/7 uptime.

2. **Automatic Shutdown**: When no players are online, there's no reason to keep the server running and incurring costs. These scripts automatically detect idle periods and shut down the instance.

3. **Crash Detection**: If the Minecraft server crashes, the instance should shut down rather than sit idle consuming resources.

4. **Graceful Shutdown**: The scripts ensure the server saves properly before shutting down the instance.

### What These Scripts Do

This project consists of three main components:

1. **Idle Detection** (`check_idle.sh`): Monitors player count via RCON and shuts down the instance after a configurable idle period (default: 5 minutes).

2. **Service Watchdog** (`mc-check.sh`): Monitors the Minecraft systemd service and shuts down the instance if the service crashes or stops unexpectedly.

3. **Systemd Integration**: Services and timers that run these checks automatically every minute.

## Components

### Scripts

#### `check_idle.sh`
- **Purpose**: Checks if the Minecraft server has any players online
- **How it works**:
  1. Connects to the server via RCON and queries the player list
  2. If players are online, resets the idle timer
  3. If no players are online, checks if the idle time has exceeded the threshold
  4. If idle time exceeded, sends a stop command to the server, waits for it to save, then shuts down the instance
- **Configuration**: Edit the variables at the top of the script:
  - `RCON_HOST`: RCON host (default: 127.0.0.1)
  - `RCON_PORT`: RCON port (default: 25575)
  - `RCON_PASS`: RCON password (⚠️ **CHANGE THIS**)
  - `IDLE_MINUTES`: Minutes of idle time before shutdown (default: 5)

#### `mc-check.sh`
- **Purpose**: Monitors the Minecraft systemd service health
- **How it works**:
  1. Checks if `minecraft.service` is active
  2. If the service is not active, logs the status and shuts down the instance
  3. This prevents the instance from running idle if the server crashes
- **Configuration**: None required (uses `minecraft.service` by default)

### Systemd Services

#### `minecraft.service`
- **Purpose**: Main Minecraft server service
- **User**: Runs as `minecraft` user
- **Working Directory**: `/opt/minecraft/server-files`
- **Startup**: Executes `/opt/minecraft/server-files/run.sh`
- **Behavior**: 
  - Resets the idle timer on startup
  - Restarts on failure (with limits to prevent restart loops)

#### `mc-idle-check.service` + `mc-idle-check.timer`
- **Purpose**: Runs the idle check script periodically
- **Frequency**: Every minute
- **User**: Runs as root (needed for shutdown command)

#### `mc-watchdog.service` + `mc-watchdog.timer`
- **Purpose**: Runs the service watchdog script periodically
- **Frequency**: Every minute
- **User**: Runs as root (needed for shutdown command)

## File Structure

After deployment, the following structure is created:

```
/opt/minecraft/
├── scripts/
│   ├── check_idle.sh      # Idle detection script
│   └── mc-check.sh         # Service watchdog script
├── server-files/
│   └── run.sh              # Your Minecraft server startup script (you provide this)
└── last_player.timestamp   # Tracks when players were last online

/var/log/
├── minecraft_idle_check.log    # Idle check logs
└── minecraft_watchdog.log      # Watchdog logs

/etc/systemd/system/
├── minecraft.service
├── mc-idle-check.service
├── mc-idle-check.timer
├── mc-watchdog.service
└── mc-watchdog.timer
```

## Prerequisites

- Linux system with systemd
- `mcrcon` - RCON client tool for communicating with the Minecraft server
- Minecraft server with RCON enabled
- Root/sudo access for deployment

## Installation

1. **Clone or download this repository**:
   ```bash
   git clone <repository-url>
   cd minecraft-server-spot-instance-helpers
   ```

2. **Run the deployment script**:
   ```bash
   sudo ./deploy.sh
   ```

3. **Install mcrcon** (if not already installed):
   ```bash
   # Debian/Ubuntu
   sudo apt-get install mcrcon
   
   # Or build from source: https://github.com/Tiiffi/mcrcon
   ```

4. **Configure RCON in your Minecraft server**:
   Edit `server.properties`:
   ```properties
   enable-rcon=true
   rcon.port=25575
   rcon.password=YOUR_SECURE_PASSWORD
   ```

5. **Update the RCON password in the idle check script**:
   ```bash
   sudo nano /opt/minecraft/scripts/check_idle.sh
   # Update RCON_PASS variable
   ```

6. **Create your server startup script**:
   Create `/opt/minecraft/server-files/run.sh` that starts your Minecraft server:
   ```bash
   #!/bin/bash
   java -Xmx4G -Xms4G -jar server.jar nogui
   ```
   Make it executable:
   ```bash
   sudo chmod +x /opt/minecraft/server-files/run.sh
   sudo chown minecraft:minecraft /opt/minecraft/server-files/run.sh
   ```

7. **Enable and start the services**:
   ```bash
   sudo systemctl enable minecraft.service
   sudo systemctl enable mc-idle-check.timer
   sudo systemctl enable mc-watchdog.timer
   
   sudo systemctl start minecraft.service
   sudo systemctl start mc-idle-check.timer
   sudo systemctl start mc-watchdog.timer
   ```

## Configuration

### Idle Timeout

To change the idle timeout, edit `/opt/minecraft/scripts/check_idle.sh`:
```bash
IDLE_MINUTES=10  # Change from 5 to 10 minutes
```

### RCON Settings

Update RCON connection details in `/opt/minecraft/scripts/check_idle.sh`:
```bash
RCON_HOST="127.0.0.1"
RCON_PORT="25575"
RCON_PASS="your-secure-password"
```

## Monitoring

### Check Service Status
```bash
systemctl status minecraft.service
systemctl status mc-idle-check.timer
systemctl status mc-watchdog.timer
```

### View Logs
```bash
# Idle check logs
tail -f /var/log/minecraft_idle_check.log

# Watchdog logs
tail -f /var/log/minecraft_watchdog.log

# Minecraft service logs
journalctl -u minecraft.service -f
```

### Check Timer Status
```bash
systemctl list-timers mc-idle-check.timer mc-watchdog.timer
```

## How It Works

1. **Server Startup**: When the instance starts, `minecraft.service` starts the server and resets the idle timer.

2. **Idle Monitoring**: Every minute, `mc-idle-check.timer` triggers `check_idle.sh`:
   - If players are online → reset timer
   - If no players and timer expired → stop server → shutdown instance

3. **Health Monitoring**: Every minute, `mc-watchdog.timer` triggers `mc-check.sh`:
   - If service is active → do nothing
   - If service is not active → shutdown instance

4. **Graceful Shutdown**: When shutdown is triggered:
   - Server receives a `stop` command via RCON
   - Script waits 30 seconds for the server to save
   - Instance is shut down

## Troubleshooting

### Server won't start
- Check that `/opt/minecraft/server-files/run.sh` exists and is executable
- Check server logs: `journalctl -u minecraft.service -n 50`
- Verify file permissions: `ls -la /opt/minecraft/server-files/`

### Idle check not working
- Verify mcrcon is installed: `which mcrcon`
- Check RCON configuration in `server.properties`
- Verify RCON password in `check_idle.sh` matches `server.properties`
- Check logs: `tail -f /var/log/minecraft_idle_check.log`

### Services not running
- Check service status: `systemctl status minecraft.service`
- Verify timers are active: `systemctl list-timers`
- Check systemd logs: `journalctl -xe`

## Security Notes

⚠️ **Important**: 
- Change the default RCON password in `check_idle.sh`
- Use a strong, unique password for RCON
- Ensure RCON is only accessible from localhost (default: 127.0.0.1)
- Review file permissions after deployment

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

