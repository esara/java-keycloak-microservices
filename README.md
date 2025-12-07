# Java Keycloak Microservices Demo

This project demonstrates multiple Java-based microservices using a self-hosted Keycloak service for authentication, all running in Kubernetes.

## Architecture

The project consists of:
- **API Gateway**: Spring Cloud Gateway that routes requests and validates JWT tokens
- **User Service**: Microservice for user management
- **Product Service**: Microservice for product management
- **Keycloak**: Self-hosted authentication and authorization server
- **PostgreSQL**: Database for Keycloak

## Prerequisites

- Java 17 or higher
- Maven 3.6+
- Docker
- Kubernetes cluster (minikube, kind, or cloud-based)
- kubectl configured
- Helm 3.0+

## Project Structure

```
java-keycloak-microservices/
├── api-gateway/          # Spring Cloud Gateway
├── user-service/         # User management service
├── product-service/      # Product management service
├── helm/                # Helm chart
└── docs/                # Documentation
```

## Quick Start

### 1. Build and Push Docker Images

```bash
# Build all services
mvn clean package -DskipTests

# Set your DockerHub username (optional, defaults to 'esara')
export DOCKERHUB_USERNAME=your-username

# Set image tag (optional, defaults to 'latest')
export IMAGE_TAG=latest

# Build and push multi-arch images (amd64 and arm64)
make docker-setup-buildx
make docker-build

# Or override variables directly:
# make docker-build DOCKERHUB_USERNAME=your-username IMAGE_TAG=1.0.0
```

### 2. Install CloudNativePG Operator (Prerequisite)

CloudNativePG is required for PostgreSQL management:

```bash
helm upgrade --install cnpg --create-namespace --namespace cloakworks cloudnative-pg --repo https://cloudnative-pg.github.io/charts
```

### 3. Deploy Using Helm

All services will be deployed in a single namespace:

```bash
helm upgrade --install --namespace cloakworks --create-namespace keycloak-microservices ./helm/keycloak-microservices

# Wait for PostgreSQL cluster to be ready
kubectl wait --for=condition=ready --timeout=300s cluster/postgres -n cloakworks

# Wait for Keycloak to be ready
kubectl wait --for=condition=available --timeout=300s deployment/keycloak -n cloakworks
```

### 4. Configure Keycloak

#### Prerequisites

- Keycloak deployed and running in Kubernetes
- Access to Keycloak admin console

#### Step 1: Access Keycloak Admin Console

1. Port forward the Keycloak service:
   ```bash
   kubectl port-forward svc/keycloak 8080:8080 -n cloakworks
   ```

2. Open http://localhost:8080 in your browser

3. Login with:
   - Username: `admin`
   - Password: `admin`

#### Step 2: Create a Realm

1. Click on the realm dropdown (top left, shows "master")
2. Click "Create Realm"
3. Enter realm name: `microservices`
4. Click "Create"

#### Step 3: Create a Client

1. In the left sidebar, go to "Clients"
2. Click "Create client"
3. Configure:
   - **Client type**: OpenID Connect
   - **Client ID**: `api-gateway`
   - Click "Next"
4. Capability config:
   - Enable "Client authentication": OFF (Public client)
   - Enable "Authorization": OFF
   - **Enable "Direct access grants"**: ON (this allows password grant type)
   - Click "Next"
5. Login settings:
   - **Valid redirect URIs**: `*`
   - **Web origins**: `*`
   - Click "Save"
   **Note**: "Direct access grants" enables the password grant type (username/password authentication) for this client.

#### Step 4: Create Users (Optional)

1. Go to "Users" in the left sidebar
2. Click "Create new user"
3. Fill in:
   - **Username**: `testuser`
   - **Email**: `testuser@example.com`
   - **First name**: `Test`
   - **Last name**: `User`
   - Enable "Email verified"
4. Go to "Credentials" tab
5. Set password: `testpass`
6. Disable "Temporary"
7. Click "Set password"

### 5. Get Access Token

#### Using curl:

```bash
# Get token using password grant
curl -k -X POST "https://localhost:8443/realms/microservices/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=testuser" \
  -d "password=testpass" \
  -d "grant_type=password" \
  -d "client_id=api-gateway" | jq -r '.access_token'
```

#### Using Keycloak Admin Console:

1. Go to "Clients" → `api-gateway`
2. Go to "Client scopes" tab
3. Use the token endpoint URL shown

### 6. Test the Services

```bash
# Set the token
export TOKEN="<your-token-here>"

# Test API Gateway (using port-forward if ClusterIP)
kubectl port-forward svc/api-gateway 8080:8080 -n cloakworks &
curl -H "Authorization: Bearer $TOKEN" http://localhost:8080/api/users
curl -H "Authorization: Bearer $TOKEN" http://localhost:8080/api/products
```

Or if using LoadBalancer services:

```bash
# Get API Gateway LoadBalancer IP
export API_GATEWAY_IP=$(kubectl get svc api-gateway -n cloakworks -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Test with token
curl -H "Authorization: Bearer $TOKEN" http://${API_GATEWAY_IP}:8080/api/users
curl -H "Authorization: Bearer $TOKEN" http://${API_GATEWAY_IP}:8080/api/products
```

## Services

### API Gateway (Port 8080)
- Routes requests to backend services
- Validates JWT tokens from Keycloak
- Endpoints:
  - `/api/users/*` → User Service
  - `/api/products/*` → Product Service

### User Service (Port 8080)
- User management operations
- Protected by Keycloak authentication
- Endpoints:
  - `GET /users` - List all users
  - `GET /users/{id}` - Get user by ID
  - `POST /users` - Create user

### Product Service (Port 8080)
- Product management operations
- Protected by Keycloak authentication
- Endpoints:
  - `GET /products` - List all products
  - `GET /products/{id}` - Get product by ID
  - `POST /products` - Create product

## Helm Chart Configuration

### Image Registry

By default, microservices images are pulled from DockerHub using the `esara` registry:
- `esara/api-gateway:latest`
- `esara/user-service:latest`
- `esara/product-service:latest`

To use a different registry:
```bash
helm upgrade --install --namespace cloakworks --create-namespace keycloak-microservices ./helm/keycloak-microservices \
  --set global.imageRegistry=myregistry.io
```

### Service Types

By default, all services use `ClusterIP`. To use `LoadBalancer` services:

**Option 1: Using values file**
```yaml
keycloak:
  service:
    type: LoadBalancer

apiGateway:
  service:
    type: LoadBalancer
```

**Option 2: Using command line flags**
```bash
helm upgrade --install --namespace cloakworks --create-namespace keycloak-microservices ./helm/keycloak-microservices \
  --set keycloak.service.type=LoadBalancer \
  --set apiGateway.service.type=LoadBalancer
```

### Access Services

**ClusterIP (Default):**
```bash
export NAMESPACE=cloakworks

# Port-forward services
kubectl port-forward svc/keycloak 8443:8443 -n $NAMESPACE
kubectl port-forward svc/api-gateway 8080:8080 -n $NAMESPACE
```

**LoadBalancer:**
```bash
# Wait for LoadBalancer IPs to be assigned (may take a few minutes)
kubectl get svc -n $NAMESPACE -w

# Get service IPs
kubectl get svc keycloak -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
kubectl get svc api-gateway -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

### Configurable Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.imageRegistry` | Docker image registry for microservices | `esara` |
| `global.keycloakRealm` | Keycloak realm name | `microservices` |
| `global.keycloakClientId` | Keycloak client ID | `api-gateway` |
| `keycloak.enabled` | Enable Keycloak deployment | `true` |
| `keycloak.service.type` | Keycloak service type | `ClusterIP` |
| `keycloak.admin.username` | Keycloak admin username | `admin` |
| `keycloak.admin.password` | Keycloak admin password | `admin` |
| `postgresql.enabled` | Enable PostgreSQL deployment | `true` |
| `postgresql.instances` | Number of PostgreSQL instances | `1` |
| `postgresql.storage.size` | PostgreSQL storage size | `10Gi` |
| `postgresql.enableSuperuserAccess` | Enable superuser access | `true` |
| `apiGateway.enabled` | Enable API Gateway | `true` |
| `apiGateway.replicas` | API Gateway replica count | `2` |
| `apiGateway.service.type` | API Gateway service type | `ClusterIP` |
| `userService.enabled` | Enable User Service | `true` |
| `userService.replicas` | User Service replica count | `2` |
| `userService.service.type` | User Service service type | `ClusterIP` |
| `productService.enabled` | Enable Product Service | `true` |
| `productService.replicas` | Product Service replica count | `2` |
| `productService.service.type` | Product Service service type | `ClusterIP` |

### Configuring Resources

By default, resources are set to empty `{}`, which means Kubernetes will use cluster defaults. To configure resources:

**Using values file:**
```yaml
keycloak:
  resources:
    requests:
      memory: "512Mi"
      cpu: "500m"
    limits:
      memory: "1Gi"
      cpu: "1000m"

apiGateway:
  resources:
    requests:
      memory: "256Mi"
      cpu: "250m"
    limits:
      memory: "512Mi"
      cpu: "500m"
```

**Using command line:**
```bash
helm upgrade --install --namespace cloakworks --create-namespace keycloak-microservices ./helm/keycloak-microservices \
  --set keycloak.resources.requests.memory=512Mi \
  --set keycloak.resources.limits.memory=1Gi
```

### Custom Installation

Install with custom values:
```bash
helm upgrade --install --namespace cloakworks --create-namespace keycloak-microservices ./helm/keycloak-microservices \
  --set keycloak.admin.password=mySecurePassword \
  --set apiGateway.replicas=3
```

Or use a custom values file:
```bash
helm upgrade --install --namespace cloakworks --create-namespace keycloak-microservices ./helm/keycloak-microservices \
  -f my-values.yaml
```

## Helm Chart Management

### Upgrading

```bash
helm upgrade keycloak-microservices ./helm/keycloak-microservices --namespace cloakworks
```

### Uninstallation

```bash
helm uninstall keycloak-microservices --namespace cloakworks
```

This will remove all resources created by the chart.

### Validation

```bash
# Lint the chart
helm lint ./helm/keycloak-microservices

# Dry run
helm install keycloak-microservices ./helm/keycloak-microservices --dry-run --debug --namespace cloakworks
```

## Development

### Running Locally

1. Start Keycloak:
   ```bash
   docker run -p 8080:8080 -e KEYCLOAK_ADMIN=admin -e KEYCLOAK_ADMIN_PASSWORD=admin quay.io/keycloak/keycloak:latest start-dev
   ```

2. Configure Keycloak (see step 3 above)

3. Run services:
   ```bash
   cd api-gateway && mvn spring-boot:run
   cd user-service && mvn spring-boot:run
   cd product-service && mvn spring-boot:run
   ```

## Troubleshooting

### Check Pod Status
```bash
kubectl get pods -n cloakworks
```

### View Logs
```bash
kubectl logs -f deployment/keycloak -n cloakworks
kubectl logs -f deployment/api-gateway -n cloakworks
```

### Check Services
```bash
kubectl get svc -n cloakworks
```

### Check Service Endpoints
```bash
kubectl get endpoints -n cloakworks
```

### Common Issues

- **Keycloak not accessible**: Verify the service is running and check if using ClusterIP (requires port-forward) or LoadBalancer
- **Token validation fails**: Check that the realm name matches `microservices` and client ID is `api-gateway`
- **Services can't connect**: Verify all services are in the same namespace and check service names

#### Keycloak-Specific Troubleshooting

**Token validation fails:**
- Check that the issuer URI matches: `http://keycloak.cloakworks.svc.cluster.local:8080/realms/microservices`
- Verify the realm name is exactly `microservices`
- Check service logs for JWT validation errors

**Cannot connect to Keycloak:**
- Verify Keycloak pod is running: `kubectl get pods -n cloakworks`
- Check Keycloak logs: `kubectl logs -f deployment/keycloak -n cloakworks`
- Verify PostgreSQL is running: `kubectl get pods -n cloakworks`

**CORS issues:**
- Ensure Web origins is set to `*` in client configuration
- Check API Gateway CORS configuration in `application.yml`

## License

MIT
