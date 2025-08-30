#!/usr/bin/env bash
OAUTH2_TOKEN="${TOKEN}"
TARGET=OrangePi5Pro
# Unified flash script for Linux and macOS
IMAGE="DietPi_${TARGET}-ARMv8-Bookworm.img"
IMG_NAME="${IMAGE%.xz}"

# Detect OS
OS=$(uname -s)

# Generate random 3-digit number for hostname
RANDOM_NUM=$(printf "%03d" $((RANDOM % 1000)))
HOSTNAME="bracketbot-${RANDOM_NUM}"

# Prompt for WiFi credentials
echo "[*] WiFi Configuration"
read -p "Enter WiFi SSID: " WIFI_SSID
read -p "Enter WiFi Password: " WIFI_PASSWORD

echo -e "\033[1;32m[*] Generated hostname: $HOSTNAME\033[0m"
echo "[*] WiFi SSID: $WIFI_SSID"
echo "[*] WiFi Password: $WIFI_PASSWORD"

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
    echo -n "Continue? (YES/no): "
    read CONFIRM
    [ "$CONFIRM" != "yes" ] && [ "$CONFIRM" != "" ] && exit 0
fi

# Download/decompress if needed
if [[ ! -f "img/$IMAGE" ]]; then
    echo "[*] Downloading..."
    wget -q --show-progress "https://dietpi.com/downloads/images/$IMAGE.xz"
    echo "[*] Decompressing..."
    mkdir -p img
    xz -dk "$IMAGE.xz"
    mv "$IMAGE" img/
    rm "$IMAGE.xz"
fi

# Flash based on OS
echo "[*] Flashing..."
if [ "$OS" = "Linux" ]; then
    sudo dd if="img/$IMAGE" of="$DEVICE" bs=4M conv=fsync status=progress
    sudo partprobe "$DEVICE"
else
    sudo diskutil unmountDisk "$DEVICE"
    sudo dd if="img/$IMAGE" of="${DEVICE/disk/rdisk}" bs=4m status=progress
fi

sleep 2

# Prepare sed expressions for configuration updates
# Escape single quotes in SSID and password for sed
ESCAPED_SSID=$(echo "$WIFI_SSID" | sed "s/'/'\\\\''/g")
ESCAPED_PASSWORD=$(echo "$WIFI_PASSWORD" | sed "s/'/'\\\\''/g")

# Mount and copy files based on OS
echo "[*] Copying config files with updated values..."
if [ "$OS" = "Linux" ]; then
    sudo mkdir -p mnt
    sudo mount ${DEVICE}2 mnt
    [ ! -d "mnt/boot" ] && { sudo umount mnt; sudo mount ${DEVICE}1 mnt; }
    
    # Update and copy dietpi.txt on-the-fly
    sed "s/AUTO_SETUP_NET_HOSTNAME=.*/AUTO_SETUP_NET_HOSTNAME=$HOSTNAME/" ${TARGET}/dietpi.txt | sudo tee mnt/boot/dietpi.txt > /dev/null
    
    # Update and copy dietpi-wifi.txt on-the-fly
    sed -e "s/aWIFI_SSID\[0\]=.*/aWIFI_SSID[0]='$ESCAPED_SSID'/g" \
        -e "s/aWIFI_KEY\[0\]=.*/aWIFI_KEY[0]='$ESCAPED_PASSWORD'/g" ${TARGET}/dietpi-wifi.txt | sudo tee mnt/boot/dietpi-wifi.txt > /dev/null

    sed -e "s/OAUTH2_TOKEN/$OAUTH2_TOKEN/g" ${TARGET}/Automation_Custom_Script.sh | sudo tee /tmp/mnt/boot/Automation_Custom_Script.sh > /dev/null
    
    sudo cp ${TARGET}/Automation_Custom_Script.sh mnt/boot/
    sudo umount mnt
else
    DISK_ID="${DEVICE#/dev/}"
    anylinuxfs stop 2>/dev/null
    sudo mkdir -p /tmp/mnt
    sudo anylinuxfs "/dev/${DISK_ID}s1" /tmp/mnt
    sleep 3
    
    # Update and copy dietpi.txt on-the-fly
    sed "s/AUTO_SETUP_NET_HOSTNAME=.*/AUTO_SETUP_NET_HOSTNAME=$HOSTNAME/" ${TARGET}/dietpi.txt | sudo tee /tmp/mnt/boot/dietpi.txt > /dev/null
    
    # Update and copy dietpi-wifi.txt on-the-fly
    sed -e "s/aWIFI_SSID\[0\]=.*/aWIFI_SSID[0]='$ESCAPED_SSID'/g" \
        -e "s/aWIFI_KEY\[0\]=.*/aWIFI_KEY[0]='$ESCAPED_PASSWORD'/g" ${TARGET}/dietpi-wifi.txt | sudo tee /tmp/mnt/boot/dietpi-wifi.txt > /dev/null
   
    sudo cp -X ${TARGET}/Automation_Custom_Script.sh /tmp/mnt/boot/

    sed -e "s/WIFI_SSID/$ESCAPED_SSID/g" \
        -e "s/WIFI_PASSWORD/$ESCAPED_PASSWORD/g" ${TARGET}/Automation_Custom_Script.sh | sudo tee /tmp/mnt/boot/Automation_Custom_Script.sh > /dev/null

    sed -e "s/OAUTH2_TOKEN/$OAUTH2_TOKEN/g" ${TARGET}/Automation_Custom_Script.sh | sudo tee /tmp/mnt/boot/Automation_Custom_Script.sh > /dev/null
    
    sudo umount /tmp/mnt 2>/dev/null
    anylinuxfs stop
fi

sync
echo "[✔] Flash complete!"
