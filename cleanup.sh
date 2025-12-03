#!/bin/bash

# Cleanup script for K8s API Demo

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}K8s API Demo - Cleanup${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Delete namespace (this removes all resources)
print_info "Deleting demo-app namespace and all resources..."
kubectl delete namespace demo-app --ignore-not-found=true

print_success "Namespace deleted"

# Ask about NGINX Ingress
read -p "Do you want to remove NGINX Ingress Controller? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_info "Removing NGINX Ingress Controller..."
    kubectl delete namespace ingress-nginx --ignore-not-found=true
    print_success "NGINX Ingress removed"
else
    print_info "Keeping NGINX Ingress Controller"
fi

# Ask about /etc/hosts
read -p "Do you want to remove api.local from /etc/hosts? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_info "Removing api.local from /etc/hosts (requires sudo)..."
    sudo sed -i '' '/api.local/d' /etc/hosts 2>/dev/null || true
    print_success "/etc/hosts updated"
else
    print_info "Keeping api.local in /etc/hosts"
fi

echo ""
print_success "Cleanup complete!"
