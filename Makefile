.PHONY: build-linux64-static build-macos

NAME := $(shell cat package.yaml | grep "name:" | sed 's/name: *//g')
VERSION := $(shell cat package.yaml | grep "version:" | sed 's/version: *//g')
DIST := $(PWD)/dist/
LINUX64_OUTPUT_DIR := ${NAME}-${VERSION}-linux64-static
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
	tar -C ${DIST} -czvf ${LINUX64_OUTPUT_DIR}.tar.gz ${LINUX64_OUTPUT_DIR}

build-docker-image: build-linux64-static
	docker build . --tag ${NAME} --tag ${NAME}:${VERSION}

docker-image-save: build-docker-image
	docker save ${NAME}:${VERSION} | gzip --best -c > ${NAME}-${VERSION}-docker.tar.gz
