# 02 - Production Grade E-Commerce App Deployment in Kubernetes | TECH MAHATO

> Production-Ready Microservices E-Commerce Application Deployment on Kind Cluster
>
> By **Arbind Kr. Mahato** | Cloud and DevOps Engineer | AWS Certified | CKA and CKAD | AWS Community Builder
>
> [TECH MAHATO YouTube](https://www.youtube.com/techmahato) | [Medium Blog](https://medium.com/@techmahato) | [LinkedIn](https://www.linkedin.com/in/arbindmahato/)

---

**Objective:** Deploy a production-grade microservices e-commerce application (OpenTelemetry Demo) on Kubernetes Kind cluster, understanding Kubernetes core concepts including Service Accounts, Deployments, Services, Service Discovery, and LoadBalancer access.

**Application:** OpenTelemetry Astronomy Shop (20+ Microservices)
**Source:** https://opentelemetry.io/docs/demo/

---

## Table of Contents

- [Part 1 - Project Overview](#part-1---project-overview)
  - [1.1 Project Introduction](#11-project-introduction)
  - [1.2 Application Features](#12-application-features)
  - [1.3 Project Architecture](#13-project-architecture)
  - [1.4 Why This Project for DevOps Practice](#14-why-this-project-for-devops-practice)
- [Part 2 - Kubernetes Concepts for This Deployment](#part-2---kubernetes-concepts-for-this-deployment)
  - [2.1 Service Account](#21-service-account)
  - [2.2 Deployment Resource (Scaling and Healing)](#22-deployment-resource-scaling-and-healing)
  - [2.3 Service Resource (Service Discovery)](#23-service-resource-service-discovery)
  - [2.4 Kubernetes Service Types](#24-kubernetes-service-types)
- [Part 3 - Deploy the Application](#part-3---deploy-the-application)
  - [3.1 Prerequisites](#31-prerequisites)
  - [3.2 Create Service Account](#32-create-service-account)
  - [3.3 Deploy All Microservices](#33-deploy-all-microservices)
  - [3.4 Verify Deployment](#34-verify-deployment)
- [Part 4 - Access the Application](#part-4---access-the-application)
  - [4.1 Using LoadBalancer Service Type (with Cloud Provider KIND)](#41-using-loadbalancer-service-type-with-cloud-provider-kind)
  - [4.2 Using NodePort (Alternative)](#42-using-nodeport-alternative)
  - [4.3 Using Port-Forward (Quick Access)](#43-using-port-forward-quick-access)
- [Part 5 - LoadBalancer vs Ingress](#part-5---loadbalancer-vs-ingress)
  - [5.1 Disadvantages of LoadBalancer Service Type](#51-disadvantages-of-loadbalancer-service-type)
  - [5.2 Advantages of Ingress](#52-advantages-of-ingress)
  - [5.3 What is Ingress and Ingress Controller](#53-what-is-ingress-and-ingress-controller)
- [Part 6 - Deploy Ingress (AWS ALB Controller)](#part-6---deploy-ingress-aws-alb-controller)
  - [6.1 For Kind Cluster (Our Lab)](#61-for-kind-cluster-our-lab)
  - [6.2 For EKS Cluster (Production Reference)](#62-for-eks-cluster-production-reference)
  - [6.3 Create Ingress Resource for Frontend Proxy](#63-create-ingress-resource-for-frontend-proxy)
  - [6.4 Custom Domain with Route 53 (Production)](#64-custom-domain-with-route-53-production)
- [Part 7 - Troubleshooting](#part-7---troubleshooting)
- [Part 8 - Cleanup](#part-8---cleanup)
- [References](#references)
- [Credits and Connect](#credits-and-connect)

---

## Part 1 - Project Overview

### 1.1 Project Introduction

The **OpenTelemetry Demo** (also known as the Astronomy Shop) is a production-grade e-commerce application designed to sell astronomy-themed products. It serves as an excellent learning platform for DevOps engineers because it mirrors the complexity and architecture of real-world e-commerce systems.

This project was chosen for the following reasons:

- **Microservice Architecture** - Contains 20+ independently deployable services communicating over gRPC and HTTP
- **Comprehensive and Real-Time Like** - Mirrors actual e-commerce workflows including cart, checkout, payment, and shipping
- **Very Good Documentation** - Maintained by the OpenTelemetry community with detailed architecture docs
- **Stable and Actively Maintained** - Regular releases with a large contributor base
- **Production Patterns** - Demonstrates service discovery, inter-service communication, and feature flagging

**Source Repository:** https://github.com/open-telemetry/opentelemetry-demo

### 1.2 Application Features

| Feature | Description |
|---------|-------------|
| Shopping | Browse and search astronomy products |
| Product Catalog | Centralized product listing with details and pricing |
| Cart | Add/remove items, persistent shopping cart |
| Currency Conversion | Real-time currency conversion for international users |
| Shipping | Calculate shipping costs based on items and destination |
| Checkout | Complete order workflow with address and payment |
| Payment | Process payments (simulated credit card processing) |
| Recommendations | Product recommendations based on browsing history |
| Email Notifications | Order confirmation and shipping notification emails |
| Fraud Detection | Analyze transactions for potential fraud |
| Accounting | Track revenue and financial transactions |
| Feature Flagging (flagd) | Toggle features on/off without redeployment |

### 1.3 Project Architecture

```
+-------------------+       +-------------------------+       +-------------------+
|  Internet / Load  |------>|  Frontend Proxy (Envoy) |------>|  Frontend (Web UI)|
|    Generator      |       |     (Port 8080)         |       |    (Next.js)      |
+-------------------+       +-------------------------+       +-------------------+
                                                                       |
                    +--------------------------------------------------+
                    |              |              |            |        |
                    v              v              v            v        v
          +--------------+ +------------+ +-----------+ +--------+ +----------------+
          |Product Catalog| |    Cart    | | Checkout  | |Currency| | Recommendation |
          |   Service    | |  Service   | |  Service  | |Service | |    Service     |
          +--------------+ +------------+ +-----------+ +--------+ +----------------+
                                                |
                         +----------------------+----------------------+
                         |              |              |                |
                         v              v              v                v
                   +-----------+ +-----------+ +-----------+    +------------+
                   |  Shipping | |  Payment  | |   Email   |    |   Quote    |
                   |  Service  | |  Service  | |  Service  |    |  Service   |
                   +-----------+ +-----------+ +-----------+    +------------+

          +----------------+    +-------------------+    +-------------------+
          |   Accounting   |    |  Fraud Detection  |    |   flagd (Feature  |
          |    Service     |    |     Service       |    |    Flagging)      |
          +----------------+    +-------------------+    +-------------------+
                 ^                       ^                        ^
                 |                       |                        |
                 +--- All services connect to flagd for feature flag evaluation ---+
```

**Reference:** https://opentelemetry.io/docs/demo/architecture/

### 1.4 Why This Project for DevOps Practice

| Aspect | Value for DevOps Engineers |
|--------|---------------------------|
| Microservices Architecture | Practice deploying and managing 20+ services with different runtimes |
| Real-World Patterns | Service discovery, load balancing, inter-service communication |
| Comprehensive Documentation | Well-documented architecture reduces guesswork |
| Resume Showcase | Demonstrates ability to handle production-grade deployments |
| Observability Built-in | Pre-instrumented with OpenTelemetry for metrics, traces, and logs |
| Multi-Language Services | Go, Python, Java, .NET, Node.js, Rust, C++, Ruby, PHP, Kotlin |
| Feature Flagging | Modern deployment patterns with flagd integration |

---


## Part 2 - Kubernetes Concepts for This Deployment

### 2.1 Service Account

A **Service Account** provides an identity for pods running in a Kubernetes cluster. It determines what a pod is allowed to do when interacting with the Kubernetes API.

**Key Points:**

- **What:** An identity assigned to pods for authentication and authorization within the cluster
- **Why:** In production environments, pods MUST have explicit service accounts rather than relying on the default. This follows the principle of least privilege.
- **Default Behavior:** If no service account is specified in a pod spec, Kubernetes automatically assigns the `default` service account in that namespace
- **When Elevated Permissions Are Needed:** Attach Roles or ClusterRoles via RoleBindings or ClusterRoleBindings to grant specific API permissions
- **For This Project:** A simple service account without additional RBAC bindings is sufficient because the microservices do not need to interact with the Kubernetes API

**serviceaccount.yaml:**

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: opentelemetry-demo
  labels:
    opentelemetry.io/name: opentelemetry-demo
    app.kubernetes.io/instance: opentelemetry-demo
    app.kubernetes.io/name: opentelemetry-demo
    app.kubernetes.io/version: "1.12.0"
    app.kubernetes.io/part-of: opentelemetry-demo
```

### 2.2 Deployment Resource (Scaling and Healing)

A **Deployment** is the standard Kubernetes resource for running stateless applications. It manages the lifecycle of pods through a ReplicaSet.

**How It Works:**

```
Deployment --creates--> ReplicaSet --manages--> Pod(s)
```

- **Auto-Healing:** If a pod crashes or is deleted, the ReplicaSet automatically creates a replacement to maintain the desired replica count
- **Auto-Scaling:** Change the `replicas` field to scale horizontally
- **Rolling Updates:** Deployments support zero-downtime updates by gradually replacing old pods with new ones

**Deployment Hierarchy:**

```
                    Deployment (YAML you write)
                         |
                         | creates and manages
                         v
                    ReplicaSet (auto-created)
                         |
                         | maintains desired count
                         v
          +----------+---+---+----------+
          |          |       |          |
        Pod 1      Pod 2   Pod 3     Pod N
       (replica)  (replica) (replica) (replica)
          |          |       |          |
      Container  Container Container Container
      (your app) (your app)(your app)(your app)
```

Key behaviors:
- **Auto-healing:** If Pod 2 crashes, ReplicaSet immediately creates a new Pod to maintain the count
- **Auto-scaling:** Change `replicas: 3` to `replicas: 10` and ReplicaSet scales up instantly
- **Rolling updates:** Deployment creates a new ReplicaSet, gradually shifting traffic

**Deployment Structure:**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: <service-name>
  labels:
    app.kubernetes.io/name: <service-name>
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: <service-name>
  template:
    metadata:
      labels:
        app.kubernetes.io/name: <service-name>
    spec:
      serviceAccountName: opentelemetry-demo
      containers:
        - name: <service-name>
          image: <image:tag>
          ports:
            - containerPort: <port>
          env:
            - name: KEY
              value: "value"
```

**Field Breakdown:**

| Field | Purpose |
|-------|---------|
| `apiVersion: apps/v1` | API group for Deployment resource |
| `metadata.name` | Unique name for this deployment |
| `spec.replicas` | Number of pod instances to maintain |
| `spec.selector.matchLabels` | How the Deployment finds its pods |
| `spec.template` | Pod template (blueprint for each pod) |
| `spec.template.spec.serviceAccountName` | Identity assigned to the pod |
| `spec.template.spec.containers` | Container definitions (image, ports, env) |

**Deployment YAML Field-by-Field Breakdown:**

```yaml
apiVersion: apps/v1              # API group and version (always apps/v1 for Deployments)
kind: Deployment                 # Resource type
metadata:
  name: currency-service         # Name of this Deployment (for identification)
  labels:                        # Labels for the Deployment itself (for filtering/selection)
    app.kubernetes.io/name: currency-service
    app.kubernetes.io/part-of: opentelemetry-demo
spec:
  replicas: 1                    # Number of pod copies ReplicaSet maintains
  selector:                      # How ReplicaSet finds its pods
    matchLabels:
      app.kubernetes.io/name: currency-service
  template:                      # Pod template (equivalent to Docker Compose service)
    metadata:
      labels:                    # Pod labels (CRITICAL for Service Discovery)
        app.kubernetes.io/name: currency-service
    spec:
      serviceAccountName: opentelemetry-demo  # SA assigned to pod (not default!)
      containers:
        - name: currency-service             # Container name
          image: otel/demo:currency-service   # Container image
          ports:
            - containerPort: 8080            # Port the app listens on
          env:                               # Environment variables (from developers)
            - name: OTEL_SERVICE_NAME
              value: "currency-service"
            - name: PAYMENT_SERVICE_URL
              value: "http://payment-service:8080"  # Uses SERVICE NAME!
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 250m
              memory: 256Mi
```

| Field | Purpose | Who Provides It |
|-------|---------|----------------|
| apiVersion, kind | Identifies the resource type | Kubernetes docs |
| metadata.name | Names the deployment | DevOps engineer |
| metadata.labels | Identifies the deployment during troubleshooting | DevOps engineer |
| spec.replicas | Controls scaling (auto-healing + auto-scaling) | DevOps engineer |
| template.metadata.labels | Used by Service for discovery (CRITICAL) | DevOps engineer |
| spec.serviceAccountName | Pod identity and permissions | DevOps engineer |
| containers.image | The container to run | Developer provides |
| containers.ports | Port the app listens on | Developer provides |
| containers.env | App configuration (service URLs, etc.) | Developer provides |
| containers.resources | CPU/memory requests and limits | DevOps engineer |

### 2.3 Service Resource (Service Discovery)

**The Problem:**

Pods receive dynamic IP addresses that change every time they restart. If Service A communicates with Service B using an IP address, and Service B restarts with a new IP, the connection breaks.

**The Solution - Kubernetes Services:**

A Service provides a stable network endpoint (DNS name and ClusterIP) that routes traffic to healthy pods using label selectors.

```
Frontend Pod                    Kubernetes Service                  Backend Pods
+-----------+                  +------------------+                +-----------+
| Uses env: |  --- DNS --->    | cart-service     |  --- routes    | Pod IP:   |
| CART_SVC  |                  | ClusterIP:       |  --- to --->   | 10.244.x  |
+-----------+                  | 10.96.x.x       |                +-----------+
                               | selector:        |                | Pod IP:   |
                               |  app: cart       |  --- to --->   | 10.244.y  |
                               +------------------+                +-----------+
```

**How Service Discovery Works:**

1. Deployment creates pods with labels (e.g., `app.kubernetes.io/name: cart-service`)
2. Service has a selector matching those labels
3. Service gets a stable ClusterIP and DNS name
4. Other services reference the Service name (not pod IPs)
5. Frontend uses environment variables like `CART_SERVICE_ADDR=cart-service:8080`

```
  WITHOUT Kubernetes Service (The Problem):
  =========================================

  Frontend Pod              Backend Pod
  +---------------+         +---------------+
  | env:          |         | IP: 10.1.4.6  |  <-- IP changes on restart!
  |  BACKEND_IP=  |-------->|               |
  |  10.1.4.6     |    X    | (crashed and  |
  +---------------+    |    |  restarted)   |
                       |    +---------------+
                       |    +---------------+
                       +--->| IP: 10.1.5.4  |  <-- New IP, frontend broken!
                            +---------------+


  WITH Kubernetes Service (The Solution):
  =======================================

  Frontend Pod                Service                 Backend Pod(s)
  +---------------+         +-----------+         +---------------+
  | env:          |         | Name:     |         | Labels:       |
  |  BACKEND_URL= |-------->| backend-  |-------->|  app: backend |
  |  backend-svc  |         | svc       |         | IP: 10.1.5.4  |
  +---------------+         |           |         +---------------+
                            | Selector: |         +---------------+
                            |  app:     |-------->| Labels:       |
                            |  backend  |         |  app: backend |
                            +-----------+         | IP: 10.1.6.2  |
                                                  +---------------+

  - Service identifies pods by LABELS, not IPs
  - Frontend uses SERVICE NAME, not pod IP
  - Even if backend pods restart with new IPs, the Service finds them by label
  - This is Service Discovery in Kubernetes
```

**Service Structure:**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: <service-name>
spec:
  type: ClusterIP
  selector:
    app.kubernetes.io/name: <service-name>
  ports:
    - port: 8080
      targetPort: 8080
```

**Selector Matching:**

The Service `selector` field MUST match the labels defined in the Deployment's `spec.template.metadata.labels`. This is how Kubernetes knows which pods belong to which service:

```
Deployment labels:              Service selector:
  app.kubernetes.io/name:         app.kubernetes.io/name:
    cart-service        <=====>     cart-service
```

If labels do not match, the Service will have zero endpoints and traffic will not route.

**Service YAML Field-by-Field Breakdown:**

```yaml
apiVersion: v1                   # API version (always v1 for Services)
kind: Service                    # Resource type
metadata:
  name: currency-service         # Service name (used as DNS hostname!)
  labels:
    app.kubernetes.io/name: currency-service
spec:
  type: ClusterIP                # ClusterIP | NodePort | LoadBalancer
  selector:                      # MUST match pod template labels
    app.kubernetes.io/name: currency-service
  ports:
    - port: 8080                 # Port the Service listens on
      targetPort: 8080           # Port on the container (must match containerPort)
      protocol: TCP
```

| Field | Purpose | Connection |
|-------|---------|------------|
| metadata.name | Becomes the DNS name for the service | Other pods use this as hostname |
| spec.type | Determines access scope | ClusterIP=internal, NodePort=VPC, LoadBalancer=internet |
| spec.selector | Links Service to Pods | MUST match template.metadata.labels in Deployment |
| ports.port | Service listening port | Other pods connect to `service-name:port` |
| ports.targetPort | Container port to forward to | MUST match containers.ports.containerPort |

**How Selector Links Service to Deployment:**
```
  Deployment YAML                          Service YAML
  ==================                       =============
  spec:                                    spec:
    template:                                selector:
      metadata:                                app.kubernetes.io/name: currency-service
        labels:                                         |
          app.kubernetes.io/name: ----MUST MATCH---------+
            currency-service
```

### 2.4 Kubernetes Service Types

| Type | Scope | Use Case | How It Works |
|------|-------|----------|--------------|
| ClusterIP | Internal only | Service-to-service communication | Default type. Assigns an internal IP reachable only within the cluster |
| NodePort | VPC/Organization | Access via node IP:port | Opens a static port (30000-32767) on every node. Traffic to NodeIP:NodePort routes to the Service |
| LoadBalancer | External/Internet | Public access | Requests an external load balancer from the cloud provider. Exposes service externally |

**Cloud Controller Manager (CCM):**

The LoadBalancer service type relies on the **Cloud Controller Manager** to provision actual load balancers. When you create a LoadBalancer service:

1. Kubernetes API receives the service creation request
2. CCM detects the LoadBalancer type
3. CCM communicates with the cloud provider API (AWS, GCP, Azure)
4. Cloud provider creates an external load balancer
5. External IP/DNS is written back to the service status

For Kind clusters, **Cloud Provider KIND** acts as the CCM, assigning IPs from the Docker network to simulate cloud load balancer behavior.

```
  Kubernetes Service Types - Access Scope:
  =========================================

  +------------------------------------------------------------------+
  |  INTERNET (External Users)                                        |
  |                                                                    |
  |     Can access via LoadBalancer external IP/DNS                    |
  |                            |                                       |
  +----------------------------|---------------------------------------+
                               v
  +------------------------------------------------------------------+
  |  VPC / Organization Network                                       |
  |                                                                    |
  |     Can access via NodePort (NodeIP:30000-32767)                  |
  |                            |                                       |
  +----------------------------|---------------------------------------+
                               v
  +------------------------------------------------------------------+
  |  KUBERNETES CLUSTER (Internal Network via CNI)                    |
  |                                                                    |
  |     ClusterIP: Only pods within cluster can access                |
  |                                                                    |
  |  +----------+    +---------+    +---------+                       |
  |  |  Node 1  |    | Node 2  |    | Node 3  |                       |
  |  | +------+ |    | +-----+ |    | +-----+ |                       |
  |  | | Pod  | |    | | Pod | |    | | Pod | |                       |
  |  | +------+ |    | +-----+ |    | +-----+ |                       |
  |  +----------+    +---------+    +---------+                       |
  |                                                                    |
  +------------------------------------------------------------------+

  LoadBalancer Flow:
    API Server --> Cloud Controller Manager (CCM) --> Cloud Provider (AWS/GCP)
                                                          |
                                                          v
                                                   Creates external LB
                                                   (e.g., AWS ALB/NLB)
```

---


## Part 3 - Deploy the Application

### 3.1 Prerequisites

| Prerequisite | Status Required | Reference |
|--------------|----------------|-----------|
| Kind Cluster | Running with multi-node setup | [001-Platform-Setup](../001-Platform-Setup/) |
| kubectl | Configured and connected to Kind cluster | `kubectl cluster-info` |
| Docker | Running (Kind runs on Docker) | `docker ps` |
| Cloud Provider KIND | Running in background for LoadBalancer support | `sudo cloud-provider-kind &` |

### 3.2 Create Service Account

Apply the service account that all microservices will use:

```bash
kubectl apply -f serviceaccount.yaml
kubectl get sa
```

Expected output:

```
serviceaccount/opentelemetry-demo created
NAME                 SECRETS   AGE
default              0         10m
opentelemetry-demo   0         5s
```

### 3.3 Deploy All Microservices

There are two approaches to deploy the application:

**Approach 1 - Individual Folders (Granular Control):**

```bash
kubectl apply -f cart-service/
kubectl apply -f checkout-service/
kubectl apply -f currency-service/
# ... repeat for each microservice
```

**Approach 2 - Single Manifest (Recommended for Lab):**

```bash
# Deploy all 20+ microservices at once
kubectl apply -f complete-deploy.yaml

# Watch pods come up in real-time
kubectl get pods -w

# Verify all pods are Running (wait until all show 1/1 Running)
kubectl get pods

# Verify all services
kubectl get svc
```

Note: It may take 2-5 minutes for all pods to reach Running status depending on image pull times and available resources.

### 3.4 Verify Deployment

```bash
# Check all pods are running with node placement
kubectl get pods -o wide

# Check all services and their ClusterIPs
kubectl get svc

# Check events for any issues
kubectl get events --sort-by='.lastTimestamp' | tail -20

# Describe a specific pod if troubleshooting
kubectl describe pod <pod-name>
```

All pods should show `1/1 Running` status. If any pods are in `Pending`, `CrashLoopBackOff`, or `ImagePullBackOff`, refer to Part 7 (Troubleshooting).

---


## Part 4 - Access the Application

### 4.1 Using LoadBalancer Service Type (with Cloud Provider KIND)

Since Cloud Provider KIND is running from the platform setup (001), we can use LoadBalancer service type to get an external IP:

```bash
# Change frontend-proxy service to LoadBalancer
kubectl patch svc opentelemetry-demo-frontendproxy -p '{"spec": {"type": "LoadBalancer"}}'

# Wait for External IP assignment
kubectl get svc opentelemetry-demo-frontendproxy -w

# Get the External IP
LB_IP=$(kubectl get svc opentelemetry-demo-frontendproxy -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Access the app at: http://${LB_IP}:8080"

# Verify with curl
curl http://${LB_IP}:8080
```

Open the URL in your browser to see the Astronomy Shop frontend.

### 4.2 Using NodePort (Alternative)

If Cloud Provider KIND is not available, use NodePort to expose the service:

```bash
# Patch to NodePort
kubectl patch svc opentelemetry-demo-frontendproxy -p '{"spec": {"type": "NodePort"}}'

# Get the assigned NodePort
NODE_PORT=$(kubectl get svc opentelemetry-demo-frontendproxy -o jsonpath='{.spec.ports[0].nodePort}')
echo "Access the app at: http://<EC2-IP>:${NODE_PORT}"
```

Replace `<EC2-IP>` with your actual EC2 instance public IP if running on AWS.

### 4.3 Using Port-Forward (Quick Access)

The simplest method for local development and testing:

```bash
kubectl port-forward svc/opentelemetry-demo-frontendproxy 8080:8080 --address=0.0.0.0 &
echo "Access the app at: http://<EC2-IP>:8080"
```

Note: Port-forward runs in the foreground (or background with `&`). It is not suitable for production but works well for quick verification.

---


### 4.4 Understanding Networking: Kind on EC2 (Why EXTERNAL-IP is a Docker IP)

When you patch the frontendproxy service to `LoadBalancer`, you will see:

```
NAME                               TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
opentelemetry-demo-frontendproxy   LoadBalancer   10.96.111.254   172.18.0.5    8080:32100/TCP   12m
```

The `EXTERNAL-IP` is `172.18.0.5` — a Docker network IP, not a public IP. Here is why:

**Architecture: Kind LoadBalancer on EC2**

```
  YOUR LAPTOP (Browser)
      |
      | connects to EC2 Elastic IP (e.g., 3.111.87.86:8080)
      v
  +------------------------------------------------------------------+
  |  AWS EC2 INSTANCE (t3a.xlarge)                                    |
  |  Public IP: 3.111.87.86 (Elastic IP)                             |
  |  Private IP: 172.31.x.x (VPC)                                   |
  |                                                                    |
  |  +--------------------------------------------------------------+ |
  |  |  DOCKER ENGINE                                                | |
  |  |  Docker Network: "kind" (172.18.0.0/16)                      | |
  |  |                                                                | |
  |  |  +----------------+  +----------------+  +----------------+  | |
  |  |  | control-plane  |  | worker-1       |  | worker-2       |  | |
  |  |  | 172.18.0.3     |  | 172.18.0.4     |  | 172.18.0.2     |  | |
  |  |  | Port maps:     |  | (pods here)    |  | (pods here)    |  | |
  |  |  | 80->host:80    |  |                |  |                |  | |
  |  |  | 443->host:443  |  |                |  |                |  | |
  |  |  +----------------+  +----------------+  +----------------+  | |
  |  |                                                                | |
  |  |  +---------------------+                                      | |
  |  |  | Cloud Provider KIND |  (Docker container acting as LB)     | |
  |  |  | IP: 172.18.0.5      |  <-- This is the EXTERNAL-IP         | |
  |  |  +---------------------+                                      | |
  |  +--------------------------------------------------------------+ |
  +------------------------------------------------------------------+
```

**Real Cloud (EKS/GKE) vs Kind on EC2:**

| Aspect | Real Cloud (EKS) | Kind on EC2 |
|--------|-----------------|-------------|
| CCM talks to | AWS/GCP API | Docker daemon |
| Creates | Real ALB with public DNS | Docker container with Docker IP |
| EXTERNAL-IP | Public DNS (reachable from internet) | 172.18.x.x (reachable from EC2 host only) |
| Browser access | Direct via LB DNS | Requires port-forward or NodePort |

**Three Methods to Access the App:**

**Method 1: curl from EC2 host (immediate, no browser)**

```bash
# EC2 host CAN reach Docker network IPs directly
curl http://172.18.0.5:8080
```

Why: The EC2 host has a route to the Docker bridge network (172.18.0.0/16).

**Method 2: kubectl port-forward (for browser access from laptop)**

```bash
# Bridges: EC2-public-IP:8080 --> K8s-Service:8080
nohup kubectl port-forward svc/opentelemetry-demo-frontendproxy 8080:8080 --address=0.0.0.0 &>/dev/null &
```

Access from browser: `http://<EC2-ELASTIC-IP>:8080`

How it works:
```
  Browser --> EC2:8080 --> kubectl port-forward --> K8s API --> Pod
                ^                                              ^
                |                                              |
      listens on 0.0.0.0:8080                       app running
      (all interfaces)                              inside pod
```

The `--address=0.0.0.0` flag is critical. Without it, port-forward only listens on `127.0.0.1` (localhost), meaning only processes on EC2 itself can connect.

**Method 3: NodePort via extraPortMappings (no port-forward needed)**

The kind cluster config has ports 80/443 mapped to the EC2 host. When Istio Ingress Gateway is configured to use those ports:

```
  Browser --> EC2:80 --> Docker port-map --> control-plane:80 --> Istio Gateway --> Service --> Pods
```

This is the method used with Istio Ingress Gateway (covered in next lab module).

**Summary:**

| Method | Access From | Command | Limitation |
|--------|------------|---------|-----------|
| Docker IP (172.18.0.5) | EC2 host only | `curl http://172.18.0.5:8080` | Not reachable from internet |
| kubectl port-forward | Browser via Elastic IP | `kubectl port-forward --address=0.0.0.0` | Dies when terminal disconnects (use nohup) |
| extraPortMappings (80/443) | Browser via Elastic IP | Configure service on mapped ports | Best for Istio (next module) |

---

## Part 5 - LoadBalancer vs Ingress (Deep Dive)

This section explains why LoadBalancer service type has limitations, how Ingress solves those problems, and the complete architecture of Ingress Controllers.

### 5.1 How LoadBalancer Service Type Works

When you change a service type to `LoadBalancer`:

```
  Step-by-step flow:
  ==================

  1. You run: kubectl patch svc frontend -p '{"spec": {"type": "LoadBalancer"}}'
                    |
                    v
  2. Kubernetes API Server receives the change
                    |
                    v
  3. API Server notifies Cloud Controller Manager (CCM)
     (CCM is a control-plane component that talks to cloud APIs)
                    |
                    v
  4. CCM calls cloud provider API:
     - AWS: Creates an ALB or NLB
     - GCP: Creates a Google Cloud Load Balancer
     - Kind: Cloud Provider KIND creates a Docker container
                    |
                    v
  5. Cloud provider returns an external IP or DNS
                    |
                    v
  6. CCM writes the external IP back to the Service's
     status.loadBalancer.ingress field
                    |
                    v
  7. kubectl get svc shows EXTERNAL-IP
```

**Result for our application:**
```bash
$ kubectl patch svc opentelemetry-demo-frontendproxy -p '{"spec": {"type": "LoadBalancer"}}'
$ kubectl get svc opentelemetry-demo-frontendproxy
NAME                               TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
opentelemetry-demo-frontendproxy   LoadBalancer   10.96.111.254   172.18.0.5    8080:32100/TCP   12m
```

### 5.2 Disadvantages of LoadBalancer Service Type

```
  The Problem at Scale (20 microservices, each needing external access):
  =====================================================================

  Service 1 (frontend)       --> Creates LB 1  (cost: $20/month)
  Service 2 (API gateway)    --> Creates LB 2  (cost: $20/month)
  Service 3 (admin panel)    --> Creates LB 3  (cost: $20/month)
  Service 4 (webhooks)       --> Creates LB 4  (cost: $20/month)
  ...                        ...
  Service 20 (monitoring)    --> Creates LB 20 (cost: $20/month)
                                              ___________________
                                 Total cost:  $400/month (just LBs!)

  With Ingress: ONE load balancer routes to ALL 20 services = $20/month
```

| Disadvantage | Detailed Explanation |
|---|---|
| Not Declarative | You cannot configure HTTPS, certificates, custom headers, rate limiting, or routing rules via the Service YAML. The Service only says `type: LoadBalancer`. Any additional configuration must be done manually in the cloud console (AWS/GCP) or via annotations that vary per provider. If someone modifies the LB in the console, there is NO record of the change in Git. |
| Cost Inefficient | Each LoadBalancer service creates a SEPARATE cloud load balancer. AWS ALB costs ~$20/month + data transfer. With 10 services, that is $200/month just for load balancers. Ingress uses ONE LB for all services. |
| No Routing Rules | LoadBalancer service can only forward traffic to ONE service. You cannot say "if path is /api, go to API service; if path is /web, go to frontend." Each service needs its own LB. |
| Tied to Cloud Provider | If you switch from AWS to GCP, the LB behavior changes. You cannot control which type of LB is created (ALB vs NLB vs Classic). |
| Does Not Work Everywhere | On Kind, Minikube, bare-metal — LoadBalancer type stays `<pending>` forever unless you install MetalLB or Cloud Provider KIND. |

### 5.3 How Ingress Solves These Problems

```
  With Ingress: ONE Load Balancer handles ALL routing
  ====================================================

                          INTERNET
                             |
                             v
                   +-------------------+
                   |  ONE Load Balancer |  (cost: $20/month total)
                   |  (created by       |
                   |   Ingress          |
                   |   Controller)      |
                   +---+-------+---+---+
                       |       |   |   |
     host: shop.com ---+       |   |   +--- host: admin.com
     path: /           |       |   |       path: /
                       v       |   |       v
              +-----------+    |   |    +-----------+
              | Frontend  |    |   |    | Admin     |
              | Service   |    |   |    | Service   |
              +-----------+    |   |    +-----------+
                               |   |
        host: api.example.com -+   +- host: shop.com
        path: /v1                     path: /images
                               |       |
                               v       v
                       +-----------+ +----------+
                       | API       | | Image    |
                       | Service   | | Service  |
                       +-----------+ +----------+
```

| Advantage | Detailed Explanation |
|---|---|
| Declarative (GitOps-friendly) | ALL routing rules are in a YAML file. Host-based routing, path-based routing, TLS certificates, rate limits, custom headers — everything is defined in code, version-controlled in Git, reviewable in PRs. |
| Cost Effective | ONE load balancer handles routing for ALL services. 10 services behind one LB = $20/month instead of $200/month. |
| Host-Based Routing | `shop.example.com` goes to frontend, `api.example.com` goes to API, `admin.example.com` goes to admin panel — all through ONE LB. |
| Path-Based Routing | `example.com/` goes to frontend, `example.com/api/v1` goes to API service, `example.com/admin` goes to admin panel. |
| Flexible (Choose Your LB) | Want NGINX? Deploy NGINX Ingress Controller. Want AWS ALB? Deploy ALB Controller. Want Envoy? Use Istio. You pick the load balancer technology. |
| Works Everywhere | Works on Kind (with Cloud Provider KIND), Minikube (with minikube tunnel), bare-metal (with MetalLB), and any cloud. |

### 5.4 What is Ingress and Ingress Controller (Detailed)

**Key Concept:** Ingress Resource does NOTHING by itself. It is just a configuration document. It needs an Ingress Controller (a running pod) to read it and act on it.

```
  Analogy:
  ========
  Ingress Resource  = Menu card (describes what you want)
  Ingress Controller = Chef (reads the menu and actually cooks)
  Load Balancer      = Plate of food (the actual result)

  Without the Chef (Controller), the Menu (Ingress) is just paper.
```

**Ingress Resource Structure:**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ecommerce-ingress
  annotations:                          # Controller-specific configuration
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx               # Which controller should read this
  rules:
    - host: shop.example.com            # Host-based routing (optional)
      http:
        paths:
          - path: /                     # Path-based routing
            pathType: Prefix
            backend:
              service:
                name: frontend-service  # Target service
                port:
                  number: 8080          # Service port
    - host: api.example.com
      http:
        paths:
          - path: /v1
            pathType: Prefix
            backend:
              service:
                name: api-service
                port:
                  number: 8080
```

| Field | Purpose |
|-------|--------|
| metadata.annotations | Controller-specific settings (TLS, rate limits, CORS, etc.). Different per controller. |
| spec.ingressClassName | Tells which controller should process this Ingress. If you have NGINX + ALB controllers running, this selects one. |
| spec.rules[].host | Route by domain name. If omitted, matches ALL hosts. |
| spec.rules[].http.paths[].path | Route by URL path |
| spec.rules[].http.paths[].pathType | `Prefix` (matches /foo and /foo/bar) or `Exact` (matches only /foo) |
| backend.service.name | Kubernetes Service to forward traffic to |
| backend.service.port.number | Port on that Service |

**Ingress Controller Architecture:**

```
  +------------------------------------------------------------------+
  |  KUBERNETES CLUSTER                                               |
  |                                                                    |
  |  +-----------------------------+                                  |
  |  | Ingress Controller Pod      |                                  |
  |  | (e.g., NGINX, ALB, Traefik) |                                  |
  |  |                             |                                  |
  |  | 1. Watches K8s API for      |                                  |
  |  |    Ingress resources        |                                  |
  |  | 2. Reads routing rules      |                                  |
  |  | 3. Configures load balancer |                                  |
  |  | 4. Updates when rules change|                                  |
  |  +-----------------------------+                                  |
  |         |                                                          |
  |         | creates/configures                                       |
  |         v                                                          |
  |  +-----------------------------+                                  |
  |  | Load Balancer               |                                  |
  |  | (NGINX reverse proxy,       |                                  |
  |  |  AWS ALB, Envoy, etc.)      |                                  |
  |  |                             |                                  |
  |  | Routing table:              |                                  |
  |  |  shop.com/     -> svc-A     |                                  |
  |  |  api.com/v1    -> svc-B     |                                  |
  |  |  admin.com/    -> svc-C     |                                  |
  |  +-----------------------------+                                  |
  |         |        |        |                                        |
  |         v        v        v                                        |
  |     svc-A    svc-B    svc-C                                       |
  |     (pods)   (pods)   (pods)                                      |
  +------------------------------------------------------------------+
```

**Why ingressClassName matters:**

In production, you might have multiple controllers:
- Team A uses NGINX Ingress Controller
- Team B uses AWS ALB Controller

```yaml
# Team A's Ingress (processed by NGINX)
spec:
  ingressClassName: nginx

# Team B's Ingress (processed by ALB Controller)
spec:
  ingressClassName: alb
```

Each controller only watches Ingress resources that match its class name.

### 5.5 LoadBalancer vs Ingress - When to Use Which

| Scenario | Use LoadBalancer | Use Ingress |
|----------|-----------------|------------|
| Quick testing, single service | Yes | Overkill |
| Production with multiple services | No (too expensive) | Yes |
| Need host/path routing | Not possible | Yes |
| Need TLS termination (HTTPS) | Manual config | Declarative via YAML |
| Non-cloud cluster (Kind, bare-metal) | Needs MetalLB/CPK | Works natively |
| TCP/UDP traffic (non-HTTP) | Yes (only option) | No (Ingress is HTTP only) |
| Interview answer | Easy to configure, not scalable | Production-grade, declarative, cost-effective |

---


## Part 6 - Deploy Ingress (AWS ALB Controller)

> Note: This section covers Ingress deployment for both Kind (lab) and EKS (production). The ALB Controller steps apply specifically to AWS EKS clusters.

### 6.1 For Kind Cluster - Deploy Ingress for Our E-Commerce Application

In this section, we deploy an Ingress resource for the OpenTelemetry Demo e-commerce application that is already running in our Kind cluster.

#### 6.1.1 How Ingress Works on Kind (with Cloud Provider KIND)

With Cloud Provider KIND v0.9.0+, you do NOT need to install any separate ingress controller (no NGINX, no Traefik). Cloud Provider KIND itself acts as the ingress controller.

```
  Cloud Provider KIND as Ingress Controller:
  ==========================================

  +------------------------------------------------------------------+
  |  EC2 HOST                                                         |
  |                                                                    |
  |  cloud-provider-kind (binary running on host)                     |
  |      |                                                             |
  |      | 1. Watches K8s API for Ingress resources                    |
  |      | 2. Reads routing rules from Ingress YAML                    |
  |      | 3. Creates a Docker container with reverse proxy            |
  |      v                                                             |
  |  +--------------------------------------------------------------+ |
  |  |  Docker Network (kind: 172.18.0.0/16)                         | |
  |  |                                                                | |
  |  |  +---------------------+                                      | |
  |  |  | Reverse Proxy       |  (Docker container created by CPK)   | |
  |  |  | IP: 172.18.0.6      |                                      | |
  |  |  | Port: 80            |                                      | |
  |  |  |                     |                                      | |
  |  |  | Routing:            |                                      | |
  |  |  |  /foo -> foo-svc    |                                      | |
  |  |  |  /bar -> bar-svc    |                                      | |
  |  |  +----------+----------+                                      | |
  |  |             |                                                  | |
  |  |             | routes to K8s Services                           | |
  |  |             v                                                  | |
  |  |  +----------------+  +----------------+  +----------------+   | |
  |  |  | control-plane  |  | worker-1       |  | worker-2       |   | |
  |  |  | (pods/services)|  | (pods/services)|  | (pods/services)|   | |
  |  |  +----------------+  +----------------+  +----------------+   | |
  |  +--------------------------------------------------------------+ |
  +------------------------------------------------------------------+
```

#### 6.1.2 The Port Conflict Problem

Our Kind cluster config maps port 80 and 443 from EC2 host to the control-plane container:

```yaml
# From our kind-istio-cluster.yaml:
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 80
        hostPort: 80          # EC2:80 -> control-plane:80
      - containerPort: 443
        hostPort: 443         # EC2:443 -> control-plane:443
```

**The issue:** Cloud Provider KIND creates its ingress proxy on port 80, but that port is already mapped to the control-plane container. So the ingress proxy container gets its OWN Docker IP (172.18.0.x) and listens on port 80 THERE.

```
  Port 80 mapping (current state):
  ================================

  EC2:80  ---------->  control-plane container:80  (via extraPortMappings)
                       (nothing is listening on port 80 inside control-plane yet)

  Ingress proxy:       172.18.0.6:80  (separate Docker container)
                       (reachable from EC2 host, NOT from internet directly)
```

**Solutions to access Ingress from browser:**

| Solution | How | When to Use |
|----------|-----|------------|
| curl from EC2 | `curl http://172.18.0.6/foo` | Quick testing on server |
| Port-forward | `kubectl port-forward` | When you need browser access |
| Istio Gateway on NodePort | Uses extraPortMappings 80/443 directly | Production setup (next module) |

**Why port 80 on EC2 does not conflict:**
- The extraPortMappings maps EC2:80 to control-plane-container:80
- BUT nothing is listening on port 80 INSIDE the control-plane container yet
- The Ingress proxy is a SEPARATE Docker container (not inside control-plane)
- When we later install Istio, the Istio Ingress Gateway pod WILL listen on port 80 inside the control-plane (via NodePort), and THAT will use the extraPortMappings correctly

#### 6.1.3 Deploy Ingress for Our E-Commerce Frontend

**Step 1: Verify the application is running**

```bash
# All pods should be Running
kubectl get pods | grep -c Running

# Frontend proxy service exists
kubectl get svc opentelemetry-demo-frontendproxy
```

**Step 2: Make sure frontendproxy is ClusterIP (not LoadBalancer)**

```bash
# If you previously patched it to LoadBalancer, revert it
kubectl patch svc opentelemetry-demo-frontendproxy -p '{"spec": {"type": "ClusterIP"}}'
```

When using Ingress, the backend service should be ClusterIP. The Ingress controller/proxy handles external access.

**Step 3: Create the Ingress resource for our app**

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ecommerce-ingress
spec:
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: opentelemetry-demo-frontendproxy
                port:
                  number: 8080
EOF
```

This tells the ingress: "Route ALL HTTP traffic on path `/` to the `opentelemetry-demo-frontendproxy` service on port 8080."

**Step 4: Wait for Ingress to get an IP**

```bash
kubectl get ingress ecommerce-ingress -w
```

Expected (wait 10-30 seconds):
```
NAME                 CLASS    HOSTS   ADDRESS      PORTS   AGE
ecommerce-ingress    <none>   *       172.18.0.6   80      30s
```

If ADDRESS stays empty, check that cloud-provider-kind is running:
```bash
ps aux | grep cloud-provider-kind
# If not running:
sudo cloud-provider-kind &
```

**Step 5: Test from EC2 host**

```bash
# Get the Ingress IP
INGRESS_IP=$(kubectl get ingress ecommerce-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Ingress IP: ${INGRESS_IP}"

# Test - should return HTML from the e-commerce frontend
curl -s http://${INGRESS_IP}/ | head -20

# Or just check HTTP status
curl -o /dev/null -s -w "%{http_code}" http://${INGRESS_IP}/
# Expected: 200
```

**Step 6: Access from your browser (via port-forward)**

Since the Ingress IP (172.18.0.x) is only reachable from the EC2 host, use port-forward for browser access:

```bash
# Forward EC2:8080 to the frontendproxy service
nohup kubectl port-forward svc/opentelemetry-demo-frontendproxy 8080:8080 --address=0.0.0.0 &>/dev/null &

echo "Access from browser: http://<EC2-ELASTIC-IP>:8080"
```

Or, forward the Ingress itself (if it supports it):
```bash
# Alternative: Forward to the Ingress port directly
nohup kubectl port-forward svc/opentelemetry-demo-frontendproxy 80:8080 --address=0.0.0.0 &>/dev/null &
echo "Access from browser: http://<EC2-ELASTIC-IP>"
```

Note: Port 80 on EC2 must be open in the Security Group.

#### 6.1.4 Complete Flow Diagram for Our Application

```
  Method 1: curl from EC2 (direct to Ingress proxy)
  ==================================================

  EC2 terminal
      |
      | curl http://172.18.0.6/
      v
  Docker network (kind)
      |
      v
  Ingress Proxy Container (172.18.0.6:80)
      |
      | routes path: / -> opentelemetry-demo-frontendproxy:8080
      v
  opentelemetry-demo-frontendproxy Service (ClusterIP)
      |
      | selector matches pod labels
      v
  frontendproxy Pod (Envoy reverse proxy)
      |
      | routes internally to frontend, cart, checkout, etc.
      v
  All 20+ microservice pods


  Method 2: Browser via port-forward
  ===================================

  Your Browser
      |
      | http://3.111.87.86:8080
      v
  EC2 Elastic IP:8080
      |
      | kubectl port-forward (bridges network gap)
      v
  opentelemetry-demo-frontendproxy Service:8080
      |
      v
  frontendproxy Pod
      |
      v
  All microservices


  Method 3: (Future - Istio) Browser via extraPortMappings
  =========================================================

  Your Browser
      |
      | http://3.111.87.86 (port 80)
      v
  EC2:80
      |
      | extraPortMappings: hostPort 80 -> containerPort 80
      v
  Kind control-plane container:80
      |
      | NodePort routing to Istio Ingress Gateway
      v
  Istio Ingress Gateway Pod (Envoy)
      |
      | VirtualService routing rules
      v
  opentelemetry-demo-frontendproxy Service
      |
      v
  All microservices (with Envoy sidecars for mTLS, tracing, etc.)
```

#### 6.1.5 Add Host-Based Routing (Optional - Advanced)

To test host-based routing without a real domain:

```bash
# Create Ingress with host rule
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ecommerce-ingress-host
spec:
  rules:
    - host: shop.local              # Only responds to this hostname
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: opentelemetry-demo-frontendproxy
                port:
                  number: 8080
EOF

# Wait for IP
kubectl get ingress ecommerce-ingress-host -w

# Test WITH correct host header (works)
INGRESS_IP=$(kubectl get ingress ecommerce-ingress-host -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl -H "Host: shop.local" http://${INGRESS_IP}/
# Expected: 200 OK, returns HTML

# Test WITHOUT host header (fails - 404)
curl http://${INGRESS_IP}/
# Expected: 404 Not Found (host doesn't match)

# Test with wrong host (fails)
curl -H "Host: wrong.com" http://${INGRESS_IP}/
# Expected: 404 Not Found
```

This demonstrates host-based routing — the SAME IP returns different responses based on the `Host` header. In production, DNS resolves `shop.example.com` to the LB IP, so the browser automatically sends the correct Host header.

#### 6.1.6 Cleanup Ingress Resources

```bash
kubectl delete ingress ecommerce-ingress
kubectl delete ingress ecommerce-ingress-host 2>/dev/null
```

#### 6.1.7 Why We Will Use Istio Gateway Instead of Kubernetes Ingress

Kubernetes Ingress has limitations:
- Only supports HTTP/HTTPS (no TCP/gRPC natively)
- Limited traffic management (no canary, no retries, no fault injection)
- No mutual TLS between services
- No distributed tracing

Istio Gateway + VirtualService provides:
- Full HTTP, HTTPS, TCP, gRPC support
- Traffic shifting (90% v1, 10% v2)
- Fault injection for testing
- Retries with configurable policies
- Circuit breaking
- Mutual TLS everywhere
- Distributed tracing with Jaeger
- Metrics with Prometheus/Grafana

```
  Kubernetes Ingress:               Istio Gateway:
  ===================               ==============
  - Routes HTTP only                - Routes HTTP, HTTPS, TCP, gRPC
  - Basic path/host routing         - Canary, blue-green, A/B routing
  - No traffic policies             - Retries, timeouts, circuit breaking
  - No security mesh                - mTLS between all services
  - No observability                - Kiali, Grafana, Jaeger, Prometheus
  - No fault injection              - Inject delays, errors for testing
```

This is WHY we are learning Istio — it replaces basic Ingress with a full-featured service mesh.

### 6.2 For EKS Cluster (Production Reference)

When running on Amazon EKS, the AWS Load Balancer Controller provisions ALBs (Application Load Balancers) for Ingress resources.

**Step 1: Setup OIDC Connector**

```bash
export cluster_name=<your-cluster-name>

# Get OIDC ID
oidc_id=$(aws eks describe-cluster --name $cluster_name --query "cluster.identity.oidc.issuer" --output text | cut -d '/' -f 5)

# Check if already associated
aws iam list-open-id-connect-providers | grep $oidc_id | cut -d "/" -f4

# Associate OIDC provider
eksctl utils associate-iam-oidc-provider --cluster $cluster_name --approve
```

**Step 2: Download IAM Policy**

```bash
curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.11.0/docs/install/iam_policy.json
```

**Step 3: Create IAM Policy**

```bash
aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam_policy.json
```

**Step 4: Create IAM Role and Service Account**

```bash
eksctl create iamserviceaccount \
  --cluster=$cluster_name \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --attach-policy-arn=arn:aws:iam::<account-id>:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve
```

**Step 5: Install ALB Controller via Helm**

```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update eks

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$cluster_name \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=<region> \
  --set vpcId=<vpc-id>
```

**Step 6: Verify Installation**

```bash
kubectl get deployment -n kube-system aws-load-balancer-controller
kubectl get pods -n kube-system | grep aws-load-balancer
```

### 6.3 Create Ingress Resource for Frontend Proxy

Once the Ingress Controller is running, create an Ingress resource to route traffic to the frontend proxy:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: frontend-proxy
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
spec:
  ingressClassName: alb
  rules:
    - host: example.com
      http:
        paths:
          - path: "/"
            pathType: Prefix
            backend:
              service:
                name: opentelemetry-demo-frontendproxy
                port:
                  number: 8080
```

```bash
kubectl apply -f ingress.yaml
kubectl get ingress

# Wait for ALB DNS to appear in ADDRESS column
kubectl get ingress frontend-proxy -w
```

### 6.4 Custom Domain with Route 53 (Production)

To map a custom domain to the Ingress load balancer:

1. Get the ALB DNS name from `kubectl get ingress` (ADDRESS column)
2. Open AWS Route 53 console
3. Navigate to your Hosted Zone
4. Create an A record with Alias enabled
5. Point the alias to the Application Load Balancer
6. Select the correct region and ALB from the dropdown

This allows users to access the application via a friendly domain name (e.g., `shop.techmahato.com`) instead of the raw ALB DNS.

---


## Part 7 - Troubleshooting

### Common Issues

| Issue | Cause | Fix |
|---|---|---|
| Pods in Pending | Insufficient CPU/memory resources | Scale down replicas or use a bigger instance type |
| ImagePullBackOff | Image not found or registry auth issue | Verify image name and tag. Check `kubectl describe pod` for details |
| CrashLoopBackOff | Application error or missing environment variables | Check logs: `kubectl logs <pod-name>` |
| Service not reachable | Wrong selector or port mismatch | Verify labels match between Deployment and Service |
| LB IP stays Pending | Cloud Provider KIND not running | Start it: `sudo cloud-provider-kind &` |
| Ingress no address | Ingress controller not deployed | Deploy an ingress controller first |
| Pods evicted | Node disk pressure or memory pressure | Check node conditions: `kubectl describe node` |

### Useful Debugging Commands

```bash
# List all pods with status
kubectl get pods

# Detailed pod information (events, conditions, volumes)
kubectl describe pod <pod-name>

# View container logs (current)
kubectl logs <pod-name>

# View container logs (previous crashed instance)
kubectl logs <pod-name> --previous

# Cluster events sorted by time
kubectl get events --sort-by='.lastTimestamp'

# List all services and endpoints
kubectl get svc
kubectl get endpoints

# Check ingress status
kubectl get ingress

# Exec into a pod for network debugging
kubectl exec -it <pod-name> -- /bin/sh
```

---

## Part 8 - Cleanup

Remove all deployed resources when finished:

```bash
# Delete all deployed resources
kubectl delete -f complete-deploy.yaml

# Delete the service account
kubectl delete -f serviceaccount.yaml

# If ingress was created
kubectl delete -f ingress.yaml

# Verify everything is removed
kubectl get pods
kubectl get svc
kubectl get ingress
```

---

## References

| Resource | URL |
|---|---|
| OpenTelemetry Demo | https://opentelemetry.io/docs/demo/ |
| OTel Demo Architecture | https://opentelemetry.io/docs/demo/architecture/ |
| OTel Demo GitHub | https://github.com/open-telemetry/opentelemetry-demo |
| Kubernetes Deployments | https://kubernetes.io/docs/concepts/workloads/controllers/deployment/ |
| Kubernetes Services | https://kubernetes.io/docs/concepts/services-networking/service/ |
| Kubernetes Ingress | https://kubernetes.io/docs/concepts/services-networking/ingress/ |
| AWS LB Controller | https://kubernetes-sigs.github.io/aws-load-balancer-controller/ |
| Kind LoadBalancer | https://kind.sigs.k8s.io/docs/user/loadbalancer/ |
| Kind Ingress | https://kind.sigs.k8s.io/docs/user/ingress/ |

---

## Credits and Connect

| Platform | Link |
|----------|------|
| YouTube | [TECH MAHATO](https://www.youtube.com/techmahato) |
| Medium Blog | [Tech Mahato on Medium](https://medium.com/@techmahato) |
| LinkedIn | [Arbind Kr. Mahato](https://www.linkedin.com/in/arbindmahato/) |
| Website | [techmahato.com](https://techmahato.com) |
| GitHub | [techmahato](https://github.com/techmahato) |

---

> If this helped you, please Star the repo and Subscribe to [TECH MAHATO on YouTube](https://www.youtube.com/techmahato).
>
> **Next:** Move to `003-Istio-Installation` to install Istio service mesh on top of this deployed application.
