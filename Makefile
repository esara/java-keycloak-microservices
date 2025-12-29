.PHONY: build build-all docker-build docker-build-local deploy clean setup

# DockerHub username (set via DOCKERHUB_USERNAME env var or override)
DOCKERHUB_USERNAME ?= esara

# Image tag (set via IMAGE_TAG env var or override)
IMAGE_TAG ?= javaagent

# Build all services
build-all:
	cd api-gateway && mvn clean package -DskipTests
	cd user-service && mvn clean package -DskipTests
	cd product-service && mvn clean package -DskipTests

# Build and push multi-arch Docker images to DockerHub
docker-build:
	@echo "Building multi-arch images for arm64 and amd64 with tag: $(IMAGE_TAG)..."
	docker buildx build --platform linux/amd64,linux/arm64 \
		-t $(DOCKERHUB_USERNAME)/api-gateway:$(IMAGE_TAG) \
		--push ./api-gateway
	docker buildx build --platform linux/amd64,linux/arm64 \
		-t $(DOCKERHUB_USERNAME)/user-service:$(IMAGE_TAG) \
		--push ./user-service
	docker buildx build --platform linux/amd64,linux/arm64 \
		-t $(DOCKERHUB_USERNAME)/product-service:$(IMAGE_TAG) \
		--push ./product-service
	@echo "✅ Images built and pushed to DockerHub with tag: $(IMAGE_TAG)"

# Build single-arch images locally (for testing, no push)
docker-build-local:
	@echo "Building images locally for current platform (no push) with tag: $(IMAGE_TAG)..."
	docker build -t api-gateway:$(IMAGE_TAG) ./api-gateway
	docker build -t user-service:$(IMAGE_TAG) ./user-service
	docker build -t product-service:$(IMAGE_TAG) ./product-service

# Deploy to Kubernetes using Helm
deploy:
	helm upgrade --install --namespace cloakworks --create-namespace keycloak-microservices ./helm/keycloak-microservices
	kubectl wait --for=condition=available --timeout=300s deployment/keycloak -n cloakworks || true

# Clean up
clean:
	helm uninstall --namespace cloakworks keycloak-microservices || true
	cd api-gateway && mvn clean
	cd user-service && mvn clean
	cd product-service && mvn clean

# Full setup
setup: build-all docker-build deploy

