#!/bin/bash

# Initialize error log
ERROR_LOG="/tmp/arch_install_errors.log"
> "$ERROR_LOG"

# Error handling function
log_error() {
  echo "Error: $1" >> "$ERROR_LOG"
}

# Get installation disk name
echo "Available disks:"
lsblk
read -p "Enter disk name for installation (e.g., sda): " DISK
DISK="/dev/${DISK}"

# Disk partitioning
echo "Partitioning disk $DISK..."
fdisk -l

(
echo g
echo n
echo 1
echo
echo +500M
echo t
echo 1
echo n
echo 2
echo
echo +4G
echo t
echo 2
echo 19
echo n
echo 3
echo
echo
echo w
) | fdisk $DISK 2>> "$ERROR_LOG" || log_error "Disk partitioning failed"

fdisk -l

# Formatting partitions
echo "Formatting partitions..."
mkfs.fat -F32 ${DISK}1 2>> "$ERROR_LOG" || log_error "EFI partition formatting failed"
mkswap ${DISK}2 2>> "$ERROR_LOG" || log_error "Swap creation failed"
mkfs.ext4 ${DISK}3 2>> "$ERROR_LOG" || log_error "Root partition formatting failed"

# Mounting partitions
echo "Mounting partitions..."
swapon ${DISK}2 2>> "$ERROR_LOG" || log_error "Swap activation failed"
mount ${DISK}3 /mnt 2>> "$ERROR_LOG" || log_error "Root partition mount failed"
mkdir -p /mnt/boot/efi
mount ${DISK}1 /mnt/boot/efi 2>> "$ERROR_LOG" || log_error "EFI partition mount failed"

# Base system installation
echo "Installing base system..."
pacstrap /mnt base linux linux-firmware nano sudo networkmanager grub efibootmgr 2>> "$ERROR_LOG" || log_error "Package installation failed"

# Generate fstab
echo "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab 2>> "$ERROR_LOG" || log_error "fstab generation failed"
cat /mnt/etc/fstab

# System configuration in chroot
echo "Configuring system in chroot..."
arch-chroot /mnt /bin/bash <<EOF 2>> "$ERROR_LOG" || log_error "Chroot environment error"

# Timezone and locale setup
timedatectl set-timezone Europe/Moscow
ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime
hwclock --systohc

# Locale configuration
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "ru_RU.UTF-8 UTF-8" >> /etc/locale.gen
echo "ru_UA.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen

# Network configuration
read -p "Enter hostname: " HOSTNAME
echo "\$HOSTNAME" > /etc/hostname

cat > /etc/hosts <<HOSTS_EOF
127.0.0.1  localhost
::1        localhost
127.0.1.1  \$HOSTNAME.localdomain  \$HOSTNAME
HOSTS_EOF

# Set root password
echo "Setting root password:"
passwd || exit 1

# Create user
read -p "Enter username: " USER
useradd -m \$USER || exit 1
echo "Setting password for user \$USER:"
passwd \$USER || exit 1
usermod -aG wheel,audio,video,storage,optical \$USER

# Configure sudo
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers
echo "%sudo ALL=(ALL) ALL" >> /etc/sudoers

# Enable NetworkManager
systemctl enable NetworkManager

# Install bootloader
grub-install --target=x86_64-efi --bootloader-id=grub_uefi --recheck $DISK || exit 1
grub-mkconfig -o /boot/grub/grub.cfg || exit 1

exit
EOF

# Finalizing installation
echo "Completing installation..."
umount -R /mnt 2>> "$ERROR_LOG" || log_error "Unmounting failed"

# Display collected errors
echo -e "\n\n=== Installation Summary ==="
if [ -s "$ERROR_LOG" ]; then
  echo -e "\nThe following errors occurred during installation:"
  cat "$ERROR_LOG"
  echo -e "\nWarning: Some errors were encountered during installation!"
else
  echo -e "\nNo errors detected during installation."
fi

echo -e "\nInstallation complete! Execute 'reboot' to restart the system."
