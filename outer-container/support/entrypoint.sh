#!/bin/bash

set -x

# Extract the disk image
xz -dk /disk-image.qcow2.xz

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

while true ; do

    # Delete any pre-existing snapshot
    [ ! -f /disk-image-snap.qcow2 ] || rm /disk-image-snap.qcow2

    # Create a new snapshot
    qemu-img create -f qcow2 -b /disk-image.qcow2 -F qcow2 /disk-image-snap.qcow2

    # Create a registration token
    gh api --method POST -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" "repos/${GITHUB_REPOSITORY}/actions/runners/registration-token" --jq '.token' > /tmp/fw_cfg/REGISTRATION_TOKEN

    # Start the VM
    qemu-system-x86_64 -smp $NUM_CPUS -m $MEMORY_ALLOC \
        -enable-kvm \
        -machine q35,accel=kvm:tcg \
        -cpu host \
        -object rng-random,id=rng0,filename=/dev/urandom \
        -device virtio-balloon-pci,id=balloon0,deflate-on-oom=on \
        -device virtio-rng-pci,rng=rng0 \
        -drive file=/disk-image-snap.qcow2,index=0,media=disk \
        -device virtio-net-pci,netdev=t0,mac=ae:3a:04:d8:e0:e2 \
        -netdev user,id=t0 \
        -nographic \
        ${config_entries[@]} \
        -fw_cfg name=opt/runner/REGISTRATION_TOKEN,file=/tmp/fw_cfg/REGISTRATION_TOKEN
done
