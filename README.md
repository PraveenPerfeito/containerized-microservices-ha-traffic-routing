# Containerized Microservices with High Availability and Smart Traffic Routing

> **SkillfyBank** — Docker Production-Level Assignment #1

---

## Scenario

You are a **DevOps Engineer at SkillfyBank**, a digital banking company running a microservices-based core banking platform. After multiple incidents due to poor deployment strategies and scaling issues, you are tasked with **re-architecting and deploying** the platform using **Docker, Docker Swarm, Kubernetes, and Istio**.

---

## Services

| Service | Stack | Port |
|---|---|---|
| Account Service | Node.js (Express) | 3000 |
| Transaction Service | Spring Boot (Java 17) | 8080 |
| Notification Service | Python Flask + Gunicorn | 5000 |

---

## Project Structure

```
.
├── account-service/
│   ├── app.js
│   ├── package.json
│   ├── Dockerfile
│   └── .dockerignore
├── transaction-service/
│   ├── src/main/java/com/skillfybank/transaction/
│   │   ├── TransactionApplication.java
│   │   └── controller/TransactionController.java
│   ├── src/main/resources/application.properties
│   ├── pom.xml
│   ├── Dockerfile
│   └── .dockerignore
├── notification-service/
│   ├── app.py
│   ├── requirements.txt
│   ├── Dockerfile
│   └── .dockerignore
├── docker-compose.yml
├── swarm/
│   ├── docker-stack.yml
│   └── setup-swarm.sh
├── kubernetes/
│   ├── namespace.yaml
│   ├── configmap.yaml
│   ├── secrets.yaml
│   ├── account/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── pv.yaml
│   │   └── pvc.yaml
│   ├── transaction/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── hpa.yaml
│   └── notification/
│       ├── deployment.yaml
│       └── service.yaml
└── istio/
    ├── peer-authentication.yaml
    ├── transaction-vs-dr.yaml
    ├── notification-vs-dr.yaml
    └── jaeger-tracing.yaml
```

---

## PART 1: Docker — Containerize Banking Microservices

### Goals
1. Create Dockerfiles for all three services
2. Optimize image sizes using best practices (multi-stage builds, `.dockerignore`, layer caching)
3. Push all 3 Docker images to DockerHub
4. Use Docker networking to allow containers to communicate
5. Configure port mapping for external access to Account and Notification services only
6. Simulate a broken image push (tag mismatch or error in Dockerfile) and troubleshoot it

### Build & Run Locally

```bash
# Build and start all services
docker compose up --build

# Run in background
docker compose up --build -d

# Check running containers
docker ps

# Check logs
docker logs account-service
docker logs transaction-service
docker logs notification-service

# Stop all services
docker compose down
```

### Build Individual Images

```bash
# Account Service
docker build -t skillfybank/account-service:latest ./account-service

# Transaction Service
docker build -t skillfybank/transaction-service:latest ./transaction-service

# Notification Service
docker build -t skillfybank/notification-service:latest ./notification-service
```

### Push Images to DockerHub

```bash
# Login to DockerHub
docker login

# Tag images with your DockerHub username
docker tag skillfybank/account-service:latest <your-dockerhub-username>/account-service:latest
docker tag skillfybank/transaction-service:latest <your-dockerhub-username>/transaction-service:latest
docker tag skillfybank/notification-service:latest <your-dockerhub-username>/notification-service:latest

# Push all images
docker push <your-dockerhub-username>/account-service:latest
docker push <your-dockerhub-username>/transaction-service:latest
docker push <your-dockerhub-username>/notification-service:latest
```

### Simulate Broken Image Push (Troubleshooting)

```bash
# Simulate tag mismatch error
docker tag skillfybank/account-service:latest <your-dockerhub-username>/account-service:wrongtag
docker push <your-dockerhub-username>/account-service:v999   # Will fail - tag not found locally

# Fix: always tag before push
docker tag skillfybank/account-service:latest <your-dockerhub-username>/account-service:v1.0
docker push <your-dockerhub-username>/account-service:v1.0
```

### Test Endpoints

```bash
# Account Service
curl http://localhost:3000/health
curl http://localhost:3000/accounts

# Notification Service
curl http://localhost:5000/health
curl http://localhost:5000/notifications

# Transaction Service (internal only - no port exposed)
# Access via docker network
docker exec -it account-service wget -qO- http://transaction-service:8080/transactions/health
```

### Docker Networking

- All services are on the `skillfybank-net` bridge network
- Account and Notification services have external port mapping
- Transaction service is internal only (no port exposed to host)
- Services communicate using service names as hostnames

---

## PART 2: Docker Swarm — Multi-Host Service Orchestration

### Goals
1. Initialize Docker Swarm with **3 Manager Nodes** and **2 Worker Nodes**
2. Deploy all 3 services using Docker Stack
3. Set up overlay network, rolling update strategy, auto-restart policy
4. Simulate node failure and validate HA, service reallocation, network re-stitching
5. Create custom healthcheck and observe health status in Swarm

### Setup Swarm (Automated)

```bash
# Run the setup script (requires docker-machine)
bash swarm/setup-swarm.sh
```

### Setup Swarm (Manual)

```bash
# Initialize swarm on manager1
docker swarm init --advertise-addr <MANAGER1_IP>

# Get worker join token
docker swarm join-token worker

# Get manager join token
docker swarm join-token manager

# Join manager2 and manager3
docker swarm join --token <MANAGER_TOKEN> <MANAGER1_IP>:2377

# Join worker1 and worker2
docker swarm join --token <WORKER_TOKEN> <MANAGER1_IP>:2377

# Verify nodes
docker node ls
```

### Deploy Stack

```bash
# Deploy to swarm
docker stack deploy -c swarm/docker-stack.yml skillfybank

# Check services
docker stack services skillfybank

# Check service tasks
docker service ps skillfybank_account-service
docker service ps skillfybank_transaction-service
docker service ps skillfybank_notification-service
```

### Rolling Update (Transaction Service)

```bash
# Update transaction service image
docker service update \
  --image skillfybank/transaction-service:v2 \
  --update-parallelism 1 \
  --update-delay 15s \
  skillfybank_transaction-service

# Monitor update
docker service ps skillfybank_transaction-service
```

### Simulate Node Failure

```bash
# Stop a worker node to simulate failure
docker-machine stop worker1

# Watch service reallocation (run on manager)
watch docker service ps skillfybank_account-service

# Stop a manager node
docker-machine stop manager2

# Verify manager HA (quorum maintained with 2 of 3 managers)
docker node ls
```

### Check Health Status

```bash
# Inspect service health
docker service inspect --pretty skillfybank_account-service

# View container health
docker ps --format "table {{.Names}}\t{{.Status}}"
```

---

## PART 3: Kubernetes — Full-Scale Platform Deployment

### Goals
1. Set up a 3-node K8s cluster (minikube/multipass/kubeadm)
2. Create Kubernetes YAMLs for Deployments, ConfigMaps, Secrets, HPA, PV/PVC
3. Use ClusterIP, NodePort, and LoadBalancer services
4. Simulate a broken Deployment rollout and fix using rollback
5. Apply taints and tolerations for Notification Service

### Prerequisites

```bash
# Start minikube with 3 nodes
minikube start --nodes=3 --cpus=2 --memory=2048

# Verify nodes
kubectl get nodes

# Enable metrics server for HPA
minikube addons enable metrics-server

# Enable MetalLB for LoadBalancer (bare metal)
minikube addons enable metallb
```

### Deploy All Resources

```bash
# Create namespace first
kubectl apply -f kubernetes/namespace.yaml

# Apply ConfigMap and Secrets
kubectl apply -f kubernetes/configmap.yaml
kubectl apply -f kubernetes/secrets.yaml

# Deploy Account Service (with PV/PVC)
kubectl apply -f kubernetes/account/

# Deploy Transaction Service (with HPA)
kubectl apply -f kubernetes/transaction/

# Deploy Notification Service (with taints/tolerations)
kubectl apply -f kubernetes/notification/

# Verify everything
kubectl get all -n skillfybank
```

### Apply Taint for Notification Service Node

```bash
# Taint a node so only Notification service runs on it
kubectl taint nodes <node-name> notification-only=true:NoSchedule

# Label the node
kubectl label nodes <node-name> role=notification

# Verify pod placement
kubectl get pods -n skillfybank -o wide
```

### Test HPA (Simulate CPU Load)

```bash
# Watch HPA
kubectl get hpa -n skillfybank -w

# Generate CPU load on transaction service
kubectl run -n skillfybank load-generator \
  --image=busybox \
  --restart=Never \
  -- /bin/sh -c "while true; do wget -q -O- http://transaction-service:8080/transactions; done"

# Watch pods scale up
kubectl get pods -n skillfybank -w

# Stop load generator
kubectl delete pod load-generator -n skillfybank
```

### Simulate Broken Deployment & Rollback

```bash
# Deploy a broken image (wrong tag)
kubectl set image deployment/transaction-service \
  transaction-service=skillfybank/transaction-service:broken \
  -n skillfybank

# Watch rollout fail
kubectl rollout status deployment/transaction-service -n skillfybank

# Check pod errors
kubectl describe pod -l app=transaction-service -n skillfybank
kubectl logs -l app=transaction-service -n skillfybank

# Rollback to previous version
kubectl rollout undo deployment/transaction-service -n skillfybank

# Verify rollback
kubectl rollout status deployment/transaction-service -n skillfybank
kubectl rollout history deployment/transaction-service -n skillfybank
```

### Useful kubectl Commands

```bash
# Get all resources in namespace
kubectl get all -n skillfybank

# Describe a pod
kubectl describe pod <pod-name> -n skillfybank

# View logs
kubectl logs <pod-name> -n skillfybank
kubectl logs -l app=account-service -n skillfybank

# Exec into pod
kubectl exec -it <pod-name> -n skillfybank -- /bin/sh

# Get events
kubectl get events -n skillfybank --sort-by='.lastTimestamp'

# Port forward for local testing
kubectl port-forward svc/account-service 3000:3000 -n skillfybank
kubectl port-forward svc/notification-service 5000:5000 -n skillfybank
```

### Services Overview

| Service | Type | Port | Access |
|---|---|---|---|
| account-service | NodePort | 30000 | External |
| transaction-service | ClusterIP | 8080 | Internal only |
| notification-service | LoadBalancer | 5000 | External |

---

## PART 4: Istio — Advanced Traffic Management

### Goals
1. Install Istio on Kubernetes cluster
2. Enable mTLS between all services
3. Configure 90/10 traffic split for Transaction Service (v1/v2)
4. Configure canary deployment for Notification Service
5. Simulate A/B test via HTTP headers for Notification Service
6. Use Jaeger for distributed tracing
7. Demonstrate circuit breaking and retry logic

### Install Istio

```bash
# Download Istio
curl -L https://istio.io/downloadIstio | sh -

# Add istioctl to PATH
export PATH=$PWD/istio-*/bin:$PATH

# Install Istio on cluster (demo profile)
istioctl install --set profile=demo -y

# Verify installation
kubectl get pods -n istio-system

# Enable Istio sidecar injection for namespace
kubectl label namespace skillfybank istio-injection=enabled

# Restart existing pods to inject sidecars
kubectl rollout restart deployment -n skillfybank
```

### Apply Istio Configs

```bash
# Enable mTLS (STRICT mode)
kubectl apply -f istio/peer-authentication.yaml

# Apply Transaction traffic split (90/10)
kubectl apply -f istio/transaction-vs-dr.yaml

# Apply Notification canary + A/B routing
kubectl apply -f istio/notification-vs-dr.yaml

# Enable Jaeger tracing
kubectl apply -f istio/jaeger-tracing.yaml

# Verify configs
kubectl get virtualservices -n skillfybank
kubectl get destinationrules -n skillfybank
kubectl get peerauthentication -n skillfybank
```

### Test Traffic Splitting (Transaction 90/10)

```bash
# Send multiple requests and observe v1/v2 distribution
for i in $(seq 1 20); do
  curl -s http://<CLUSTER_IP>/transactions | grep version
done
```

### Test A/B Routing (Notification by Header)

```bash
# Route to canary version using header
curl -H "x-version: canary" http://<CLUSTER_IP>/notifications

# Route to stable version (no header)
curl http://<CLUSTER_IP>/notifications
```

### Access Jaeger UI

```bash
# Port forward Jaeger
kubectl port-forward svc/tracing 16686:80 -n istio-system

# Open in browser
# http://localhost:16686
```

### Access Kiali Dashboard (optional)

```bash
kubectl port-forward svc/kiali 20001:20001 -n istio-system
# Open http://localhost:20001
```

### Circuit Breaker Test

```bash
# The DestinationRule in transaction-vs-dr.yaml has outlier detection configured
# consecutiveGatewayErrors: 5 — ejects pod after 5 consecutive errors
# Verify with:
kubectl describe destinationrule transaction-service-dr -n skillfybank
```

---

## Bonus: EFK Stack — Centralized Logging

### Deploy EFK (Elasticsearch + Fluentd + Kibana)

```bash
# Add Elastic Helm repo
helm repo add elastic https://helm.elastic.co
helm repo update

# Install Elasticsearch
helm install elasticsearch elastic/elasticsearch \
  --namespace logging --create-namespace \
  --set replicas=1

# Install Kibana
helm install kibana elastic/kibana \
  --namespace logging

# Deploy Fluentd as DaemonSet
kubectl apply -f https://raw.githubusercontent.com/fluent/fluentd-kubernetes-daemonset/master/fluentd-daemonset-elasticsearch.yaml

# Access Kibana
kubectl port-forward svc/kibana-kibana 5601:5601 -n logging
# Open http://localhost:5601
```

---

## Troubleshooting

### Docker Issues

```bash
# Check container logs
docker logs <container-name>

# Inspect network
docker network inspect skillfybank-net

# Check image layers
docker history skillfybank/account-service:latest
```

### Kubernetes Issues

```bash
# Pod stuck in Pending
kubectl describe pod <pod-name> -n skillfybank

# ImagePullBackOff
kubectl get events -n skillfybank

# CrashLoopBackOff
kubectl logs <pod-name> -n skillfybank --previous

# Check node resources
kubectl top nodes
kubectl top pods -n skillfybank
```

### Istio Issues

```bash
# Check sidecar injection
kubectl get pods -n skillfybank -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].name}{"\n"}{end}'

# Verify mTLS
istioctl authn tls-check <pod-name>.skillfybank

# Analyze config
istioctl analyze -n skillfybank
```

---

## Prerequisites Summary

| Tool | Version | Purpose |
|---|---|---|
| Docker | 24+ | Container runtime |
| Docker Compose | v2+ | Local multi-container |
| docker-machine | latest | Swarm node simulation |
| kubectl | 1.28+ | Kubernetes CLI |
| minikube | 1.32+ | Local K8s cluster |
| istioctl | 1.20+ | Istio CLI |
| helm | 3+ | K8s package manager |

---

*Assignment by Skillfyme — Empowering your success*
