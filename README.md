# DietPi Flasher

A simple tool to flash DietPi images to SD cards with custom configuration.

## Features

- Downloads DietPi image for Orange Pi 5 Ultra
- Flashes the image to your SD card
- Mounts the Linux filesystem to access the `/boot` directory
- Automatically copies custom configuration files
- **Unified script** that automatically detects and supports both macOS and Linux

## Requirements

### macOS (Apple Silicon only)
- `wget` - Install with: `brew install wget`
- `xz` - Install with: `brew install xz`
- `anylinuxfs` - Install with:
  ```bash
  brew tap nohajc/anylinuxfs
  brew install anylinuxfs
  ```
  
**Note**: The macOS script requires an Apple Silicon Mac (M1/M2/M3) as `anylinuxfs` only supports ARM64.

### Linux
- `wget` (usually pre-installed)
- `xz-utils` (usually pre-installed)

## Usage

1. Insert your SD card

2. Run the flash script:
   ```bash
   ./flash.sh
   ```
   
   The script will automatically detect your operating system (macOS or Linux) and use the appropriate commands.

3. On macOS, you'll be prompted to confirm the target disk

4. Wait for the process to complete

## Configuration Files

The flasher automatically copies these configuration files to the `/boot` directory in the Linux filesystem:

- `dietpi.txt` - Main DietPi configuration (includes WiFi settings, timezone, etc.)
- `dietpi-wifi.txt` - WiFi credentials  
- `Automation_Custom_Script.sh` - Custom automation script that runs on first boot

Make sure these files exist in the same directory as the flash script before running it.

## Warning

⚠️ This tool will **completely erase** all data on the selected disk. Always double-check you've selected the correct device before confirming.

## How It Works

The unified `flash.sh` script:
1. Detects your operating system using `uname`
2. Uses platform-specific commands for disk detection and mounting
3. Downloads and caches the DietPi image (if not already present)
4. Flashes the image using `dd` with appropriate parameters
5. Mounts the boot partition and copies your configuration files

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
- macOS users: Warning messages about "extended attributes" are harmless and can be ignored