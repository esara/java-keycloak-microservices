#!/bin/bash

set -e

echo "🚀 Deploying Java Keycloak Microservices Demo"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"
command -v kubectl >/dev/null 2>&1 || { echo "kubectl is required but not installed. Aborting." >&2; exit 1; }
command -v helm >/dev/null 2>&1 || { echo "helm is required but not installed. Aborting." >&2; exit 1; }
command -v docker >/dev/null 2>&1 || { echo "docker is required but not installed. Aborting." >&2; exit 1; }
command -v mvn >/dev/null 2>&1 || { echo "mvn is required but not installed. Aborting." >&2; exit 1; }

# Build services
echo -e "${YELLOW}Building services...${NC}"
cd "$(dirname "$0")/.."
mvn clean package -DskipTests -f api-gateway/pom.xml
mvn clean package -DskipTests -f user-service/pom.xml
mvn clean package -DskipTests -f product-service/pom.xml

# Build and push multi-arch Docker images to DockerHub
echo -e "${YELLOW}Building and pushing multi-arch Docker images...${NC}"
DOCKERHUB_USERNAME=${DOCKERHUB_USERNAME:-esara}
IMAGE_TAG=${IMAGE_TAG:-latest}

if [ "$DOCKERHUB_USERNAME" = "your-username" ]; then
    echo -e "${YELLOW}Warning: DOCKERHUB_USERNAME not set. Using 'your-username'. Set it via: export DOCKERHUB_USERNAME=your-username${NC}"
fi

echo -e "${YELLOW}Using DockerHub username: ${DOCKERHUB_USERNAME}, Image tag: ${IMAGE_TAG}${NC}"

# Setup buildx if needed
docker buildx create --name multiarch --use 2>/dev/null || docker buildx use multiarch
docker buildx inspect --bootstrap

# Build and push images
docker buildx build --platform linux/amd64,linux/arm64 \
    -t ${DOCKERHUB_USERNAME}/api-gateway:${IMAGE_TAG} \
    --push ./api-gateway

docker buildx build --platform linux/amd64,linux/arm64 \
    -t ${DOCKERHUB_USERNAME}/user-service:${IMAGE_TAG} \
    --push ./user-service

docker buildx build --platform linux/amd64,linux/arm64 \
    -t ${DOCKERHUB_USERNAME}/product-service:${IMAGE_TAG} \
    --push ./product-service

# Check for Helm
command -v helm >/dev/null 2>&1 || { echo "helm is required but not installed. Aborting." >&2; exit 1; }

# Deploy using Helm
echo -e "${YELLOW}Deploying with Helm...${NC}"
NAMESPACE=${NAMESPACE:-cloakworks}
helm upgrade --install --namespace ${NAMESPACE} --create-namespace keycloak-microservices ./helm/keycloak-microservices

# Wait for Keycloak
echo -e "${YELLOW}Waiting for Keycloak to be ready...${NC}"
kubectl wait --for=condition=available --timeout=300s deployment/keycloak -n ${NAMESPACE} || true

echo -e "${GREEN}✅ Deployment complete!${NC}"
echo ""
echo "Next steps:"
echo "1. Configure Keycloak (see keycloak-setup.md)"
echo "2. Port forward services:"
echo "   kubectl port-forward svc/keycloak 8080:8080 -n ${NAMESPACE}"
echo "   kubectl port-forward svc/api-gateway 8080:8080 -n ${NAMESPACE}"
echo "3. Get access token and test the APIs"

