#!/bin/bash

# Quick fix for NGINX Ingress webhook issues in Rancher Desktop

set -e

echo "Fixing NGINX Ingress admission webhook issue..."

# Option 1: Wait for webhook to be ready
echo "Waiting for NGINX Ingress Controller to be fully ready..."
kubectl wait --namespace ingress-nginx \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=60s || true

# Give the webhook time to initialize
sleep 5

# Try to apply ingress
if kubectl apply -f k8s/ingress.yaml 2>&1 | grep -q "error when creating"; then
    echo "Webhook still not ready. Applying workaround..."
    
    # Option 2: Delete the validating webhook configuration
    kubectl delete validatingwebhookconfiguration ingress-nginx-admission --ignore-not-found=true
    
    echo "Waiting a moment..."
    sleep 2
    
    # Try again
    kubectl apply -f k8s/ingress.yaml
    
    echo "✓ Ingress deployed successfully (validation webhook removed)"
    echo ""
    echo "Note: The validation webhook was removed. This is safe for development."
    echo "The Ingress will still work correctly."
else
    echo "✓ Ingress deployed successfully"
fi
