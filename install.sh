#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="demo-app"
API_IMAGE_NAME="k8s-api-demo:latest"
INGRESS_HOST="api.local"
ENV_FILE=".env"
DOCKER_SECRET_NAME="docker-registry-secret"

# Function to print colored messages
print_info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

print_success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

print_error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

# Check if kubectl is available
check_kubectl() {
    print_info "Checking if kubectl is available..."
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    print_success "kubectl is available"
}

# Check if Kubernetes cluster is accessible
check_cluster() {
    print_info "Checking Kubernetes cluster connectivity..."
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        print_info "Make sure Rancher Desktop is running and Kubernetes is enabled"
        exit 1
    fi
    print_success "Connected to Kubernetes cluster"
    kubectl cluster-info | head -1
}

# Verify API image exists
verify_api_image() {
    print_info "Verifying API Docker image exists..."
    
    # Check with nerdctl first (Rancher Desktop)
    if command -v nerdctl &> /dev/null; then
        if nerdctl -n k8s.io images | grep -q "$API_IMAGE_NAME"; then
            print_success "API image found (nerdctl)"
            return 0
        fi
    fi
    
    # Check with docker
    if command -v docker &> /dev/null; then
        if docker images | grep -q "k8s-api-demo"; then
            print_success "API image found (docker)"
            return 0
        fi
    fi
    
    print_warning "API image '$API_IMAGE_NAME' not found locally"
    print_info "Assuming image will be pulled or is available in the cluster"
}

# Verify NGINX Ingress Controller exists
verify_nginx_ingress() {
    print_info "Verifying NGINX Ingress Controller..."
    
    if kubectl get namespace ingress-nginx &> /dev/null; then
        if kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller &> /dev/null; then
            print_success "NGINX Ingress Controller is present"
        else
            print_warning "NGINX Ingress namespace exists but controller not found"
        fi
    else
        print_warning "NGINX Ingress Controller not found - please install it manually"
        print_info "Run: kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.5/deploy/static/provider/cloud/deploy.yaml"
    fi
}

# Verify namespace exists
verify_namespace() {
    print_info "Verifying namespace exists..."
    if kubectl get namespace "$NAMESPACE" &> /dev/null; then
        print_success "Namespace '$NAMESPACE' exists"
    else
        print_warning "Namespace '$NAMESPACE' not found, creating it..."
        kubectl apply -f k8s/namespace.yaml
        print_success "Namespace created"
    fi
}

# Create Docker registry secret from .env file
create_docker_secret() {
    print_info "Creating Docker registry secret..."
    
    # Check if .env file exists
    if [ ! -f "$ENV_FILE" ]; then
        print_warning ".env file not found - skipping Docker registry secret creation"
        print_info "If you need to pull images from a private registry, create a .env file with:"
        print_info "  DOCKER_REGISTRY_SERVER=https://index.docker.io/v1/"
        print_info "  DOCKER_USERNAME=your-username"
        print_info "  DOCKER_PASSWORD=your-password"
        print_info "  DOCKER_EMAIL=your-email@example.com"
        return 0
    fi
    
    # Source the .env file
    source "$ENV_FILE"
    
    # Validate required variables
    if [ -z "$DOCKER_USERNAME" ] || [ -z "$DOCKER_PASSWORD" ]; then
        print_warning "DOCKER_USERNAME or DOCKER_PASSWORD not set in .env file"
        print_info "Skipping Docker registry secret creation"
        return 0
    fi
    
    # Set defaults if not provided
    DOCKER_REGISTRY_SERVER=${DOCKER_REGISTRY_SERVER:-"https://index.docker.io/v1/"}
    DOCKER_EMAIL=${DOCKER_EMAIL:-"noreply@example.com"}
    
    # Delete existing secret if it exists
    kubectl delete secret "$DOCKER_SECRET_NAME" -n "$NAMESPACE" --ignore-not-found=true
    
    # Create the secret
    kubectl create secret docker-registry "$DOCKER_SECRET_NAME" \
        --docker-server="$DOCKER_REGISTRY_SERVER" \
        --docker-username="$DOCKER_USERNAME" \
        --docker-password="$DOCKER_PASSWORD" \
        --docker-email="$DOCKER_EMAIL" \
        -n "$NAMESPACE"
    
    print_success "Docker registry secret created"
}

# Deploy MongoDB
deploy_mongodb() {
    print_info "Deploying MongoDB..."
    kubectl apply -f k8s/mongodb.yaml
    
    print_info "Waiting for MongoDB to be ready..."
    kubectl wait --namespace "$NAMESPACE" \
        --for=condition=ready pod \
        --selector=app=mongodb \
        --timeout=120s
    
    print_success "MongoDB is ready"
}

# Deploy API
deploy_api() {
    print_info "Deploying API application..."
    kubectl apply -f k8s/api.yaml
    
    print_info "Waiting for API pods to be ready..."
    kubectl wait --namespace "$NAMESPACE" \
        --for=condition=ready pod \
        --selector=app=api \
        --timeout=120s
    
    print_success "API is ready"
}

# Deploy Ingress
deploy_ingress() {
    print_info "Deploying Ingress..."
    kubectl apply -f k8s/ingress.yaml
    print_success "Ingress deployed"
}

# Configure /etc/hosts
configure_hosts() {
    print_info "Checking /etc/hosts configuration..."
    
    if grep -q "$INGRESS_HOST" /etc/hosts 2>/dev/null; then
        print_warning "$INGRESS_HOST already in /etc/hosts"
    else
        print_info "Adding $INGRESS_HOST to /etc/hosts (requires sudo)..."
        echo "127.0.0.1 $INGRESS_HOST" | sudo tee -a /etc/hosts > /dev/null
        print_success "Added $INGRESS_HOST to /etc/hosts"
    fi
}

# Get access information
get_access_info() {
    print_header "Deployment Complete!"
    
    print_success "Application is ready!"
    echo ""
    
    print_info "Access URLs:"
    echo "  For Rancher Desktop, use port-forward to access the application:"
    echo ""
    echo "  Run this command in a separate terminal:"
    echo -e "  ${GREEN}kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80${NC}"
    echo ""
    echo "  Then access the API at: http://localhost:8080"
    echo ""
    
    print_info "Test endpoints (using port-forward on port 8080):"
    echo -e "  ${YELLOW}Health Check:${NC}      curl http://localhost:8080/health -H 'Host: api.local'"
    echo -e "  ${YELLOW}API Info:${NC}          curl http://localhost:8080/ -H 'Host: api.local'"
    echo -e "  ${YELLOW}Echo Test:${NC}         curl -X POST http://localhost:8080/echo -H 'Host: api.local' -H 'Content-Type: application/json' -d '{\"test\":\"hello\"}'"
    echo -e "  ${YELLOW}Get Messages:${NC}      curl http://localhost:8080/messages -H 'Host: api.local'"
    echo -e "  ${YELLOW}Create Message:${NC}    curl -X POST http://localhost:8080/messages -H 'Host: api.local' -H 'Content-Type: application/json' -d '{\"text\":\"Hello from K8s!\",\"author\":\"Demo\"}'"
    echo ""
    
    print_info "Alternative: Direct service access via port-forward:"
    echo "  kubectl port-forward -n demo-app svc/api 8081:80"
    echo "  curl http://localhost:8081/health"
    echo ""
    
    print_info "Kubernetes Resources:"
    echo -e "  ${YELLOW}View pods:${NC}         kubectl get pods -n $NAMESPACE"
    echo -e "  ${YELLOW}View services:${NC}     kubectl get svc -n $NAMESPACE"
    echo -e "  ${YELLOW}View ingress:${NC}      kubectl get ingress -n $NAMESPACE"
    echo -e "  ${YELLOW}API logs:${NC}          kubectl logs -n $NAMESPACE -l app=api -f"
    echo -e "  ${YELLOW}MongoDB logs:${NC}      kubectl logs -n $NAMESPACE -l app=mongodb -f"
    echo ""
}

# Show deployment status
show_status() {
    print_header "Deployment Status"
    
    echo "Pods:"
    kubectl get pods -n "$NAMESPACE"
    echo ""
    
    echo "Services:"
    kubectl get svc -n "$NAMESPACE"
    echo ""
    
    echo "Ingress:"
    kubectl get ingress -n "$NAMESPACE"
    echo ""
}

# Main installation flow
main() {
    print_header "K8s API Demo - Installation Script"
    
    # Preflight checks
    check_kubectl
    check_cluster
    verify_api_image
    verify_nginx_ingress
    
    # Deploy
    verify_namespace
    create_docker_secret
    deploy_mongodb
    deploy_api
    deploy_ingress
    configure_hosts
    
    # Show results
    show_status
    get_access_info
}

# Run main function
main
