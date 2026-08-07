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


## Part 5 - LoadBalancer vs Ingress

### 5.1 Disadvantages of LoadBalancer Service Type

| Disadvantage | Explanation |
|---|---|
| Not Declarative | Load balancer configuration cannot be fully managed via YAML. Changes require patching or cloud console. |
| Cost Inefficient | Each service with type LoadBalancer creates a separate cloud load balancer. At scale with 20+ services, this becomes extremely expensive. |
| Limited Flexibility | Tied directly to the cloud provider's Cloud Controller Manager implementation. |
| No Host/Path Routing | Cannot route traffic based on domain names or URL paths. One LB serves one service only. |
| Not Portable | Does not work on non-cloud clusters (bare-metal, on-prem) without additional tooling like MetalLB or Cloud Provider KIND. |

### 5.2 Advantages of Ingress

| Advantage | Explanation |
|---|---|
| Declarative | Full YAML-based configuration. Routing rules are version-controlled and reproducible. |
| Cost Effective | One load balancer serves multiple services using host-based and path-based routing. |
| Flexible | Choose any ingress controller (NGINX, AWS ALB, Traefik, Envoy, Kong). Not locked to one vendor. |
| Host-Based Routing | Route traffic by domain name (shop.example.com, api.example.com, admin.example.com). |
| Path-Based Routing | Route traffic by URL path (/api to backend, /web to frontend, /admin to admin panel). |
| Not Dependent on CCM | Works on any Kubernetes cluster regardless of cloud provider or bare-metal setup. |

### 5.3 What is Ingress and Ingress Controller

**Ingress Resource:**

An Ingress is a Kubernetes API object that defines HTTP/HTTPS routing rules. It specifies which service should receive traffic based on the hostname and path in the incoming request. The Ingress resource itself does nothing without a controller.

**Ingress Controller:**

An Ingress Controller is a pod running in the cluster that watches for Ingress resources and configures the actual load balancer/reverse proxy accordingly. It is the implementation that makes Ingress rules work.

```
Ingress Resource (YAML)  --->  Ingress Controller (Pod)  --->  Load Balancer (Actual Routing)
   (What you want)               (Reads and acts)                (What gets created)
```

**Important:** Kubernetes is NOT opinionated about which Ingress Controller to use. You must install one yourself.

**Popular Ingress Controllers:**

| Controller | Maintained By | Best For |
|-----------|---------------|----------|
| NGINX Ingress | Kubernetes community | General purpose, widely adopted |
| AWS ALB Controller | AWS | Native ALB integration on EKS |
| Traefik | Traefik Labs | Auto-discovery, Let's Encrypt |
| Kong | Kong Inc. | API Gateway features |
| Istio Gateway | Istio project | Service mesh environments |

```
  Ingress Resource + Ingress Controller Flow:
  ============================================

  DevOps Engineer writes:
  +------------------+
  | Ingress Resource |  (YAML file with routing rules)
  | - host: shop.com |  (host-based routing)
  | - path: /api     |  (path-based routing)
  | - backend: svc   |  (target service)
  | - annotations    |  (LB configuration)
  +--------+---------+
           |
           | watches and reads
           v
  +--------------------+
  | Ingress Controller |  (e.g., AWS ALB Controller, NGINX, Traefik)
  | (Kubernetes Pod)   |
  +--------+-----------+
           |
           | creates and configures
           v
  +------------------+
  | Load Balancer    |  (AWS ALB, NGINX LB, F5, etc.)
  | - Host routing   |
  | - Path routing   |
  | - TLS/HTTPS      |
  +--------+---------+
           |
           | routes traffic to
           v
  +------------------+
  | Kubernetes       |
  | Service          |  (ClusterIP type is sufficient)
  +--------+---------+
           |
           | forwards to pods via labels
           v
  +------------------+
  | Backend Pods     |
  +------------------+

  Popular Ingress Controllers:
  +----------------------+----------------------------+
  | Ingress Controller   | Creates Load Balancer      |
  +----------------------+----------------------------+
  | AWS ALB Controller   | AWS Application LB         |
  | NGINX Ingress        | NGINX Load Balancer        |
  | Traefik              | Traefik Proxy              |
  | Kong                 | Kong API Gateway           |
  | Istio Gateway        | Envoy-based Gateway        |
  +----------------------+----------------------------+
```

---


## Part 6 - Deploy Ingress (AWS ALB Controller)

> Note: This section covers Ingress deployment for both Kind (lab) and EKS (production). The ALB Controller steps apply specifically to AWS EKS clusters.

### 6.1 For Kind Cluster (Our Lab)

With Cloud Provider KIND v0.9.0+, Ingress is natively supported. The cloud-provider-kind binary handles both LoadBalancer IPs and Ingress routing.

```bash
# Deploy ingress example to verify functionality
kubectl apply -f https://kind.sigs.k8s.io/examples/ingress/usage.yaml

# Wait for ingress to get an IP
kubectl get ingress -w

# Verify routing works
INGRESS_IP=$(kubectl get ingress example-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl ${INGRESS_IP}/foo
curl ${INGRESS_IP}/bar
```

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
