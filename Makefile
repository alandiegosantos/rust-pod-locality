export DOCKER_IMG_REPO ?= docker.io/alandiegosantos
export VERSION ?= $(shell git rev-parse --short --verify HEAD)

export DOCKER_IMG ?= $(DOCKER_IMG_REPO)/k8s-controller:$(VERSION)
export OPERATOR_NAMESPACE ?=  controllers

export CONTAINER_CTL ?= docker

all: build

.PHONY: build
build:
	cargo build

.PHONY: run
run:
	cargo run

.PHONY: fmt
fmt:
	cargo fmt

.PHONY: docker-build
docker-build:
	${CONTAINER_CTL} build -t ${DOCKER_IMG} -f Dockerfile .

.PHONY: docker-push
docker-push: docker-build
	${CONTAINER_CTL} push ${DOCKER_IMG} 


.PHONY: deploy
deploy:
	cd deployment/overlays/dev && kustomize edit set namespace $(OPERATOR_NAMESPACE)
	cd deployment/overlays/dev && kustomize edit set image manager=$(DOCKER_IMG)

