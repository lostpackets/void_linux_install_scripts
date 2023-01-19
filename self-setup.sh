#!/bin/bash

# Get the list of available storage devices
storage_devices=$(lsblk -d -n -o name,size | grep -v '^loop' | grep -v '^sr0')

echo "Please select the storage device you want to install on:"
echo "$storage_devices"
read -p "Enter the name of the storage device (e.g. sda): " device

# Get the size of the storage device
size=$(lsblk -d -n -o size "$device")

echo "Please select the partitioning scheme:"
echo "1. MBR"
echo "2. GPT"
read -p "Enter your choice: " partition_scheme

if [ $partition_scheme -eq 1 ]; then
  echo "MBR partitioning scheme selected."
  parted --script "$device" mklabel msdos
elif [ $partition_scheme -eq 2 ]; then
  echo "GPT partitioning scheme selected."
  parted --script "$device" mklabel gpt
else
  echo "Invalid choice. Exiting."
  exit 1
fi

# Create partitions
read -p "Enter the size of the boot partition in GB: " boot_size
read -p "Enter the size of the root partition in GB: " root_size

# Calculate the start and end of the partitions
boot_start=1
boot_end=$(echo "$boot_size" | awk '{print $1*1024}')
root_start=$(echo "$boot_end" | awk '{print $1 + 1}')
root_end=$(echo "$root_size" | awk '{print $1*1024 + boot_end}')

# Create the partitions
parted --script "$device" mkpart primary ext4 "$boot_start"MiB "$boot_end"MiB
mkpart primary ext4 "$root_start"MiB "$root_end"MiB

# Format the partitions
mkfs.ext4 "${device}1"
mkfs.ext4 "${device}2"

# Mount the partitions
mount "${device}1" /mnt
mkdir /mnt/root
mount "${device}2" /mnt/root

# Install the base system
xbps-install -Sy -R https://alpha.de.repo.voidlinux.org/current -r /mnt base-system

# Configure the bootloader
echo "Please select the bootloader you want to install:"
echo "1. GRUB"
echo "2. Syslinux"
read -p "Enter your choice: " bootloader

if [ $bootloader -eq 1 ]; then
  xbps-install -y -R /mnt grub
  grub-install --target=i386-pc "$device"
  grub-mkconfig -o /mnt/boot/grub/grub.cfg
elif [ $bootloader -eq 2 ]; then
  xbps-install -y -R /mnt syslinux
  extlinux --install /mnt/boot
  echo "DEFAULT void" > /mnt/boot/syslinux.cfg
  #!/bin/bash
...
  echo "LABEL void" >> /mnt/boot/syslinux.cfg
  echo "  LINUX ../vmlinuz-void" >> /mnt/boot/syslinux.cfg
  echo "  INITRD ../initramfs-void.img" >> /mnt/boot/syslinux.cfg
  echo "  APPEND root=/dev/sda2 rw" >> /mnt/boot/syslinux.cfg
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

#

