FROM debian:bookworm
RUN mkdir -p /vm-builder/output
COPY support/mk-rootfs.sh /vm-builder/mk-rootfs.sh
CMD /bin/bash /vm-builder/mk-rootfs.sh