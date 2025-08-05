# DietPi Flasher

A simple tool to flash DietPi images to SD cards with custom configuration.

## Requirements

### macOS (Apple Silicon only)
- `wget` - Install with: `brew install wget`
- `xz` - Install with: `brew install xz`
- `anylinuxfs` - Install with:
  ```bash
  brew tap nohajc/anylinuxfs
  brew install anylinuxfs
  ```
- `tmux` (for log viewer) - Install with: `brew install tmux`
  
**Note**: The macOS script requires an Apple Silicon Mac (M1/M2/M3) as `anylinuxfs` only supports ARM64.

### Linux
- `wget` (usually pre-installed)
- `xz-utils` (usually pre-installed)
- `tmux` (for log viewer) - Install with: `sudo apt-get install tmux`

## Usage

### Flashing the SD Card

1. Insert your SD card

2. Run the flash script:
   ```bash
   ./flash.sh
   ```

3. You'll be prompted for WiFi configuration:
   ```
   [*] WiFi Configuration
   Enter WiFi SSID: YourNetworkName
   Enter WiFi Password: YourPassword
   [*] Generated hostname: bracketbot-742
   [*] WiFi SSID: YourNetworkName
   [*] WiFi Password: YourPassword
   ```

4. On macOS, you'll be prompted to confirm the target disk

5. Wait for the flashing process to complete

The script will:
- Generate a unique hostname with format `bracketbot-XXX` (where XXX is a random 3-digit number)
- Configure WiFi with your provided credentials
- Update configuration files automatically during the copy process

## Features

- Downloads DietPi image for Orange Pi 5 Ultra
- Flashes the image to your SD card
- **Interactive WiFi setup** - prompts for SSID and password at runtime
- **Unique hostname generation** - creates hostnames like `bracketbot-435` with random 3-digit suffix
- Mounts the Linux filesystem to access the `/boot` directory
- Automatically copies and updates configuration files
- **Unified script** that automatically detects and supports both macOS and Linux
- **Log viewer utility** for monitoring device logs after deployment

## Configuration Files

The flasher automatically copies these configuration files to the `/boot` directory in the Linux filesystem:

- `dietpi.txt` - Main DietPi configuration (includes WiFi settings, timezone, etc.)
- `dietpi-wifi.txt` - WiFi credentials  
- `Automation_Custom_Script.sh` - Custom automation script that runs on first boot

**Note**: The configuration files now use placeholders:
- Hostname: `bracketbot-XXX` (replaced with random number at runtime)
- WiFi SSID: `TO-BE-FILLED` (replaced with your input)
- WiFi Password: `TO-BE-FILLED` (replaced with your input)

### Monitoring Device Logs

After flashing and booting your device, you can monitor its logs using the included log viewer:

```bash
./log_viewer.sh
```

The log viewer will:
1. Prompt for the hostname (e.g., `bracketbot-742`)
2. Connect to the device via SSH (default password: `1234`)
3. Open a tmux session with multiple panes showing:
   - Boot logs (`/var/log/syslog`)
   - Service logs (`/var/log/dietpi-*.log`)
   - Real-time log updates

**Tmux controls:**
- `Ctrl-B` then arrow keys: Navigate between panes
- `Ctrl-B` then `d`: Detach from session (logs continue running)
- `tmux attach -t dietpi-logs`: Reattach to session
- `Ctrl-C`: Exit and cleanup

## Warning

⚠️ This tool will **completely erase** all data on the selected disk. Always double-check you've selected the correct device before confirming.

## How It Works

The unified `flash.sh` script:
1. Generates a random 3-digit hostname suffix for uniqueness
2. Prompts for WiFi credentials interactively
3. Detects your operating system using `uname`
4. Uses platform-specific commands for disk detection and mounting
5. Downloads and caches the DietPi image (if not already present)
6. Flashes the image using `dd` with appropriate parameters
7. Mounts the boot partition
8. Updates configuration files on-the-fly using `sed` while copying them (no temporary files needed)

### Platform-Specific Behavior

**Linux**: Directly mounts the ext4 filesystem using native tools

**macOS**: Uses `anylinuxfs` to mount Linux filesystems by:
- Creating a lightweight Linux VM in the background
- Mounting the ext4 partition inside the VM
- Exporting it back to macOS via NFS
- Allowing file operations on the Linux filesystem

## Notes

- The image is cached after first download to save time on subsequent flashes
- Default password is set to `1234` (configured in dietpi.txt)
- WiFi is enabled by default, Ethernet is disabled (can be changed in dietpi.txt)
- Each flash generates a unique hostname to avoid conflicts on the same network
- WiFi passwords are accepted as plain text - DietPi handles the PSK conversion internally
- Single quotes in WiFi credentials are automatically escaped
- Configuration files are modified during the copy process without creating temporary files
- macOS users: Warning messages about "extended attributes" are harmless and can be ignored
- The log viewer requires SSH access (ensure your device is on the network before using it)
