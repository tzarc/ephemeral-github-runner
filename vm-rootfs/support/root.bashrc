#!/usr/bin/env bash
#set -x

# Create a swapfile for larger builds
fallocate -l 32G /swapfile
chmod 0600 /swapfile
mkswap /swapfile
swapon /swapfile

import_var() {
    local var_name="$1"
    if [ -f /sys/firmware/qemu_fw_cfg/by_name/opt/runner/${var_name}/raw ]; then
        cat /sys/firmware/qemu_fw_cfg/by_name/opt/runner/${var_name}/raw
    fi
}

# Work out which command we're going to be executing, if any
EXEC_COMMAND=$(import_var EXEC_COMMAND)

# Determine the github runner registration token
REGISTRATION_TOKEN=$(import_var REGISTRATION_TOKEN)
GITHUB_REPOSITORY=$(import_var GITHUB_REPOSITORY)

# Arch
RUNNER_ARCH=$(import_var RUNNER_ARCH)

# Set up proxy information
export http_proxy=$(import_var http_proxy)
export https_proxy=$(import_var https_proxy)
export no_proxy=$(import_var no_proxy)

# Configure docker to use the supplied proxy information
mkdir -p /etc/systemd/system/docker.service.d
echo '[Service]' >/etc/systemd/system/docker.service.d/http-proxy.conf
[ -z "${http_proxy:-}" ] || echo "Environment=\"HTTP_PROXY=${http_proxy}\"" >>/etc/systemd/system/docker.service.d/http-proxy.conf
[ -z "${https_proxy:-}" ] || echo "Environment=\"HTTPS_PROXY=${https_proxy}\"" >>/etc/systemd/system/docker.service.d/http-proxy.conf
[ -z "${no_proxy:-}" ] || echo "Environment=\"NO_PROXY=${no_proxy}\"" >>/etc/systemd/system/docker.service.d/http-proxy.conf

# Restart docker so the new proxy configuration is picked up
systemctl daemon-reload
systemctl restart docker

# Work out the command we're executing
target_dir=/home/runner
if [[ ! -z "${EXEC_COMMAND:-}" ]]; then
    EXEC_COMMAND="${EXEC_COMMAND#exec }" # Strip leading 'exec ', if any
    EXEC_COMMAND="exec $EXEC_COMMAND"    # Prepend an 'exec '
else
    EXEC_COMMAND="./config.sh --url https://github.com/${GITHUB_REPOSITORY} --token ${REGISTRATION_TOKEN} --ephemeral --unattended || true; exec ./run.sh"
fi

# Download the latest runner binary, so that we're on the latest version
latest_version=$(git ls-remote --tags https://github.com/actions/runner | cut -d'/' -f 3 | tail -n 1)
curl -L -o /tmp/runner.tgz https://github.com/actions/runner/releases/download/$latest_version/actions-runner-linux-${RUNNER_ARCH:-x64}-$(echo $latest_version | sed -e 's@^v@@g').tar.gz
tar xzf /tmp/runner.tgz -C /home/runner
chown -R runner:runner /home/runner
rm /tmp/runner.tgz

# Execute the command as the runner user
cd $target_dir
su -c "/usr/bin/env -i HOME=/home/runner USER=runner REGISTRATION_TOKEN=\"${REGISTRATION_TOKEN:-}\" GITHUB_REPOSITORY=\"${GITHUB_REPOSITORY:-}\" http_proxy=\"${http_proxy:-}\" https_proxy=\"${https_proxy:-}\" no_proxy=\"${no_proxy:-}\" bash -lic \"$EXEC_COMMAND\"" runner

# Shut down the VM
poweroff
