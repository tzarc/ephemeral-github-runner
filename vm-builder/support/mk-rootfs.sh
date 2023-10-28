#!/bin/bash

set -e
umask 022

# Make the filesystem
mkfs.ext4 /vm-builder/output/vm-rootfs

# Mount the filesystem
mount -t ext4 /vm-builder/output/vm-rootfs /mnt

# Deploy the rootfs into the filesystem
tar xf /vm-builder/output/vm-rootfs.tar -C /mnt

# Dummy /etc/fstab
[ ! -e /mnt/etc/fstab ] || rm /mnt/etc/fstab
cat <<-EOF > /mnt/etc/fstab
LABEL=github-runner	/	 ext4	discard,errors=remount-ro	0 1
EOF

# Resolver config
[ ! -e /mnt/etc/resolv.conf ] || rm /mnt/etc/resolv.conf
cat <<-EOF > /mnt/etc/resolv.conf
nameserver 8.8.8.8
EOF

# Default to DHCP for networking
[ ! -e /mnt/etc/network/interfaces ] || rm /mnt/etc/network/interfaces
cat <<-EOF > /mnt/etc/network/interfaces
auto eth0
allow-hotplug eth0
iface eth0 inet dhcp
EOF

# Default set of hostnames
[ ! -e /mnt/etc/hosts ] || rm /mnt/etc/hosts
cat <<-EOF > /mnt/etc/hosts
127.0.0.1	localhost
::1	localhost ip6-localhost ip6-loopback
fe00::0	ip6-localnet
ff00::0	ip6-mcastprefix
ff02::1	ip6-allnodes
ff02::2	ip6-allrouters
EOF

# Kernel and initramfs
cat /mnt/vmlinuz | gzip -dc > /vm-builder/output/vmlinuz
cp /mnt/initrd /vm-builder/output
chown ${PUID}:${PGID} /vm-builder/output/vmlinuz
chown ${PUID}:${PGID} /vm-builder/output/initrd
rm /mnt/vmlinuz /mnt/initrd /mnt/.dockerenv

# Unmount filesystem
umount /mnt

# Finalise and cleanup
e2fsck -p -f /vm-builder/output/vm-rootfs
tune2fs -O ^read-only -L github-runner /vm-builder/output/vm-rootfs