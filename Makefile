.DEFAULT: all
all: container

clean:
	rm -rf bin *.qcow2 *.qcow2.xz
	docker rm github-runner-vm:latest 2>/dev/null || true

bin/d2vm:
	if [ ! -d bin ]; then mkdir bin; fi
	VERSION=$$(git ls-remote --tags https://github.com/linka-cloud/d2vm | cut -d'/' -f 3 | grep -v -- '-rc' | tail -n 1) \
		&& OS=$$(uname -s | tr '[:upper:]' '[:lower:]') \
		&& ARCH=$$([ "$$(uname -m)" = "x86_64" ] && echo "amd64" || echo "arm64") \
		&& curl -sL "https://github.com/linka-cloud/d2vm/releases/download/$${VERSION}/d2vm_$${VERSION}_$${OS}_$${ARCH}.tar.gz" | tar -xvz d2vm
	mv d2vm bin/d2vm
	chmod +x bin/d2vm

disk-image.qcow2: Makefile bin/d2vm inner-container/Dockerfile.github-runner $(shell ls inner-container/support | xargs -I{} echo inner-container/support/{} | xargs echo)
	[ ! -f disk-image.qcow2 ] || rm disk-image.qcow2
	./bin/d2vm build --file inner-container/Dockerfile.github-runner --output disk-image.qcow2 --force --verbose --size 120G .

disk-image.qcow2.xz: Makefile disk-image.qcow2
	xz -zk9e -T 0 disk-image.qcow2

container: Makefile disk-image.qcow2.xz
	docker rm github-runner-vm:latest || true
	docker build -t github-runner-vm:latest -f outer-container/Dockerfile.runner-wrapper .
