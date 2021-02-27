#!/bin/sh

set -e

if [ ! -d /sys/firmware/efi/efivars ]; then
  printf "Error: This system is not booted in UEFI mode."
  exit 1
fi

read -p "Root Patition [/dev/sda1]: " root_partition
root_partition=${root_partition:-/dev/sda1}

if df -h | grep $root_partition; then
  printf "$root_partition is mounted."
  exit 1
fi

read -p "Swap Partition [/dev/sda2]: " swap_partition
swap_partition=${swap_partition:-/dev/sda2}

if df -h | grep $swap_partition; then
  printf "$swap_partition is mounted."
  exit 1
fi

read -p "EFI Partition [/dev/sda3]: " efi_partition
efi_partition=${efi_partition:-/dev/sda3}

if df -h | grep $efi_partition; then
  printf "$efi_partition is mounted."
  exit 1
fi  

read -p "Host name [myarch]: " host_name
host_name=${host_name:-myarch}

mkfs.fat -F32 $efi_partition 
mkfs.ext4 $root_partition

if [ $swap_partition != "none" ]; then
  mkswap $swap_partition
  swapon $swap_partition
fi 

mount $root_partition /mnt

timedatectl set-ntp true

pacstrap /mnt base linux linux-firmware grub efibootmgr dhcpcd sudo nano git ansible

genfstab -U /mnt >> /mnt/etc/fstab

echo $host_name > /mnt/etc/hostname

cat <<EOT>> /mnt/etc/hosts
127.0.0.1	localhost
::1		localhost
127.0.1.1	$host_name.localdomain	$host_name
EOT

cat << EOF | arch-chroot /mnt

mkdir /boot/efi
mount $efi_partition /boot/efi
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

systemctl enable dhcpcd.service

EOF

cat <<EOT>> /mnt/root/.bashrc

if [ "\$(stat -c %d:%i /)" == "\$(stat -c %d:%i /proc/1/root/.)" ]; then
  ansible-pull -U https://github.com/alencar-felipe/ansible
fi

EOT

cat <<EOT>> /mnt/etc/systemd/system/getty@tty1.service.d/override.conf

[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin root --noclear %I $TERM

EOT
