.PHONY: build-linux64-static

NAME := $(shell cat package.yaml | grep "name:" | sed 's/name: *//g')
VERSION := $(shell cat package.yaml | grep "version:" | sed 's/version: *//g')
DIST := $(PWD)/dist/
OUTPUT_DIR := ${NAME}-${VERSION}-linux64-static/
FULL_OUTPUT_DIR := ${DIST}/${OUTPUT_DIR}

build-linux64-static:
	mkdir -p ${FULL_OUTPUT_DIR}
	docker run --rm \
		-v $(PWD):/usr/src/build \
		-v $(HOME)/.stack:/root/.stack \
		-v ${FULL_OUTPUT_DIR}:/root/.local/bin \
		-w /usr/src/build -it itkach/alpine-haskell-stack19 \
		bash -c "stack config set system-ghc --global true && stack build --copy-bins"
	tar -C ${DIST} -czvf ${OUTPUT_DIR}.tar.gz ${OUTPUT_DIR}
