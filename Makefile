.PHONY: build-linux64-static build-docker-image build docker-image-save

NAME := $(shell cat package.yaml | grep "name:" | sed 's/name: *//g')
VERSION := $(shell cat package.yaml | grep "version:" | sed 's/version: *//g')
DIST := $(PWD)/dist/
OS_NAME := $(shell uname -s | tr '[:upper:]' '[:lower:]')
OS_ARCH := $(shell uname -m)

OUTPUT_DIR := ${NAME}-${VERSION}-${OS_NAME}-${OS_ARCH}
FULL_OUTPUT_DIR := ${DIST}/${OUTPUT_DIR}

LINUX64_OUTPUT_DIR := ${NAME}-${VERSION}-linux-x86_64-static
LINUX64_FULL_OUTPUT_DIR := ${DIST}/${LINUX64_OUTPUT_DIR}

build-linux64-static:
	mkdir -p ${LINUX64_FULL_OUTPUT_DIR}
	docker run --rm \
		-v $(PWD):/usr/src/build \
		-v $(HOME)/.stack:/root/.stack \
		-v ${LINUX64_FULL_OUTPUT_DIR}:/root/.local/bin \
		-w /usr/src/build -it itkach/alpine-haskell-stack19 \
		bash -c "stack config set system-ghc --global true && \
			 stack install --ghc-options='-optl-static -fPIC -optc-Os'"
	tar -C ${DIST} -czvf ${DIST}/${LINUX64_OUTPUT_DIR}.tar.gz ${LINUX64_OUTPUT_DIR}

build-docker-image: build-linux64-static
	docker build . --tag ${NAME} --tag ${NAME}:${VERSION}

build:
	mkdir -p ${FULL_OUTPUT_DIR}
	stack install --local-bin-path ${FULL_OUTPUT_DIR}
	tar -C ${DIST} -czvf ${DIST}/${OUTPUT_DIR}.tar.gz ${OUTPUT_DIR}

docker-image-save: build-docker-image
	docker save ${NAME}:${VERSION} | gzip --best -c > ${NAME}-${VERSION}-docker.tar.gz
