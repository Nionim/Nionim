#!/bin/bash

# Initialize error log
ERROR_LOG="/tmp/arch_installer_errors.log"
> "$ERROR_LOG"

# Error handling function
log_error() {
  echo "Error: $1" >> "$ERROR_LOG"
}

# Get user input
read -p "HOSTNAME: " HOSTNAME
read -p "USERNAME: " USERNAME
read -sp "ROOTPASS: " ROOTPASS; echo
read -sp "USERPASS: " USERPASS; echo

# Function to clean disk before partitioning
prepare_disk() {
  local disk=$1
  echo "Unmounting any existing partitions on $disk..."
  umount -R /mnt 2>/dev/null
  swapoff -a 2>/dev/null
  for partition in ${disk}*; do
    umount $partition 2>/dev/null
  done
  
  echo "Wiping existing signatures..."
  wipefs -a $disk 2>> "$ERROR_LOG"
  sgdisk -Z $disk 2>> "$ERROR_LOG"
  sgdisk -o $disk 2>> "$ERROR_LOG"
}

# Function to partition disk
partition_disk() {
  local disk=$1
  echo "Partitioning $disk..."
  (
    echo g      # Create new GPT table
    echo n      # New partition
    echo 1      # Partition number
    echo        # Default first sector
    echo +500M  # Partition size
    echo t      # Change partition type
    echo 1      # EFI System
    echo n      # New partition
    echo 2      # Partition number
    echo        # Default first sector
    echo +4G    # Partition size
    echo t      # Change partition type
    echo 2      # Partition number
    echo 19     # Linux swap
    echo n      # New partition
    echo 3      # Partition number
    echo        # Default first sector
    echo        # Use remaining space
    echo w      # Write changes
  ) | fdisk $disk 2>> "$ERROR_LOG"
}

# Get installation disk
echo "Available disks:"
lsblk
read -p "Enter disk name for installation (e.g., sda): " DISK
DISK="/dev/${DISK}"

# Prepare disk
prepare_disk $DISK

# Partition disk
partition_disk $DISK || log_error "Disk partitioning failed"
fdisk -l $DISK

# Format partitions
echo "Formatting partitions..."
mkfs.fat -F32 ${DISK}1 2>> "$ERROR_LOG" || log_error "EFI partition formatting failed"
mkswap -f ${DISK}2 2>> "$ERROR_LOG" || log_error "Swap creation failed"
mkfs.ext4 -F ${DISK}3 2>> "$ERROR_LOG" || log_error "Root partition formatting failed"

# Mount partitions
echo "Mounting partitions..."
swapon ${DISK}2 2>> "$ERROR_LOG" || log_error "Swap activation failed"
mount ${DISK}3 /mnt 2>> "$ERROR_LOG" || log_error "Root partition mount failed"
mkdir -p /mnt/boot/efi
mount ${DISK}1 /mnt/boot/efi 2>> "$ERROR_LOG" || log_error "EFI partition mount failed"

# Install base system
echo "Installing base system..."
pacstrap /mnt base linux linux-firmware nano sudo networkmanager grub efibootmgr os-prober --needed 2>> "$ERROR_LOG" || log_error "Package installation failed"

# Generate fstab
echo "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab 2>> "$ERROR_LOG" || log_error "fstab generation failed"
cat /mnt/etc/fstab

# Chroot configuration
echo "Configuring system in chroot..."
arch-chroot /mnt /bin/bash <<EOF 2>> "$ERROR_LOG" || log_error "Chroot environment error"

# Set timezone and locale
timedatectl set-timezone Europe/Moscow
ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime
hwclock --systohc

# Configure locales
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "ru_RU.UTF-8 UTF-8" >> /etc/locale.gen
echo "ru_UA.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen

# Set hostname
echo "$HOSTNAME" > /etc/hostname
cat > /etc/hosts <<HOSTS_EOF
127.0.0.1  localhost
::1        localhost
127.0.1.1  $HOSTNAME.localdomain  $HOSTNAME
HOSTS_EOF

# Set passwords
echo "root:$ROOTPASS" | chpasswd
useradd -m $USERNAME
echo "$USERNAME:$USERPASS" | chpasswd
usermod -aG wheel,audio,video,storage,optical $USERNAME

# Configure sudo
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers
echo "%sudo ALL=(ALL) ALL" >> /etc/sudoers

# Enable NetworkManager
systemctl enable NetworkManager

# Install bootloader
grub-install --target=x86_64-efi --bootloader-id=grub_uefi --recheck $DISK
grub-mkconfig -o /boot/grub/grub.cfg

exit
EOF

# Finalize installation
echo "Completing installation..."
umount -R /mnt 2>> "$ERROR_LOG" || log_error "Unmounting failed"

# Show summary
echo -e "\n\n=== Installation Summary ==="
if [ -s "$ERROR_LOG" ]; then
  echo -e "\nThe following errors occurred during installation:"
  cat "$ERROR_LOG"
  echo -e "\nWarning: Some errors were encountered during installation!"
else
  echo -e "\nNo errors detected during installation."
fi

echo -e "\nInstallation complete! Execute 'reboot' to restart the system."
