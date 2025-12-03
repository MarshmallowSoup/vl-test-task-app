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

# Function to print colored messages
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
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

# Check if nerdctl is available (Rancher Desktop uses nerdctl)
check_container_runtime() {
    print_info "Checking container runtime..."
    
    if command -v nerdctl &> /dev/null; then
        CONTAINER_CMD="nerdctl"
        print_success "Using nerdctl (Rancher Desktop)"
    elif command -v docker &> /dev/null; then
        CONTAINER_CMD="docker"
        print_success "Using docker"
    else
        print_error "Neither nerdctl nor docker is available"
        exit 1
    fi
}

# Build the API Docker image
build_api_image() {
    print_info "Building API Docker image..."
    cd api
    
    # For Rancher Desktop, use the k8s.io namespace
    if [ "$CONTAINER_CMD" = "nerdctl" ]; then
        nerdctl -n k8s.io build -t "$API_IMAGE_NAME" .
    else
        docker build -t "$API_IMAGE_NAME" .
    fi
    
    cd ..
    print_success "API image built successfully"
}

# Install NGINX Ingress Controller if not present
install_nginx_ingress() {
    print_info "Checking NGINX Ingress Controller..."
    
    if kubectl get namespace ingress-nginx &> /dev/null; then
        print_warning "NGINX Ingress already installed"
    else
        print_info "Installing NGINX Ingress Controller..."
        kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.5/deploy/static/provider/cloud/deploy.yaml
        
        print_info "Waiting for NGINX Ingress Controller to be ready..."
        kubectl wait --namespace ingress-nginx \
            --for=condition=ready pod \
            --selector=app.kubernetes.io/component=controller \
            --timeout=120s
        
        print_success "NGINX Ingress Controller installed"
    fi
}

# Create namespace
create_namespace() {
    print_info "Creating namespace..."
    kubectl apply -f k8s/namespace.yaml
    print_success "Namespace created/verified"
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
    
    # Get Ingress port
    INGRESS_PORT=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.spec.ports[?(@.name=="http")].nodePort}')
    
    if [ -z "$INGRESS_PORT" ]; then
        # If NodePort is not available, try LoadBalancer port
        INGRESS_PORT=80
    fi
    
    print_success "Application is ready!"
    echo ""
    print_info "Access URLs:"
    echo -e "  ${GREEN}http://$INGRESS_HOST${NC}"
    echo ""
    
    print_info "Test endpoints:"
    echo -e "  ${YELLOW}Health Check:${NC}      curl http://$INGRESS_HOST/health"
    echo -e "  ${YELLOW}API Info:${NC}          curl http://$INGRESS_HOST/"
    echo -e "  ${YELLOW}Echo Test:${NC}         curl -X POST http://$INGRESS_HOST/echo -H 'Content-Type: application/json' -d '{\"test\":\"hello\"}'"
    echo -e "  ${YELLOW}Get Messages:${NC}      curl http://$INGRESS_HOST/messages"
    echo -e "  ${YELLOW}Create Message:${NC}    curl -X POST http://$INGRESS_HOST/messages -H 'Content-Type: application/json' -d '{\"text\":\"Hello from K8s!\",\"author\":\"Demo\"}'"
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
    check_container_runtime
    
    # Build and deploy
    build_api_image
    install_nginx_ingress
    create_namespace
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
