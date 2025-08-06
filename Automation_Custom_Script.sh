ROOT_DEV=$(findmnt -no SOURCE /)

# Add journal + 5‑second commit window (harmless if already set)
if ! tune2fs -l "$ROOT_DEV" | grep -q "has_journal"; then
  tune2fs -O has_journal "$ROOT_DEV"
  echo "Journal enabled"
fi
# Set defaults: full data‑journaling and 5 s commit interval
if ! tune2fs -l "$ROOT_DEV" | grep -q "journal_data"; then
  tune2fs -o journal_data,commit=5 "$ROOT_DEV"
  echo "Journal data set to 5 seconds"
fi

# Patch /etc/fstab for safer options (idempotent)
FSTAB_LINE=$(grep -nE "\s/\s+ext4" /etc/fstab | cut -d: -f1)
if [[ -n "$FSTAB_LINE" ]]; then
  sed -i "${FSTAB_LINE}s@[^ ]*\s*/\s*ext4.*@${ROOT_DEV} / ext4 defaults,noatime,errors=remount-ro 0 1@" /etc/fstab
  echo "Fstab patched"
fi

mkdir -p /boot/overlay-user
cp /boot/dtb/rockchip/overlay/rk3588-uart2-m0.dtbo /boot/overlay-user/

# Add overlays if not already present
grep -q '^overlays=spi1-m1-cs1-spidev$' /boot/dietpiEnv.txt || echo 'overlays=spi1-m1-cs1-spidev' | sudo tee -a /boot/dietpiEnv.txt

# Add user_overlays if not already present
grep -q '^user_overlays=rk3588-uart2-m0$' /boot/dietpiEnv.txt || echo 'user_overlays=rk3588-uart2-m0' | sudo tee -a /boot/dietpiEnv.txt

# Add extraargs, replacing existing line if it exists
EXTRA_ARGS='rootflags=data=journal,errors=remount-ro,commit=5,noatime net.ifnames=0 usbcore.autosuspend=-1'
if grep -q '^extraargs=' /boot/dietpiEnv.txt; then
  sudo sed -i "s|^extraargs=.*|extraargs=$EXTRA_ARGS|" /boot/dietpiEnv.txt
else
  echo "extraargs=$EXTRA_ARGS" | sudo tee -a /boot/dietpiEnv.txt
fi


# Install RKNPU2
curl -o /usr/lib/librknnrt.so https://github.com/Pelochus/ezrknn-toolkit2/raw/3780dd7e3f1b96f9f76533ac0bbcde1dd268c5ad/rknpu2/runtime/Linux/librknn_api/aarch64/librknnrt.so

sudo tee /etc/udev/rules.d/99-rknpu-permissions.rules > /dev/null << 'EOF'
# RKNPU permissions for DRM render devices
# The RK3588 NPU is accessed through these DRM devices
SUBSYSTEM=="drm", KERNEL=="renderD129", MODE="0666", GROUP="render"
SUBSYSTEM=="drm", KERNEL=="card1", MODE="0666", GROUP="render"

# Also handle any traditional rknpu device if it exists
KERNEL=="rknpu", MODE="0666"
KERNEL=="rknpu[0-9]*", MODE="0666"
EOF


OLD_USER=dietpi
NEW_USER=bracketbot
NEW_PASS=1234

# Remove default DietPi user if present
id "$OLD_USER" &>/dev/null && {
  deluser --remove-home "$OLD_USER" || true
  rm -rf "/home/$OLD_USER"
}

# Create bracketbot if missing
if ! id "$NEW_USER" &>/dev/null; then
  adduser --disabled-password --gecos "" "$NEW_USER"
  echo "$NEW_USER:$NEW_PASS" | chpasswd
fi

# Sudo NOPASSWD
SUDOERS_FILE="/etc/sudoers.d/$NEW_USER"
printf "%s ALL=(ALL) NOPASSWD:ALL\n" "$NEW_USER" >"$SUDOERS_FILE"
chmod 0440 "$SUDOERS_FILE"

# Helpful groups

for grp in sudo dialout video audio spi render; do
  getent group "$grp" >/dev/null || groupadd "$grp"
  usermod -aG "$grp" "$NEW_USER"
done

# SPI udev rule (idempotent)
RULE="/etc/udev/rules.d/90-spi.rules"
[[ -f $RULE ]] || echo 'SUBSYSTEM=="spidev", GROUP="spi", MODE="0660"' > "$RULE"


# Copy UART overlay (idempotent)
mkdir -p /boot/overlay-user
OVERLAY_SRC="/boot/dtb/rockchip/overlay/rk3588-uart2-m0.dtbo"
OVERLAY_DST="/boot/overlay-user/rk3588-uart2-m0.dtbo"
[[ -f "$OVERLAY_SRC" && ! -f "$OVERLAY_DST" ]] && cp "$OVERLAY_SRC" "$OVERLAY_DST"

# Install the Mali-G610 driver library
cd /usr/lib && sudo curl \
https://github.com/JeffyCN/mirrors/raw/libmali/lib/aarch64-linux-gnu/libmali-valhall-g610-g6p0-x11-wayland-gbm.so

# -- Install the GPU firmware blob
cd /lib/firmware && sudo curl \
https://github.com/JeffyCN/mirrors/raw/libmali/firmware/g610/mali_csffw.bin

# --  Register the driver with the OpenCL ICD loader
sudo mkdir -p /etc/OpenCL/vendors
echo "/usr/lib/libmali-valhall-g610-g6p0-x11-wayland-gbm.so" | \
sudo tee /etc/OpenCL/vendors/mali.icd


# Install bracketbot
runasuser() {
       su - bracketbot -c "cd /home/bracketbot; source ~/.bashrc; $*"
}
runasuser "curl -LsSf https://astral.sh/uv/install.sh | sh"
runasuser "uv python install 3.11"
runasuser "[[ -d BracketBotOS ]] || git clone -b ipc https://oauth2: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@github.com/Bracket-Bot-Inc/BracketBotOS.git"
runasuser "cd BracketBotOS; uv run ./install"

# Use NetworkManager instead of ifupdown
sudo apt purge -y ifupdown isc-dhcp-client isc-dhcp-server

sudo systemctl disable --now \
       ifupdown-pre.service \
       dnsmasq.service \
       ifup@wlan0.service ifup@eth0.service \
       dietpi-wifi-monitor.service || true
sudo systemctl mask networking.service ifupdown-pre.service
printf "auto lo\niface lo inet loopback\n" | sudo tee /etc/network/interfaces

# disable mac randomization
NETWORK_MANAGER_CONF="/etc/NetworkManager/conf.d/90-disable-mac-rand.conf"
if [[ ! -f "$NETWORK_MANAGER_CONF" ]]; then
  sudo tee "$NETWORK_MANAGER_CONF" >/dev/null <<'EOF'
[device]
wifi.scan-rand-mac-address=no

[connection]
wifi.cloned-mac-address=permanent
EOF
fi

sudo reboot
