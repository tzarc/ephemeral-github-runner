#!/bin/bash

set -x

# Set up directories
[ -d /base ] || mkdir /base
[ -d /work ] || mkdir /work

# Extract the disk image
xz -dc vm-rootfs.qcow2.xz > /base/vm-rootfs.qcow2

# Work out the args to pass to qemu
config_entries=()
mkdir -p /tmp/fw_cfg

# Proxy config entries
[[ -z "${http_proxy:-}" ]] || { echo "${http_proxy}" > /tmp/fw_cfg/http_proxy ; config_entries+=("-fw_cfg name=opt/runner/http_proxy,file=/tmp/fw_cfg/http_proxy") ; }
[[ -z "${https_proxy:-}" ]] || { echo "${https_proxy}" > /tmp/fw_cfg/https_proxy ; config_entries+=("-fw_cfg name=opt/runner/https_proxy,file=/tmp/fw_cfg/https_proxy") ; }
[[ -z "${no_proxy:-}" ]] || { echo "${no_proxy}" > /tmp/fw_cfg/no_proxy ; config_entries+=("-fw_cfg name=opt/runner/no_proxy,file=/tmp/fw_cfg/no_proxy") ; }

# Github config entries
[[ -z "${GITHUB_REPOSITORY:-}" ]] || { echo "${GITHUB_REPOSITORY}" > /tmp/fw_cfg/GITHUB_REPOSITORY ; config_entries+=("-fw_cfg name=opt/runner/GITHUB_REPOSITORY,file=/tmp/fw_cfg/GITHUB_REPOSITORY") ; }

# Optional command to execute, if we want to skip the runner
[[ -z "${EXEC_COMMAND:-}" ]] || { echo "${EXEC_COMMAND}" > /tmp/fw_cfg/EXEC_COMMAND ; config_entries+=("-fw_cfg name=opt/runner/EXEC_COMMAND,file=/tmp/fw_cfg/EXEC_COMMAND") ; }

# Optional runner architecture -- x64, arm64, arm
[[ -z "${RUNNER_ARCH:-}" ]] || { echo "${RUNNER_ARCH}" > /tmp/fw_cfg/RUNNER_ARCH ; config_entries+=("-fw_cfg name=opt/runner/RUNNER_ARCH,file=/tmp/fw_cfg/RUNNER_ARCH") ; }

# Work out if we want to run nice
if [[ ${NICE_VAL:-0} -ne 0 ]] ; then
    NICE_CMD="nice -n${NICE_VAL:-0}"
fi

while true ; do

    # Delete any pre-existing snapshot
    [ ! -f /work/vm-snap.qcow2 ] || rm /work/vm-snap.qcow2

    # Create a new snapshot so we don't mess with the rootfs each time
    qemu-img create -f qcow2 -b /base/vm-rootfs.qcow2 -F qcow2 /work/vm-snap.qcow2

    # Create a registration token
    gh api --method POST -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" "repos/${GITHUB_REPOSITORY}/actions/runners/registration-token" --jq '.token' > /tmp/fw_cfg/REGISTRATION_TOKEN

    # Start the VM
    ${NICE_CMD:-} qemu-system-x86_64 \
        -smp $NUM_CPUS \
        -m $MEMORY_ALLOC \
        -enable-kvm \
        -machine q35,accel=kvm:tcg \
        -cpu host \
        -object rng-random,id=rng0,filename=/dev/urandom \
        -device virtio-balloon-pci,id=balloon0,deflate-on-oom=on \
        -device virtio-rng-pci,rng=rng0 \
        -device virtio-net-pci,netdev=t0 \
        -netdev user,id=t0 \
        -nographic \
        -kernel /vmlinuz \
        -initrd /initrd \
        -drive file=/work/vm-snap.qcow2,index=0,media=disk \
        -append "root=/dev/sda nomodeset console=ttyS0 net.ifnames=0" \
        ${config_entries[@]} \
        -fw_cfg name=opt/runner/REGISTRATION_TOKEN,file=/tmp/fw_cfg/REGISTRATION_TOKEN
done
