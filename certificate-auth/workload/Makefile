VERSION ?= v0.0.1
REGISTRY ?= fengyu225
APP_NAME ?= db-client
IMAGE_TAG ?= $(VERSION)

.PHONY: init
init:
	@echo "Initializing Go modules..."
	go mod tidy

.PHONY: build
build: init
	CGO_ENABLED=0 go build -o bin/dbclient

.PHONY: docker-build
docker-build:
	docker build -t $(REGISTRY)/$(APP_NAME):$(IMAGE_TAG) .

.PHONY: docker-push
docker-push:
	docker push $(REGISTRY)/$(APP_NAME):$(IMAGE_TAG)

.PHONY: run
run: build
	./bin/dbclient

.PHONY: clean
clean:
	rm -f bin/dbclient
	rm -f go.sum

.PHONY: docker-run
docker-run:
	docker run --network db-network $(REGISTRY)/$(APP_NAME):$(IMAGE_TAG)