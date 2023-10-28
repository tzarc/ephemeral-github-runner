.DEFAULT: all
all: runner-image

ROOTFS_SIZE = 80G

.PHONY: clean
clean:
	[ ! -e output ] || rm -rf output

output/vm-rootfs.tar: $(shell find vm-rootfs -type f)
	if [ ! -d output ]; then mkdir output; fi
	cd vm-rootfs \
		&& docker buildx build --tag github-runner-rootfs:latest . \
		&& docker create --name github_runner_rootfs github-runner-rootfs:latest \
		&& docker export github_runner_rootfs -o ../output/vm-rootfs.tar \
		&& docker rm github_runner_rootfs \
		&& docker rmi github-runner-rootfs:latest

output/vm-rootfs: output/vm-rootfs.tar $(shell find vm-builder -type f)
	truncate -s $(ROOTFS_SIZE) output/vm-rootfs
	cd vm-builder \
		&& docker buildx build --tag github-runner-vm-builder:latest . \
		&& docker run --rm --privileged -v $(shell realpath output):/vm-builder/output -e PUID=$(shell id -u) -e PGID=$(shell id -g) github-runner-vm-builder:latest \
		&& docker rmi github-runner-vm-builder:latest

output/vm-rootfs.qcow2: output/vm-rootfs
	[ ! -f output/vm-rootfs.qcow2 ] || rm output/vm-rootfs.qcow2
	qemu-img convert -O qcow2 output/vm-rootfs output/vm-rootfs.qcow2

output/vm-rootfs.qcow2.xz: output/vm-rootfs.qcow2
	[ ! -f output/vm-rootfs.qcow2.xz ] || rm output/vm-rootfs.qcow2.xz
	xz -zk9e -T 0 output/vm-rootfs.qcow2

output/vmlinuz: output/vm-rootfs

output/initrd: output/vm-rootfs

.PHONY: vm-rootfs
vm-rootfs: output/vm-rootfs.qcow2.xz output/vmlinuz output/initrd

.PHONY: container
container: vm-rootfs $(shell find runner-container -type f)
	ls -1al output/ \
		&& cp output/vmlinuz output/initrd output/vm-rootfs.qcow2.xz runner-container \
		&& cd runner-container \
		&& { docker rmi github-runner-vm:latest || true ; } \
		&& docker buildx build --tag github-runner-vm:latest . \
		&& rm -f vmlinuz initrd vm-rootfs.qcow2.xz

.PHONY: squid-container
squid-container: $(shell find squid-container -type f)
	cd squid-container \
		&& docker build -t github-runner-squid:latest .