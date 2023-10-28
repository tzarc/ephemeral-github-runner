FROM alpine:latest

RUN apk update \
    && apk --no-cache add bash qemu-system-x86_64 qemu-img runit jq curl github-cli xz

COPY support/entrypoint.sh /entrypoint.sh
COPY vmlinuz /vmlinuz
COPY initrd /initrd
COPY vm-rootfs.qcow2.xz /vm-rootfs.qcow2.xz

ENTRYPOINT ["/entrypoint.sh"]
