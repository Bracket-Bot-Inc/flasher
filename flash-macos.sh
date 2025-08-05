#!/usr/bin/env bash

# Dead simple macOS script - we KNOW partition 1 has /boot

# Check anylinuxfs
if ! command -v anylinuxfs &> /dev/null; then
    echo "[!] Install anylinuxfs first:"
    echo "    brew tap nohajc/anylinuxfs"
    echo "    brew install anylinuxfs"
    exit 1
fi

# Image files
IMAGE="DietPi_OrangePi5Ultra-ARMv8-Bookworm.img.xz"
IMG_NAME="${IMAGE%.xz}"

# Find disk
DEVICE=$(diskutil list | grep -B 3 "external, physical" | grep "/dev/disk" | head -n1 | awk '{print $1}')
if [ -z "$DEVICE" ]; then
    echo "[!] No external disk found."
    exit 1
fi

echo "[*] Will flash to: $DEVICE"
echo -n "Continue? (yes/no): "
read CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    exit 0
fi

# Download if needed
if [[ ! -f "$IMG_NAME" ]]; then
    if [[ ! -f "$IMAGE" ]]; then
        echo "[*] Downloading..."
        wget -q --show-progress "https://dietpi.com/downloads/images/$IMAGE"
    fi
    echo "[*] Decompressing..."
    xz -dk "$IMAGE"
fi

# Flash
echo "[*] Flashing..."
sudo diskutil unmountDisk "$DEVICE"
sudo dd if="$IMG_NAME" of="${DEVICE/disk/rdisk}" bs=4m status=progress

# Wait
echo "[*] Waiting..."
sleep 5

# Mount partition 1 (we KNOW it has /boot)
DISK_ID=$(echo "$DEVICE" | sed 's|/dev/||')
echo "[*] Mounting Linux partition..."
anylinuxfs stop 2>/dev/null
sudo mkdir -p /tmp/mnt
sudo anylinuxfs "/dev/${DISK_ID}s1" /tmp/mnt

# Wait for mount
sleep 3

# Copy (we KNOW /boot exists in partition 1)
if [ -d "/tmp/mnt/boot" ]; then
    echo "[*] Found /boot, copying files..."
    sudo cp dietpi*.txt /tmp/mnt/boot/
    sudo cp Automation_Custom_Script.sh /tmp/mnt/boot/
    echo "[*] Files copied successfully"
else
    echo "[!] ERROR: /boot not found in partition 1!"
    echo "[*] Contents of mount:"
    ls -la /tmp/mnt/ | head -10
fi

# Done
sudo umount /tmp/mnt 2>/dev/null
anylinuxfs stop
sync

echo "[✔] Done!"