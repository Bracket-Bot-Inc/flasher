# DietPi Flasher

A simple tool to flash DietPi images to SD cards with custom configuration.

## Features

- Downloads DietPi image for Orange Pi 5 Ultra
- Flashes the image to your SD card
- Mounts the Linux filesystem to access the `/boot` directory
- Automatically copies custom configuration files
- Supports both macOS (Apple Silicon) and Linux

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

2. Run the appropriate script for your OS:
   ```bash
   # For macOS
   ./flash-macos.sh

   # For Linux
   ./flash-linux.sh
   ```

3. Follow the prompts to select your SD card

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

### Linux
The Linux script directly mounts the ext4 filesystem and copies configuration files to the `/boot` directory.

### macOS
Since macOS cannot natively mount Linux filesystems, the script uses `anylinuxfs` which:
- Creates a lightweight Linux VM in the background
- Mounts the ext4 partition inside the VM
- Exports it back to macOS via NFS
- Allows copying files to the `/boot` directory

## Notes

- The image is cached after first download to save time on subsequent flashes
- Default password is set to `1234` (configured in dietpi.txt)
- WiFi is enabled by default, Ethernet is disabled (can be changed in dietpi.txt)
- Warning messages about "extended attributes" on macOS are harmless and can be ignored