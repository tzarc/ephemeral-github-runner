FROM debian:bookworm-slim as kernel
USER 0:0

RUN mkdir -p /var/lib/apt/lists/partial \
    && apt-get update \
    && apt-get install -y --no-install-recommends linux-image-generic udev kmod zstd initramfs-tools \
    && apt-get clean \
    && update-initramfs -u

FROM debian:bookworm-slim
USER 0:0

# Extract the kernel, modules, and initrd
COPY --from=kernel /lib/modules /lib/modules
COPY --from=kernel /boot/vmlinuz-* /vmlinuz
COPY --from=kernel /boot/initrd.img-* /initrd

# slim seems to expect a kernel to be gzipped
RUN ls -1al /vm* \
    && gzip /vmlinuz \
    && mv /vmlinuz.gz /vmlinuz

# Prerequisites
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends \
        apt-utils \
        qemu-guest-agent \
        ca-certificates \
        dnsutils \
        systemd \
        systemd-sysv \
        zstd \
        sudo \
        curl \
        nano \
        udev \
        kmod \
        dbus \
        isc-dhcp-client \
        iproute2 \
        iputils-ping

RUN if [ -z "$(apt-cache madison ifupdown-ng 2> /dev/null)" ]; then \
        DEBIAN_FRONTEND=noninteractive apt-get install -y ifupdown; \
    else\
        DEBIAN_FRONTEND=noninteractive apt-get install -y ifupdown-ng; \
    fi

# Install Docker
RUN DEBIAN_FRONTEND=noninteractive apt-get remove -y docker docker.io containerd runc podman \
    && { rm -f `which docker` || true ; } \
    && curl -fsSL https://get.docker.com | sh

# root user setup
COPY support/root.bashrc /root/.bashrc
RUN chmod 0640 /root/.bashrc

# Auto-login
COPY support/getty.service-override.conf /etc/systemd/system/serial-getty@ttyS0.service.d/override.conf
RUN systemctl enable getty@tty1.service

# Randomly-generated hostname each bootup
COPY support/random-hostname /usr/local/bin/random-hostname
COPY support/random-hostname.service /etc/systemd/system/random-hostname.service
RUN systemctl enable random-hostname

# User setup
RUN useradd runner -m -s /bin/bash -G sudo,docker \
    && echo "runner:runner" | chpasswd \
    && sed -i 's|ALL=(ALL:ALL) ALL|ALL=(ALL:ALL) NOPASSWD: ALL|g' /etc/sudoers

# Clear out some space
RUN apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /var/lib/apt/lists/partial \
    && { systemctl disable swapfile.swap || true ; } \
    && { systemctl mask swapfile.swap || true ; } \
    && { rm /swapfile || true ; }

# Docker commands that follow should be executed as the in-container user
USER runner:runner
