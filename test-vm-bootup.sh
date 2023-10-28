#!/bin/sh

set -e
umask 022

# Make the disk image
make vm-rootfs

# Create a temporary snapshot
pushd output
[ ! -f vm-snap.qcow2 ] || rm vm-snap.qcow2
qemu-img create -f qcow2 -b vm-rootfs.qcow2 -F qcow2 vm-snap.qcow2
popd

# Boot the VM
qemu-system-x86_64 \
    -smp 2 \
    -m 4096 \
    -enable-kvm \
    -machine q35,accel=kvm:tcg \
    -cpu host \
    -object rng-random,id=rng0,filename=/dev/urandom \
    -device virtio-balloon-pci,id=balloon0,deflate-on-oom=on \
    -device virtio-rng-pci,rng=rng0 \
    -device virtio-net-pci,netdev=t0 \
    -netdev user,id=t0 \
    -nographic \
    -kernel output/vmlinuz \
    -initrd output/initrd \
    -drive file=output/vm-snap.qcow2,index=0,media=disk \
    -append "root=/dev/sda nomodeset console=ttyS0 net.ifnames=0" \
    -fw_cfg name=opt/runner/EXEC_COMMAND,string="bash -li"
