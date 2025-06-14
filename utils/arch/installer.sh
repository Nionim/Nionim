#!/bin/bash

read -p "HOSTNAME: " HOSTNAME
read -p "USERNAME: " USERNAME
read -s -p "PASSWORD (For all): " PASSWORD
echo
read -p "DRIVE (default: /dev/sda): " DRIVE
DRIVE=${DRIVE:-/dev/sda}

timedatectl set-ntp true

parted -s $DRIVE mklabel gpt
parted -s $DRIVE mkpart primary fat32 1MiB 513MiB set 1 esp on
parted -s $DRIVE mkpart primary linux-swap 513MiB 4.5GiB
parted -s $DRIVE mkpart primary ext4 4.5GiB 100%

mkfs.fat -F32 ${DRIVE}1
mkswap ${DRIVE}2
mkfs.ext4 ${DRIVE}3

mount ${DRIVE}3 /mnt
mkdir -p /mnt/boot/efi
mount ${DRIVE}1 /mnt/boot/efi
swapon ${DRIVE}2

pacstrap /mnt base linux linux-firmware nano

genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt /bin/bash <<EOF
ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime
hwclock --systohc

echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "ru_RU.UTF-8 UTF-8" >> /etc/locale.gen
echo "ru_UA.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

echo "$HOSTNAME" > /etc/hostname
echo -e "127.0.0.1\tlocalhost\n::1\t\tlocalhost\n127.0.1.1\t$HOSTNAME.localdomain\t$HOSTNAME" >> /etc/hosts

echo "root:$PASSWORD" | chpasswd

useradd -m -G wheel,audio,video,storage,optical,scanner $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd

echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

pacman -S --noconfirm grub efibootmgr networkmanager
systemctl enable NetworkManager
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
EOF

echo "Установка завершена! Перезагружаемся..."
umount -R /mnt
reboot
