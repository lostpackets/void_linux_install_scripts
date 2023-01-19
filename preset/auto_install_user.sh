#!/bin/bash

# Get the list of mounted partitions
partitions=$(findmnt -n -o SOURCE)

echo "Please select the partition you want to install on:"
echo "$partitions"
read -p "Enter the path of the partition (e.g. /dev/sda1): " partition

# Check if the partition is already mounted
if findmnt -n -o SOURCE | grep -q "$partition"; then
  echo "The partition is already mounted."
else
  echo "The partition is not mounted. Please mount it before running the script."
  exit 1
fi

# Mount the partition to /mnt
mount "$partition" /mnt

# Install the base system
xbps-install -Sy -R https://alpha.de.repo.voidlinux.org/current -r /mnt base-system

# Configure the bootloader
echo "Please select the bootloader you want to install:"
echo "1. GRUB"
echo "2. Syslinux"
read -p "Enter your choice: " bootloader

if [ $bootloader -eq 1 ]; then
  xbps-install -y -R /mnt grub
  grub-install --target=i386-pc "$partition"
  grub-mkconfig -o /mnt/boot/grub/grub.cfg
elif [ $bootloader -eq 2 ]; then
  xbps-install -y -R /mnt syslinux
  extlinux --install /mnt/boot
  echo "DEFAULT void" > /mnt/boot/syslinux.cfg
  echo "LABEL void" >> /mnt/boot/syslinux.cfg
  echo "  LINUX ../vmlinuz-void" >> /mnt/boot/syslinux.cfg
  echo "  INITRD ../initramfs-void.img" >> /mnt/boot/syslinux.cfg
  echo "  APPEND root=$partition rw" >> /mnt/boot/syslinux.cfg
else
  echo "Invalid choice. Exiting."
  exit 1
fi

# Copy DNS information
cp /etc/resolv.conf /mnt/etc/resolv.conf

# Chroot into the new system
mount --bind /proc /mnt/proc
mount --bind /dev /mnt/dev
mount --bind /sys /mnt/sys
chroot /mnt /bin/bash

# Set the root password
passwd

# Exit the chroot
exit

# Unmount the partition
umount /mnt

echo "Installation complete. Please reboot the system to start using the new system."

