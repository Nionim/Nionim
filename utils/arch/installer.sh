#!/bin/bash

# Функция для вывода ошибок
error_exit() {
  echo "Ошибка: $1"
  exit 1
}

# Получаем имя диска для установки
echo "Доступные диски:"
lsblk
read -p "Введите имя диска для установки (например, sda): " DISK
DISK="/dev/${DISK}"

# Разметка диска
echo "Разметка диска $DISK..."
fdisk -l

(
echo g      # Создаем новую GPT таблицу
echo n      # Новый раздел
echo 1      # Номер раздела
echo        # Первый сектор по умолчанию
echo +500M  # Размер раздела
echo t      # Изменение типа раздела
echo 1      # EFI System
echo n      # Новый раздел
echo 2      # Номер раздела
echo        # Первый сектор по умолчанию
echo +4G    # Размер раздела
echo t      # Изменение типа раздела
echo 2      # Номер раздела
echo 19     # Linux swap
echo n      # Новый раздел
echo 3      # Номер раздела
echo        # Первый сектор по умолчанию
echo        # Весь оставшийся диск
echo w      # Записать изменения
) | fdisk $DISK || error_exit "Ошибка при разметке диска"

fdisk -l

# Форматирование разделов
echo "Форматирование разделов..."
mkfs.fat -F32 ${DISK}1 || error_exit "Ошибка при форматировании EFI раздела"
mkswap ${DISK}2 || error_exit "Ошибка при создании swap"
mkfs.ext4 ${DISK}3 || error_exit "Ошибка при форматировании корневого раздела"

# Монтирование разделов
echo "Монтирование разделов..."
swapon ${DISK}2
mount ${DISK}3 /mnt || error_exit "Ошибка при монтировании корневого раздела"
mkdir -p /mnt/boot/efi
mount ${DISK}1 /mnt/boot/efi || error_exit "Ошибка при монтировании EFI раздела"

# Установка базовой системы
echo "Установка базовой системы..."
pacstrap /mnt base linux linux-firmware nano sudo networkmanager grub efibootmgr || error_exit "Ошибка при установке пакетов"

# Генерация fstab
echo "Генерация fstab..."
genfstab -U /mnt >> /mnt/etc/fstab || error_exit "Ошибка при генерации fstab"
cat /mnt/etc/fstab

# Настройка системы в chroot
echo "Настройка системы в chroot..."
arch-chroot /mnt /bin/bash <<EOF || error_exit "Ошибка в chroot окружении"

# Установка времени и локали
timedatectl set-timezone Europe/Moscow
ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime
hwclock --systohc

# Настройка локалей
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "ru_RU.UTF-8 UTF-8" >> /etc/locale.gen
echo "ru_UA.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen

# Настройка сети
read -p "Введите имя хоста: " HOSTNAME
echo "$HOSTNAME" > /etc/hostname

cat > /etc/hosts <<HOSTS_EOF
127.0.0.1  localhost
::1        localhost
127.0.1.1  $HOSTNAME.localdomain  $HOSTNAME
HOSTS_EOF

# Установка пароля root
echo "Установка пароля для root:"
passwd || exit 1

# Создание пользователя
read -p "Введите имя пользователя: " USER
useradd -m \$USER || exit 1
echo "Установка пароля для пользователя \$USER:"
passwd \$USER || exit 1
usermod -aG wheel,audio,video,storage,optical \$USER

# Настройка sudo
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers
echo "%sudo ALL=(ALL) ALL" >> /etc/sudoers

# Включение NetworkManager
systemctl enable NetworkManager

# Установка загрузчика
grub-install --target=x86_64-efi --bootloader-id=grub_uefi --recheck $DISK || exit 1
grub-mkconfig -o /boot/grub/grub.cfg || exit 1

exit
EOF

# Завершение установки
echo "Завершение установки..."
umount -R /mnt
echo "Установка завершена! Выполните reboot для перезагрузки системы."
