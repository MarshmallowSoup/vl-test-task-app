# Kubernetes API Demo with MongoDB

A complete demonstration of deploying a containerized API application with MongoDB on Kubernetes using Rancher Desktop, featuring NGINX Ingress for traffic routing.

## 📋 Overview

This project includes:
- **Node.js API**: Express-based REST API with MongoDB integration
- **MongoDB Database**: StatefulSet deployment with persistent storage
- **NGINX Ingress**: API gateway for HTTP traffic routing
- **Automated Deployment**: One-command installation script

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────┐
│              NGINX Ingress Controller           │
│               (api.local → API)                 │
└─────────────────┬───────────────────────────────┘
                  │
    ┌─────────────┴─────────────┐
    │                           │
┌───▼────────┐         ┌────────▼──────┐
│   API      │────────►│   MongoDB     │
│ (2 pods)   │         │ (StatefulSet) │
└────────────┘         └───────────────┘
```

## 📦 Components

### API Application
- **Framework**: Express.js (Node.js 18)
- **Features**: Health checks, echo endpoint, MongoDB CRUD operations
- **Deployment**: 2 replicas with resource limits
- **Probes**: Liveness and readiness checks

### MongoDB Database
- **Version**: MongoDB 7.0
- **Deployment**: StatefulSet for stable network identity
- **Storage**: 1GB PersistentVolumeClaim
- **Resources**: 256Mi-512Mi memory, 250m-500m CPU

### NGINX Ingress
- **Route**: `api.local` → API service
- **Path**: `/` (all paths)
- **Type**: Prefix-based routing

## 🚀 Quick Start

### Prerequisites
- **Rancher Desktop** installed and running
- Kubernetes enabled in Rancher Desktop
- `kubectl` available in PATH
- Minimum 2GB RAM available for cluster

### Installation

Run the automated installation script:

```bash
./install.sh
```

The script will:
1. ✅ Check Kubernetes connectivity
2. 🔨 Build the API Docker image
3. 📥 Install NGINX Ingress Controller (if needed)
4. 🚀 Deploy MongoDB StatefulSet
5. 🚀 Deploy API application
6. 🌐 Configure Ingress routing
7. 📝 Update `/etc/hosts` for `api.local`
8. ⏳ Wait for all pods to be ready
9. 📊 Display access information

## 🔌 API Endpoints

### Accessing the API

With Rancher Desktop, you need to use port-forwarding to access the Ingress Controller:

```bash
# Start port forwarding (keep this running in a terminal)
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80
```

Then access the API at `http://localhost:8080` with the `Host: api.local` header.

### Available Endpoints

#### Health Check
```bash
curl http://localhost:8080/health -H 'Host: api.local'
```
Response:
```json
{
  "status": "healthy",
  "timestamp": "2025-12-03T19:00:00.000Z",
  "mongodb": "connected"
}
```

#### API Info
```bash
curl http://localhost:8080/ -H 'Host: api.local'
```

#### Echo Test
```bash
curl -X POST http://localhost:8080/echo \
  -H 'Host: api.local' \
  -H 'Content-Type: application/json' \
  -d '{"test":"hello","message":"world"}'
```

#### Get Messages
```bash
curl http://localhost:8080/messages -H 'Host: api.local'
```

#### Create Message
```bash
curl -X POST http://localhost:8080/messages \
  -H 'Host: api.local' \
  -H 'Content-Type: application/json' \
  -d '{"text":"Hello from Kubernetes!","author":"Demo User"}'
```

### Alternative: Direct Service Access

You can also bypass the Ingress and access the API service directly:

```bash
# Port forward to the API service
kubectl port-forward -n demo-app svc/api 8081:80

# Access without Host header
curl http://localhost:8081/health
```

## 🛠️ Management Commands

### View Resources
```bash
# View all pods in demo-app namespace
kubectl get pods -n demo-app

# View services
kubectl get svc -n demo-app

# View ingress
kubectl get ingress -n demo-app

# Describe API deployment
kubectl describe deployment api -n demo-app

# Describe MongoDB StatefulSet
kubectl describe statefulset mongodb -n demo-app
```

### View Logs
```bash
# API logs (all pods)
kubectl logs -n demo-app -l app=api -f

# MongoDB logs
kubectl logs -n demo-app -l app=mongodb -f

# Specific pod logs
kubectl logs -n demo-app <pod-name>
```

### Scaling
```bash
# Scale API to 3 replicas
kubectl scale deployment api -n demo-app --replicas=3

# Verify scaling
kubectl get pods -n demo-app -l app=api
```

### Restart Deployments
```bash
# Restart API deployment
kubectl rollout restart deployment api -n demo-app

# Check rollout status
kubectl rollout status deployment api -n demo-app
```

## 📂 Project Structure

```
.
├── api/
│   ├── server.js           # Express API application
│   ├── package.json        # Node.js dependencies
│   ├── Dockerfile          # Container image definition
│   └── .dockerignore       # Docker build exclusions
│
├── k8s/
│   ├── namespace.yaml      # Namespace definition
│   ├── mongodb.yaml        # MongoDB StatefulSet, Service, PVC
│   ├── api.yaml            # API Deployment and Service
│   └── ingress.yaml        # NGINX Ingress configuration
│
├── install.sh              # Automated installation script
└── README.md               # This file
```

## 🔧 Configuration

### Environment Variables (API)
- `PORT`: HTTP server port (default: 3000)
- `MONGO_URL`: MongoDB connection string
- `DB_NAME`: Database name (default: demoapp)

### Resource Limits

**API Pod:**
- Requests: 128Mi memory, 100m CPU
- Limits: 256Mi memory, 200m CPU

**MongoDB Pod:**
- Requests: 256Mi memory, 250m CPU
- Limits: 512Mi memory, 500m CPU

## 🧪 Testing

### Test MongoDB Connectivity
```bash
# Port-forward to MongoDB
kubectl port-forward -n demo-app svc/mongodb 27017:27017

# Connect with mongosh (in another terminal)
mongosh mongodb://localhost:27017/demoapp
```

### Test API Directly (without Ingress)
```bash
# Port-forward to API
kubectl port-forward -n demo-app svc/api 8080:80

# Test in another terminal
curl http://localhost:8080/health
```

### End-to-End Test
```bash
# Create a message
curl -X POST http://api.local/messages \
  -H 'Content-Type: application/json' \
  -d '{"text":"E2E test message","author":"Tester"}'

# Retrieve messages
curl http://api.local/messages
```

## 🗑️ Cleanup

### Remove Everything
```bash
# Delete namespace (removes all resources)
kubectl delete namespace demo-app

# Remove NGINX Ingress (optional)
kubectl delete namespace ingress-nginx

# Remove from /etc/hosts (requires sudo)
sudo sed -i '' '/api.local/d' /etc/hosts
```

### Rebuild and Redeploy
```bash
# If you make changes to the API code
cd api
nerdctl -n k8s.io build -t k8s-api-demo:latest .

# Restart the deployment to use new image
kubectl rollout restart deployment api -n demo-app
```

## 🐛 Troubleshooting

### Pods Not Starting
```bash
# Check pod status
kubectl get pods -n demo-app

# Describe pod for events
kubectl describe pod <pod-name> -n demo-app

# Check logs
kubectl logs <pod-name> -n demo-app
```

### Ingress Not Working
```bash
# Check ingress status
kubectl get ingress -n demo-app

# Verify NGINX Ingress Controller
kubectl get pods -n ingress-nginx

# Check if api.local is in /etc/hosts
cat /etc/hosts | grep api.local

# Test with curl verbose
curl -v http://api.local/health
```

### MongoDB Connection Issues
```bash
# Check MongoDB pod
kubectl get pod -n demo-app -l app=mongodb

# Check MongoDB logs
kubectl logs -n demo-app -l app=mongodb

# Verify service
kubectl get svc -n demo-app mongodb
```

### Image Pull Issues (Rancher Desktop)
```bash
# Verify image exists in nerdctl
nerdctl -n k8s.io images | grep k8s-api-demo

# If missing, rebuild
cd api
nerdctl -n k8s.io build -t k8s-api-demo:latest .
```

## 📚 Additional Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Rancher Desktop](https://rancherdesktop.io/)
- [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/)
- [MongoDB on Kubernetes](https://www.mongodb.com/kubernetes)
- [Express.js Guide](https://expressjs.com/)

## 🎯 Features Demonstrated

✅ Container image building with Docker/nerdctl  
✅ Kubernetes Deployments with multiple replicas  
✅ StatefulSets for stateful applications  
✅ PersistentVolumeClaims for data persistence  
✅ Services for internal networking  
✅ Ingress for external access  
✅ ConfigMap via environment variables  
✅ Resource requests and limits  
✅ Liveness and readiness probes  
✅ Labels and selectors  
✅ Namespace isolation  
✅ Automated deployment scripts  

## 📝 License

This is a demonstration project for educational purposes.

---

**Built with ❤️ for Kubernetes learning**
