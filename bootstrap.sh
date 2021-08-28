#!/bin/sh

set -e

#!/bin/bash

helpFunction()
{
   echo ""
   echo "Usage: $0 -b <\"grub\" or \"systemd-boot\">"
   echo -e "\t-b bootloader (deafault is systemd-boot)"
   exit 1 # Exit script after printing help
}

bootloader="systemd"

while getopts "b:" opt
do
   case "$opt" in
      b ) bootloader="$OPTARG" ;;
      ? ) helpFunction ;; # Print helpFunction in case parameter is non-existent
   esac
done

if [ $bootloader != "systemd" ] && [ $bootloader != "grub" ]; then
  helpFunction
fi

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

read -p "Install microcode? (auto/intel/amd/both/none) [auto]: " ucode_choice
ucode_choice=${ucode_choice:-auto}

mkfs.fat -F32 $efi_partition 
mkfs.ext4 $root_partition

if [ $swap_partition != "none" ]; then
  mkswap $swap_partition
  swapon $swap_partition
fi 

mount $root_partition /mnt
mkdir /mnt/boot
mount $efi_partition /mnt/boot

timedatectl set-ntp true

pacstrap /mnt base linux linux-firmware grub efibootmgr dhcpcd sudo nano git ansible

# INSTALLATION OF UCODE

if [ $ucode_choice == "auto" ]; then
  if cat /proc/cpuinfo | grep Intel; then
    pacstrap /mnt intel-ucode
  elif cat /proc/cpuinfo | grep AMD; then
    pacstrap /mnt amd-ucode
  fi

elif [ $ucode_choice == "intel" ]; then
  pacstrap /mnt intel-ucode

elif [ $ucode_choice == "amd" ]; then
  pacstrap /mnt amd-ucode

elif [ $ucode_choice == "both" ]; then
  pacstrap /mnt intel-ucode amd-ucode

elif [ $ucode_choice == "none" ]; then
  echo "None it is."

fi

genfstab -U /mnt >> /mnt/etc/fstab

# HOSTNAME CONFIG

echo $host_name > /mnt/etc/hostname

cat <<EOT>> /mnt/etc/hosts
127.0.0.1	localhost
::1		localhost
127.0.1.1	$host_name.localdomain	$host_name
EOT

# DHCP CONFIG

cat << EOF | arch-chroot /mnt
systemctl enable dhcpcd.service
EOF

# BOOTLOADER INSTALLLATION

if [ $bootloader == "systemd-boot" ]; then

cat << EOF | arch-chroot /mnt
bootctl install
EOF

PARTUUID=$(blkid -o export $root_partition | grep PARTUUID)

cat <<EOT>> /mnt/boot/loader/entries/arch.conf
title Arch Linux
linux /vmlinuz-linux
initrd /initramfs-linux.img
options root=$PARTUUID
EOT

cat <<EOT>> /mnt/boot/loader/loader.conf
default arch
EOT

elif [ $bootloader == "grub" ]; then

cat << EOF | arch-chroot /mnt
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
EOF

fi

mkdir -p /mnt/etc/systemd/system/getty@tty1.service.d/
cat <<EOT>> /mnt/etc/systemd/system/getty@tty1.service.d/override.conf

[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin root --noclear %I $TERM

EOT

cat <<EOT>> /mnt/etc/profile.d/ansible-bootstrap.sh

rm /etc/profile.d/ansible-bootstrap.sh
rm /etc/systemd/system/getty@tty1.service.d/override.conf

i=1
while [ "\$i" -le "10" ]; do    
  if ping -c 1 -W 1 github.com > /dev/null; then
    break
  fi
  
  echo "Waiting for github.com - network interface might be down..."
  sleep 4
   
  i=\$(( i + 1 ))
done

ansible-pull -U https://github.com/alencar-felipe/ansible

EOT


