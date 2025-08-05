#!/usr/bin/env bash

# Unified flash script for Linux and macOS
IMAGE="DietPi_OrangePi5Ultra-ARMv8-Bookworm.img.xz"
IMG_NAME="${IMAGE%.xz}"

# Detect OS
OS=$(uname -s)

# Find device based on OS
if [ "$OS" = "Linux" ]; then
    DEVICE=($(lsblk -dn -o NAME | grep -E '^sd' | sort | sed 's|^|/dev/|'))
elif [ "$OS" = "Darwin" ]; then
    # Check anylinuxfs on macOS
    if ! command -v anylinuxfs &> /dev/null; then
        echo "[!] Install anylinuxfs first:"
        echo "    brew tap nohajc/anylinuxfs"
        echo "    brew install anylinuxfs"
        exit 1
    fi
    DEVICE=$(diskutil list | grep -B 3 "external, physical" | grep "/dev/disk" | head -n1 | awk '{print $1}')
else
    echo "[!] Unsupported OS: $OS"
    exit 1
fi

[ -z "$DEVICE" ] && { echo "[!] No external disk found."; exit 1; }

# Confirm on macOS
if [ "$OS" = "Darwin" ]; then
    echo "[*] Will flash to: $DEVICE"
    echo -n "Continue? (yes/no): "
    read CONFIRM
    [ "$CONFIRM" != "yes" ] && exit 0
fi

# Download/decompress if needed
if [[ ! -f "$IMG_NAME" ]]; then
    [[ ! -f "$IMAGE" ]] && {
        echo "[*] Downloading..."
        wget -q --show-progress "https://dietpi.com/downloads/images/$IMAGE"
    }
    echo "[*] Decompressing..."
    xz -dk "$IMAGE"
fi

# Flash based on OS
echo "[*] Flashing..."
if [ "$OS" = "Linux" ]; then
    sudo dd if="$IMG_NAME" of="$DEVICE" bs=4M conv=fsync status=progress
    sudo partprobe "$DEVICE"
else
    sudo diskutil unmountDisk "$DEVICE"
    sudo dd if="$IMG_NAME" of="${DEVICE/disk/rdisk}" bs=4m status=progress
fi

sleep 2

# Mount and copy files based on OS
echo "[*] Copying config files..."
if [ "$OS" = "Linux" ]; then
    sudo mkdir -p mnt
    sudo mount ${DEVICE}2 mnt
    [ ! -d "mnt/boot" ] && { sudo umount mnt; sudo mount ${DEVICE}1 mnt; }
    sudo cp dietpi*.txt mnt/boot/
    sudo cp Automation_Custom_Script.sh mnt/boot/
    sudo umount mnt
else
    DISK_ID="${DEVICE#/dev/}"
    anylinuxfs stop 2>/dev/null
    sudo mkdir -p /tmp/mnt
    sudo anylinuxfs "/dev/${DISK_ID}s1" /tmp/mnt
    sleep 3
    sudo cp dietpi*.txt /tmp/mnt/boot/
    sudo cp Automation_Custom_Script.sh /tmp/mnt/boot/
    sudo umount /tmp/mnt 2>/dev/null
    anylinuxfs stop
fi

sync
echo "[✔] Flash complete!"