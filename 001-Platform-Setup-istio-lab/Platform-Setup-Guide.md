# 01 - Platform Setup Guide for Istio Practice Lab | TECH MAHATO

> **Production-Ready Lab Environment for Istio Service Mesh on AWS EC2 with Kind Cluster**
>
> By **Arbind Kr. Mahato** | Cloud and DevOps Engineer | AWS Certified | CKA and CKAD | AWS Community Builder
>
> [TECH MAHATO YouTube](https://www.youtube.com/techmahato) | [Medium Blog](https://medium.com/@techmahato) | [LinkedIn](https://www.linkedin.com/in/arbindmahato/)

---

**Objective:** Provision a complete platform environment for practicing Istio service mesh -- covering OS infrastructure, Kubernetes cluster deployment, and essential CLI tooling.

**Istio Version:** 1.30.3 (Current)
**Last Validated:** August 2026

---

## Table of Contents

- [Prerequisites](#prerequisites)
- [Part 1 - Launch OS Platform](#part-1---launch-os-platform)
  - [Option 1: AWS EC2 Instance (Used for Demonstration)](#option-1-aws-ec2-instance-used-for-demonstration)
  - [Option 2: VirtualBox Virtual Machine](#option-2-virtualbox-virtual-machine)
- [Part 2 - SSH Access Setup (Connect from Local Machine)](#part-2---ssh-access-setup-connect-from-local-machine)
- [Part 3 - Install Required Tools](#part-3---install-required-tools)
  - [3.1 System Update](#31-system-update)
  - [3.2 Install Docker](#32-install-docker)
  - [3.3 Install kubectl](#33-install-kubectl)
  - [3.4 Install Helm](#34-install-helm)
  - [3.5 Install Go](#35-install-go)
- [Part 4 - Setup Kubernetes Platform (kind)](#part-4---setup-kubernetes-platform-kind)
  - [Architecture Overview](#architecture-overview)
  - [Why This Configuration](#why-this-configuration)
  - [4.1 Install kind](#41-install-kind)
  - [4.2 Cluster Configuration File](#42-cluster-configuration-file)
  - [4.3 Create the Cluster](#43-create-the-cluster)
  - [4.4 Setup Cloud Provider KIND for LoadBalancer](#44-setup-cloud-provider-kind-for-loadbalancer)
  - [4.5 Remove Control Plane Exclusion Label](#45-remove-control-plane-exclusion-label)
  - [4.6 Verify LoadBalancer Support](#46-verify-loadbalancer-support)
  - [4.7 Troubleshooting Cloud Provider KIND](#47-troubleshooting-cloud-provider-kind)
- [Part 5 - Verify Cluster Topology](#part-5---verify-cluster-topology)
  - [5.1 Check Nodes and Labels](#51-check-nodes-and-labels)
  - [5.2 Verify Node Labels](#52-verify-node-labels)
  - [5.3 Check System Pods Distribution](#53-check-system-pods-distribution)
  - [5.4 Verify Port Mappings](#54-verify-port-mappings)
  - [5.5 Verify External Access](#55-verify-external-access-from-ec2-host)
- [Part 6 - Understanding the Configuration](#part-6---understanding-the-configuration)
  - [6.1 extraPortMappings](#61-extraportmappings)
  - [6.2 Node Labels](#62-node-labels)
  - [6.3 listenAddress Security Consideration](#63-listenaddress-0000-security-consideration)
  - [6.4 Topology Labels](#64-topology-labels)
- [Part 7 - Install Istio CLI (istioctl)](#part-7---install-istio-cli-istioctl)
- [Part 8 - Kind Command Reference](#part-8---kind-command-reference)
  - [8.1 Cluster Information Commands](#81-cluster-information-commands)
  - [8.2 Inspect Current Cluster](#82-inspect-current-cluster)
  - [8.3 Node Label Management](#83-node-label-management)
  - [8.4 Create a New Cluster](#84-create-a-new-cluster)
  - [8.5 Load Docker Images into Kind](#85-load-docker-images-into-kind)
  - [8.6 Cluster Lifecycle Management](#86-cluster-lifecycle-management)
  - [8.7 Debugging Commands](#87-debugging-commands)
  - [8.8 Multiple Clusters on Same Host](#88-multiple-clusters-on-same-host)
  - [8.9 Backup and Restore Cluster Config](#89-backup-and-restore-cluster-config)
  - [8.10 Quick Reference Table](#810-quick-reference-table)
- [Part 9 - Kind Administration Guide](#part-9---kind-administration-guide)
  - [9.1 Local Container Registry](#91-local-container-registry)
  - [9.2 Ingress Setup](#92-ingress-setup)
  - [9.3 Resource Management](#93-resource-management)
  - [9.4 Networking Administration](#94-networking-administration)
  - [9.5 Storage Administration](#95-storage-administration)
  - [9.6 Node Administration](#96-node-administration)
  - [9.7 Known Issues and Fixes](#97-known-issues-and-fixes)
- [Part 10 - Cleanup](#part-10---cleanup)
- [Appendix A - Minimal kind Configuration (Single Node)](#appendix-a---minimal-kind-configuration-single-node)
- [Appendix B - High Availability kind Configuration](#appendix-b---high-availability-kind-configuration)
- [Appendix C - Alternative Kubernetes Platforms](#appendix-c---alternative-kubernetes-platforms)
- [Troubleshooting](#troubleshooting)
- [References](#references)
- [Credits and Connect](#credits-and-connect)

---

## Prerequisites

| Requirement | Details |
|-------------|---------|
| AWS Account (Option 1) | IAM permissions for EC2, VPC, SSM |
| VirtualBox 7.x+ (Option 2) | Installed on host machine |
| Internet Access | Required for downloading packages and container images |
| VS Code | With Remote-SSH or AWS SSM extension |
| Foundational Knowledge | Linux CLI, Docker basics, Kubernetes fundamentals |

---


## Part 1 - Launch OS Platform

### Option 1: AWS EC2 Instance (Used for Demonstration)

> This is the option used throughout this lab series.

#### Instance Specifications

| Parameter | Value |
|-----------|-------|
| AMI | Ubuntu 24.04 LTS (HVM, SSD Volume Type) |
| Instance Type | t3a.xlarge (4 vCPU, 16 GB RAM) |
| Storage | 100 GB gp3 EBS Volume |
| Network | Public Subnet with Elastic IP |
| IAM Role | Instance Profile with SSM access |
| Security Group | Custom SG (details below) |

#### Step 1.1: Create IAM Role for SSM Access

1. Navigate to IAM Console, then Roles, then Create Role.
2. Select Trusted Entity: AWS Service, then EC2.
3. Attach managed policy: `AmazonSSMManagedInstanceCore`
4. Name the role: `EC2-SSM-Role`
5. Create the role.

#### Step 1.2: Create Custom Security Group

Create a Security Group with the following inbound rules:

| Rule | Port Range | Protocol | Source | Purpose |
|------|-----------|----------|--------|---------|
| SSH | 22 | TCP | Your IP | Terminal access |
| HTTP | 80 | TCP | Your IP | Ingress Gateway HTTP |
| HTTPS | 443 | TCP | Your IP | Ingress Gateway HTTPS |
| Custom TCP | 8080 | TCP | Your IP | Application endpoints |
| Custom TCP | 15000-15090 | TCP | Your IP | Envoy admin and telemetry |
| Custom TCP | 20001 | TCP | Your IP | Kiali dashboard |
| Custom TCP | 3000 | TCP | Your IP | Grafana dashboard |
| Custom TCP | 9090 | TCP | Your IP | Prometheus |
| Custom TCP | 16686 | TCP | Your IP | Jaeger tracing UI |
| Custom TCP | 30000-32767 | TCP | Your IP | Kubernetes NodePort range |

**Security note:** Restrict all source IPs to your own IP address. Do not open ports to 0.0.0.0/0 unless required for external testing.

#### Step 1.3: Launch the EC2 Instance

1. Navigate to EC2 Console, then Launch Instance.
2. Configure:
   - Name: `istio-lab-server`
   - AMI: Ubuntu 24.04 LTS
   - Instance Type: t3a.xlarge
   - Key Pair: Select or create one
   - Network: Public subnet, attach custom Security Group
   - Storage: 100 GB gp3
   - Advanced Details: Select IAM Instance Profile `EC2-SSM-Role`
3. Launch the instance.

#### Step 1.4: Allocate and Associate Elastic IP

Via AWS Console:
1. Navigate to EC2, then Elastic IPs, then Allocate Elastic IP address.
2. Select the allocated IP, then Actions, then Associate Elastic IP address.
3. Choose the instance and confirm.

Via AWS CLI:
```bash
aws ec2 allocate-address --domain vpc --region ap-south-1
aws ec2 associate-address --instance-id <instance-id> --allocation-id <eip-alloc-id> --region ap-south-1
```

#### Step 1.5: Connect to the Instance

Quick connection test via SSH:
```bash
ssh -i "your-key.pem" ubuntu@<elastic-ip>
```

For detailed SSH setup including VS Code Remote-SSH integration, SSM-based access, port forwarding, and troubleshooting, see [Part 2 - SSH Access Setup](#part-2---ssh-access-setup-connect-from-local-machine).

---

### Option 2: VirtualBox Virtual Machine

Use this option for a local environment without cloud costs.

#### VM Specifications

| Parameter | Value |
|-----------|-------|
| OS | Ubuntu 24.04 LTS Server |
| RAM | 8 GB minimum (16 GB recommended) |
| CPU | 4 cores |
| Disk | 100 GB dynamically allocated VDI |
| Network | Bridged Adapter or NAT with Port Forwarding |

#### Setup Steps

1. Download Ubuntu 24.04 Server ISO from https://ubuntu.com/download/server
2. Create VM in VirtualBox:
   - Type: Linux, Version: Ubuntu (64-bit)
   - Memory: 8192 MB minimum
   - Hard Disk: Create VDI, dynamically allocated, 100 GB
3. Mount ISO and complete Ubuntu installation.
4. Post-install configuration:

```bash
sudo apt update && sudo apt install -y openssh-server
sudo systemctl enable ssh && sudo systemctl start ssh
ip addr show    # Note the VM IP address
```

5. If using NAT, configure port forwarding in VirtualBox:
   - Host 2222 -> Guest 22 (SSH)
   - Host 8080 -> Guest 8080 (Apps)
   - Host 80 -> Guest 80 (Ingress)

6. Connect from VS Code Remote-SSH:
```
Host istio-vm
    HostName 127.0.0.1
    Port 2222
    User <your-username>
```


---

## Part 2 - SSH Access Setup (Connect from Local Machine)

Throughout this lab series, all commands are executed on the remote EC2 instance — not on the local machine. This section covers establishing a reliable SSH connection from your local Windows workstation using VS Code.

### Why SSH for This Lab

| Benefit | Explanation |
|---------|-------------|
| Remote terminal access | Execute Docker, kubectl, istioctl commands directly on the server |
| VS Code integration | Edit files, browse directories, and run terminals on the remote machine as if it were local |
| File transfer | SCP/SFTP support for copying manifests and configs between local and remote |
| Port forwarding | Access Kiali, Grafana, Prometheus dashboards running on the remote server via localhost |
| Persistent sessions | Reconnect without losing context if network drops (combine with tmux/screen) |

### Prerequisites

| Requirement | Details |
|-------------|---------|
| EC2 Instance | Running with Elastic IP assigned (from Part 1) |
| Key Pair (.pem file) | Downloaded during EC2 launch |
| Security Group | Port 22 open to your IP address |
| VS Code | Installed on your Windows machine |
| OpenSSH Client | Built into Windows 10/11 (verify with `ssh -V` in PowerShell) |

### Step 1: Prepare the SSH Key on Windows

Locate the `.pem` key pair file downloaded during EC2 launch. Move it to a standard location:

```powershell
# Create .ssh directory if it does not exist
if (!(Test-Path "$HOME\.ssh")) { mkdir "$HOME\.ssh" }

# Copy the key to .ssh directory (adjust source path to your actual key location)
Copy-Item -Path "D:\Office-Arbind\POC-DevOps-Project\K8s-Arbind-KP.pem" -Destination "$HOME\.ssh\K8s-Arbind-KP.pem"
```

Fix file permissions (SSH rejects keys with open permissions):

```powershell
$keyPath = "$HOME\.ssh\K8s-Arbind-KP.pem"

# Remove all inherited permissions
icacls $keyPath /inheritance:r

# Grant read-only access to the current user only
icacls $keyPath /grant:r "$($env:USERNAME):(R)"
```

Verify permissions:
```powershell
icacls "$HOME\.ssh\K8s-Arbind-KP.pem"
```

Expected: Only your username with `(R)` permission listed.

### Step 2: Test Direct SSH Connection

```powershell
ssh -i "$HOME\.ssh\K8s-Arbind-KP.pem" ubuntu@<your-elastic-ip>
```

If connection fails:

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| Connection timed out | Security Group not allowing port 22 from your IP | Update inbound rule: Port 22, Source: Your IP |
| Permission denied (publickey) | Wrong key file or wrong username | Verify key matches what was selected at launch; user is `ubuntu` for Ubuntu AMI |
| Unprotected key file warning | Permissions not set correctly | Re-run icacls commands above |
| Host key verification failed | IP was previously used by another instance | Remove old entry: `ssh-keygen -R <elastic-ip>` |

### Step 3: Configure SSH Config File

Create or edit `C:\Users\<YourUsername>\.ssh\config`:

```
Host istio-lab
    HostName <your-elastic-ip>
    User ubuntu
    IdentityFile "C:\Users\Arbind Kr. Mahato\.ssh\K8s-Arbind-KP.pem"
    Port 22
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

**Important:** If your path contains spaces, wrap the IdentityFile value in quotes.

| Parameter | Purpose |
|-----------|---------|
| Host | Alias name — used in commands like `ssh istio-lab` |
| HostName | Actual IP address or DNS name of the server |
| User | Login username (`ubuntu` for Ubuntu AMI) |
| IdentityFile | Full path to the private key file (quote if spaces in path) |
| ServerAliveInterval | Send keepalive packet every 60 seconds to prevent idle disconnection |
| ServerAliveCountMax | Disconnect after 3 missed keepalive responses |

Test the named connection:
```powershell
ssh istio-lab
```

### Step 4: Connect via VS Code Remote-SSH

1. Install the **Remote - SSH** extension in VS Code (ID: `ms-vscode-remote.remote-ssh`).
2. Press `Ctrl+Shift+P`, type `Remote-SSH: Connect to Host...` and select it.
3. Select `istio-lab` from the dropdown list.
4. A new VS Code window opens. If prompted for platform, select `Linux`.
5. Press `` Ctrl+` `` to open the integrated terminal — it runs on the remote EC2 instance.

**Open Remote Folders:**
- Click File > Open Folder.
- Navigate to any path on the remote server (e.g., `/home/ubuntu`).
- VS Code file explorer now shows the remote filesystem.

### Step 5: Port Forwarding (Access Dashboards Locally)

When Istio observability tools are running on the remote server, access them on your local browser using VS Code port forwarding:

1. In the VS Code terminal, start a port-forward:
   ```bash
   kubectl port-forward svc/kiali -n istio-system 20001:20001
   ```
2. VS Code automatically detects the forwarded port.
3. Open `http://localhost:20001` in your local browser.

Common ports to forward:

| Service | Remote Port | Local Access |
|---------|-------------|--------------|
| Kiali | 20001 | http://localhost:20001 |
| Grafana | 3000 | http://localhost:3000 |
| Prometheus | 9090 | http://localhost:9090 |
| Jaeger | 16686 | http://localhost:16686 |

### Step 6: Alternative - SSM-Based SSH (No Port 22 Exposure)

For stronger security, AWS Systems Manager Session Manager can act as the SSH transport layer without exposing port 22.

| Aspect | Direct SSH (Port 22) | SSM-Based SSH |
|--------|----------------------|---------------|
| Open inbound port | Yes (port 22) | No |
| Requires public IP | Yes | No (works with private instances) |
| Audit logging | Manual setup | Automatic via CloudTrail |
| IAM-controlled access | No | Yes |

**Prerequisites:**
- AWS CLI v2 installed on Windows
- Session Manager Plugin installed (https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html)
- Instance has IAM role with `AmazonSSMManagedInstanceCore` policy

**SSH Config for SSM:**

```
Host istio-lab-ssm
    HostName <instance-id>
    User ubuntu
    IdentityFile "C:\Users\Arbind Kr. Mahato\.ssh\K8s-Arbind-KP.pem"
    ProxyCommand aws ssm start-session --target %h --document-name AWS-StartSSHSession --parameters portNumber=%p --region ap-south-1
```

Connect via VS Code Remote-SSH by selecting `istio-lab-ssm`. Once confirmed working, you can remove port 22 from the Security Group.

### Step 7: Post-Connection Verification

After connecting, verify the environment:

```bash
whoami                    # Should output: ubuntu
cat /etc/os-release | grep -E "^(NAME|VERSION)="
docker --version
kubectl version --client
kind version
df -h /
free -h
```


---


## Part 3 - Install Required Tools

Execute the following on the Ubuntu instance (EC2 or VM).

### 3.1 System Update

```bash
sudo apt update && sudo apt upgrade -y
```

### 3.2 Install Docker

Reference: https://docs.docker.com/engine/install/ubuntu/

```bash
# Remove conflicting packages
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
  sudo apt-get remove -y $pkg 2>/dev/null
done

# Add Docker official GPG key and repository
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Allow current user to run Docker without sudo
sudo usermod -aG docker $USER
newgrp docker

# Verify
docker --version
docker run --rm hello-world
```

### 3.3 Install kubectl

Reference: https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/

```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

# Verify
kubectl version --client
```

### 3.4 Install Helm

Reference: https://helm.sh/docs/intro/install/

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify
helm version
```

### 3.5 Install Go

Go is required for installing Cloud Provider KIND (used for LoadBalancer support in kind clusters).

```bash
# Download Go
curl -LO https://go.dev/dl/go1.23.0.linux-amd64.tar.gz

# Remove any previous Go installation and extract
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf go1.23.0.linux-amd64.tar.gz

# Clean up the archive
rm go1.23.0.linux-amd64.tar.gz

# Add Go to PATH permanently
echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> ~/.bashrc
export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin

# Verify Go installation
go version
```

Expected output: `go version go1.23.0 linux/amd64`


---


## Part 4 - Setup Kubernetes Platform (kind)

**Official Istio Docs:** https://istio.io/latest/docs/setup/platform-setup/kind/

kind (Kubernetes IN Docker) runs Kubernetes clusters as Docker containers. It is lightweight, fast to create and destroy, and suitable for local development, CI, and learning.

#### Prerequisites (per Istio docs)

- Docker installed and running
- Latest version of kind installed
- Sufficient Docker memory allocation (increase Docker memory limit if needed)

### Architecture Overview

```
                    +---------------------------+
                    |      EC2 Host Machine     |
                    |      (Ubuntu 24.04)       |
                    +---------------------------+
                    |         Docker            |
                    +---------------------------+
                              |
          +-------------------+-------------------+
          |                   |                   |
+---------+--------+ +-------+--------+ +--------+--------+
| control-plane    | | worker-1       | | worker-2        |
| (istio-ecommerce| | (frontend)     | | (backend)       |
|  -control-plane) | |                | |                 |
|                  | | Labels:        | | Labels:         |
| - API Server     | |  tier=frontend | |  tier=backend   |
| - etcd           | |  app=web       | |  app=services   |
| - Scheduler      | |                | |                 |
| - Controller Mgr | | Workloads:     | | Workloads:      |
|                  | | - Istio GW     | | - Product Svc   |
| Port Mappings:   | | - Web Frontend | | - Cart Svc      |
|  80 -> 80        | |                | | - Order Svc     |
|  443 -> 443      | |                | | - Payment Svc   |
+---------+--------+ +-------+--------+ +--------+--------+
          |                   |                   |
          +-------------------+-------------------+
                              |
                    +---------+----------+
                    | Cloud Provider KIND |
                    | (LoadBalancer)      |
                    +--------------------+
```

This topology separates concerns:
- **Control plane** handles cluster management and exposes ingress ports to the host.
- **Worker 1 (frontend)** runs Istio Ingress Gateway and user-facing services.
- **Worker 2 (backend)** runs backend microservices (product catalog, cart, orders, payments).

### Why This Configuration

| Design Decision | Rationale |
|----------------|-----------|
| Multi-node (1 CP + 2 Workers) | Simulates real cluster topology where workloads don't run on control plane |
| Node labels (tier: frontend/backend) | Enables nodeSelector and pod affinity, mimicking production placement strategies |
| extraPortMappings with listenAddress 0.0.0.0 | Allows access from outside the EC2 host (your browser via Elastic IP) |
| Port 80 and 443 on control-plane | Istio Ingress Gateway routes through these standard ports |
| Cloud Provider KIND for LoadBalancer | Istio Ingress Gateway uses type LoadBalancer; this makes it work on kind |
| kubeadmConfigPatches for node labels | Applies labels at node registration time (before any scheduling) |
| Separate worker for backend services | Demonstrates affinity/anti-affinity patterns used in e-commerce |

### 4.1 Install kind

Reference: https://kind.sigs.k8s.io/docs/user/quick-start/

```bash
# Download kind v0.32.0 (latest as of this writing)
[ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.32.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Verify
kind version
```

### 4.2 Cluster Configuration File

Create the file `kind-istio-cluster.yaml`:

```yaml
# kind-istio-cluster.yaml
# Production-like kind cluster for Istio service mesh with e-commerce workloads
#
# Architecture:
#   - 1 control-plane node (API server, etcd, scheduler, controller-manager)
#   - 1 frontend worker (Istio Ingress Gateway, web-facing services)
#   - 1 backend worker (microservices: product, cart, order, payment)
#
# Reference: https://kind.sigs.k8s.io/docs/user/configuration/
# Istio Ref: https://istio.io/latest/docs/setup/platform-setup/kind/

kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: istio-ecommerce

# ------------------------------------------------------------------
# Networking Configuration
# ------------------------------------------------------------------
networking:
  # Pod CIDR - default is 10.244.0.0/16
  podSubnet: "10.244.0.0/16"
  # Service CIDR - default is 10.96.0.0/16
  serviceSubnet: "10.96.0.0/16"
  # kube-proxy mode: iptables (default), nftables, or ipvs
  # ipvs provides better performance for large clusters
  kubeProxyMode: "iptables"

# ------------------------------------------------------------------
# Node Definitions
# ------------------------------------------------------------------
nodes:

  # --- Control Plane Node ---
  # Hosts API server, etcd, scheduler, controller-manager.
  # Port mappings allow external HTTP/HTTPS traffic to reach the cluster.
  - role: control-plane
    extraPortMappings:
      # HTTP traffic - maps to Istio Ingress Gateway (via NodePort or hostPort)
      - containerPort: 80
        hostPort: 80
        listenAddress: "0.0.0.0"    # Required for remote access (EC2)
        protocol: TCP
      # HTTPS traffic - maps to Istio Ingress Gateway
      - containerPort: 443
        hostPort: 443
        listenAddress: "0.0.0.0"
        protocol: TCP
      # NodePort range for direct service access during development
      - containerPort: 30080
        hostPort: 30080
        listenAddress: "0.0.0.0"
        protocol: TCP
      - containerPort: 30443
        hostPort: 30443
        listenAddress: "0.0.0.0"
        protocol: TCP
    # Labels for the control-plane node
    labels:
      topology.kubernetes.io/zone: "zone-a"
    kubeadmConfigPatches:
      - |
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"

  # --- Frontend Worker Node ---
  # Designated for Istio Ingress Gateway and user-facing services.
  # Use nodeSelector: { tier: frontend } in pod specs to target this node.
  - role: worker
    labels:
      tier: frontend
      app-type: web
      topology.kubernetes.io/zone: "zone-a"
    kubeadmConfigPatches:
      - |
        kind: JoinConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "tier=frontend,app-type=web"

  # --- Backend Worker Node ---
  # Designated for backend microservices (product, cart, order, payment).
  # Use nodeSelector: { tier: backend } in pod specs to target this node.
  - role: worker
    labels:
      tier: backend
      app-type: services
      topology.kubernetes.io/zone: "zone-b"
    kubeadmConfigPatches:
      - |
        kind: JoinConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "tier=backend,app-type=services"
```


### 4.3 Create the Cluster

#### Save the Configuration

```bash
mkdir -p ~/istio-lab/cluster
cat > ~/istio-lab/cluster/kind-istio-cluster.yaml << 'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: istio-ecommerce
networking:
  podSubnet: "10.244.0.0/16"
  serviceSubnet: "10.96.0.0/16"
  kubeProxyMode: "iptables"
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 80
        hostPort: 80
        listenAddress: "0.0.0.0"
        protocol: TCP
      - containerPort: 443
        hostPort: 443
        listenAddress: "0.0.0.0"
        protocol: TCP
      - containerPort: 30080
        hostPort: 30080
        listenAddress: "0.0.0.0"
        protocol: TCP
      - containerPort: 30443
        hostPort: 30443
        listenAddress: "0.0.0.0"
        protocol: TCP
    labels:
      topology.kubernetes.io/zone: "zone-a"
    kubeadmConfigPatches:
      - |
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"
  - role: worker
    labels:
      tier: frontend
      app-type: web
      topology.kubernetes.io/zone: "zone-a"
    kubeadmConfigPatches:
      - |
        kind: JoinConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "tier=frontend,app-type=web"
  - role: worker
    labels:
      tier: backend
      app-type: services
      topology.kubernetes.io/zone: "zone-b"
    kubeadmConfigPatches:
      - |
        kind: JoinConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "tier=backend,app-type=services"
EOF
```

#### Delete Existing Cluster (if any)

```bash
kind delete cluster --name istio-testing 2>/dev/null
kind delete cluster --name istio-ecommerce 2>/dev/null
```

#### Create the Cluster

```bash
kind create cluster --config ~/istio-lab/cluster/kind-istio-cluster.yaml
```

Expected output:
```
Creating cluster "istio-ecommerce" ...
 ✓ Ensuring node image (kindest/node:v1.36.1)
 ✓ Preparing nodes
 ✓ Writing configuration
 ✓ Starting control-plane
 ✓ Installing CNI
 ✓ Installing StorageClass
 ✓ Joining worker nodes
Set kubectl context to "kind-istio-ecommerce"
```

#### Set Context

```bash
kubectl config use-context kind-istio-ecommerce
kubectl cluster-info
```

### 4.4 Setup Cloud Provider KIND for LoadBalancer

Istio Ingress Gateway creates a Service of type `LoadBalancer`. In production Kubernetes (EKS, GKE), the cloud provider assigns an external IP. In kind, we need Cloud Provider KIND to handle this.

Reference: https://kind.sigs.k8s.io/docs/user/loadbalancer/

**Prerequisite:** Go must be installed (see [Part 3.5 - Install Go](#35-install-go)).

As per the official kind LoadBalancer documentation, Cloud Provider KIND is installed using:

```bash
# Install cloud-provider-kind (per official docs)
go install sigs.k8s.io/cloud-provider-kind@latest
```

This downloads and compiles the binary into `~/go/bin/`. The installation may take 1-2 minutes
as it downloads dependencies. It will automatically fetch the required Go toolchain version.

After installation, copy the binary to a system-wide location:

```bash
# Make it available system-wide
sudo cp ~/go/bin/cloud-provider-kind /usr/local/bin/cloud-provider-kind

# Verify installation
cloud-provider-kind --help
```

**Important:** If you previously attempted a failed binary download, remove the broken file first:
```bash
sudo rm -f /usr/local/bin/cloud-provider-kind
```

#### Run Cloud Provider KIND

Cloud Provider KIND runs as a standalone process on the host machine. It monitors all kind
clusters and creates Docker containers that act as load balancers for Services of type
LoadBalancer. It requires sudo because it needs privileges to open ports and connect to
the container runtime.

```bash
# Run in background with sudo
sudo cloud-provider-kind &
```

For persistent operation (survives terminal disconnects), use tmux or screen:

```bash
# Using tmux (recommended for lab environments)
tmux new-session -d -s cpkind 'sudo cloud-provider-kind'

# To view logs later
tmux attach -t cpkind
```

### 4.5 Remove Control Plane Exclusion Label

By default, Kubernetes labels control-plane nodes with `node.kubernetes.io/exclude-from-external-load-balancers`
which prevents LoadBalancer services from routing traffic to them. Since kind runs workloads on all
nodes (including control-plane), remove this label:

```bash
kubectl label node istio-ecommerce-control-plane node.kubernetes.io/exclude-from-external-load-balancers-
```

### 4.6 Verify LoadBalancer Support

Deploy the test service from the official kind documentation:

```bash
# Deploy test pods and LoadBalancer service
kubectl apply -f https://kind.sigs.k8s.io/examples/loadbalancer/usage.yaml

# Wait for external IP assignment (should take ~10 seconds)
kubectl get svc foo-service --watch
```

Expected: The `EXTERNAL-IP` column shows an IP address (not `<pending>`).

```bash
# Verify traffic reaches the pods
LB_IP=$(kubectl get svc/foo-service -o=jsonpath='{.status.loadBalancer.ingress[0].ip}')
for _ in {1..10}; do
  curl ${LB_IP}:5678
done
```

Expected: Output shows hostnames of foo-app and bar-app alternating (round-robin).

Cleanup test resources:
```bash
kubectl delete -f https://kind.sigs.k8s.io/examples/loadbalancer/usage.yaml
```

### 4.7 Troubleshooting Cloud Provider KIND

| Issue | Cause | Fix |
|-------|-------|-----|
| `/usr/local/bin/cloud-provider-kind: line 1: Not: command not found` | Broken binary from failed download | `sudo rm -f /usr/local/bin/cloud-provider-kind` then reinstall via `go install` |
| `go install` fails with "go: command not found" | Go not installed | Follow [Part 3.5](#35-install-go) to install Go |
| EXTERNAL-IP stays `<pending>` | cloud-provider-kind not running | Run `sudo cloud-provider-kind &` |
| EXTERNAL-IP shows IP but curl times out | Exclusion label on control-plane node | Remove label per Step 4.5 |
| cloud-provider-kind exits immediately | Port conflict or Docker socket permission | Run with `sudo`; check `docker ps` |


---


## Part 5 - Verify Cluster Topology

### 5.1 Check Nodes and Labels

```bash
kubectl get nodes -o wide
```

Expected output:
```
NAME                            STATUS   ROLES           AGE   VERSION    INTERNAL-IP   ...
istio-ecommerce-control-plane   Ready    control-plane   2m    v1.36.1    172.18.0.x    ...
istio-ecommerce-worker          Ready    <none>          2m    v1.36.1    172.18.0.x    ...
istio-ecommerce-worker2         Ready    <none>          2m    v1.36.1    172.18.0.x    ...
```

### 5.2 Verify Node Labels

```bash
# Show all labels
kubectl get nodes --show-labels

# Check specific labels
kubectl get nodes -l tier=frontend
kubectl get nodes -l tier=backend
kubectl get nodes -l ingress-ready=true
```

### 5.3 Check System Pods Distribution

```bash
kubectl get pods -n kube-system -o wide
```

### 5.4 Verify Port Mappings

```bash
# Check Docker port mappings on the control-plane container
docker port istio-ecommerce-control-plane
```

Expected:
```
80/tcp -> 0.0.0.0:80
443/tcp -> 0.0.0.0:443
30080/tcp -> 0.0.0.0:30080
30443/tcp -> 0.0.0.0:30443
```

### 5.5 Verify External Access (from EC2 host)

```bash
# This should return "connection refused" (nothing listening yet) — not "timeout"
curl -v http://localhost:80 2>&1 | head -5
```

If you get `Connection refused`, the port mapping works. Traffic reaches the container but no service is listening yet (Istio Ingress Gateway will handle this later).

---

## Part 6 - Understanding the Configuration

### 6.1 extraPortMappings

```yaml
extraPortMappings:
  - containerPort: 80
    hostPort: 80
    listenAddress: "0.0.0.0"
    protocol: TCP
```

| Field | Purpose |
|-------|---------|
| containerPort | Port inside the kind node container |
| hostPort | Port on the EC2 host machine |
| listenAddress | `127.0.0.1` = localhost only; `0.0.0.0` = accessible from any network interface (required for EC2 remote access) |
| protocol | TCP, UDP, or SCTP |

Without `listenAddress: "0.0.0.0"`, you cannot access the cluster from your local machine via the EC2 Elastic IP. This is critical for remote lab setups.

### 6.2 Node Labels

Labels applied via `kubeadmConfigPatches` are set during node registration. This means:
- Pods with `nodeSelector` can be scheduled immediately.
- No manual `kubectl label` step is needed after cluster creation.
- Labels persist across node restarts.

Usage in pod/deployment spec:
```yaml
spec:
  nodeSelector:
    tier: frontend
```

### 6.3 listenAddress: "0.0.0.0" Security Consideration

Setting `listenAddress: "0.0.0.0"` exposes the port to all interfaces on the EC2 host. This is necessary for remote access but means:
- The EC2 Security Group is the only firewall.
- Ensure only required ports are open and restricted to your IP.
- Do NOT use this in environments where the host is on an untrusted network.

### 6.4 Topology Labels

```yaml
labels:
  topology.kubernetes.io/zone: "zone-a"
```

These simulate availability zones. Istio uses topology labels for locality-aware load balancing. When Istio sees services in different zones, it can prefer routing to the closest zone -- a pattern used heavily in production e-commerce for latency reduction.


---


## Part 7 - Install Istio CLI (istioctl)

Reference: https://istio.io/latest/docs/setup/additional-setup/download-istio-release/

### Download and Install

```bash
# Download the latest Istio release
curl -L https://istio.io/downloadIstio | sh -
```

To download a specific version:
```bash
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.30.3 TARGET_ARCH=x86_64 sh -
```

### Configure PATH

```bash
cd istio-1.30.3
export PATH=$PWD/bin:$PATH
```

To make this permanent:
```bash
echo 'export PATH=$HOME/istio-1.30.3/bin:$PATH' >> ~/.bashrc
source ~/.bashrc
```

### Verify Installation

```bash
istioctl version
```

### Pre-flight Check

Run the Istio pre-check to validate that the cluster is ready for installation:

```bash
istioctl x precheck
```

Expected output:
```
No issues found when checking the cluster. Istio is safe to install or upgrade!
  To get started, check out https://istio.io/latest/docs/setup/getting-started/
```

If issues are reported, resolve them before proceeding with Istio installation.

---

## Part 8 - Kind Command Reference

### 8.1 Cluster Information Commands

```bash
# List all kind clusters on this host
kind get clusters

# Get cluster kubeconfig
kind get kubeconfig --name istio-ecommerce

# Export kubeconfig to a specific file
kind get kubeconfig --name istio-ecommerce > ~/.kube/istio-ecommerce.yaml

# Get list of nodes (as Docker containers)
kind get nodes --name istio-ecommerce

# Check current kubectl context (should show kind-istio-ecommerce)
kubectl config current-context

# View all available contexts
kubectl config get-contexts

# Switch to kind cluster context
kubectl config use-context kind-istio-ecommerce
```

### 8.2 Inspect Current Cluster Configuration

```bash
# View the kind config that was used to create the cluster
# (kind does not store the original config, so keep your YAML file)
cat ~/istio-lab/cluster/kind-istio-cluster.yaml

# Inspect node details and labels
kubectl get nodes --show-labels

# Describe a specific node (full details including conditions, capacity, allocatable)
kubectl describe node istio-ecommerce-control-plane
kubectl describe node istio-ecommerce-worker
kubectl describe node istio-ecommerce-worker2

# Check node resource allocation
kubectl top nodes

# Check Docker-level port mappings
docker port istio-ecommerce-control-plane

# Inspect kind container network
docker inspect istio-ecommerce-control-plane --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'

# View all kind containers and their status
docker ps --filter "label=io.x-k8s.kind.cluster=istio-ecommerce" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Check Docker network used by kind
docker network ls | grep kind
docker network inspect kind
```

### 8.3 Node Label Management

```bash
# View labels on all nodes
kubectl get nodes --show-labels

# View labels on a specific node
kubectl get node istio-ecommerce-worker --show-labels

# Add a new label to a node (runtime, does not persist on cluster recreate)
kubectl label node istio-ecommerce-worker environment=staging

# Update an existing label
kubectl label node istio-ecommerce-worker tier=frontend --overwrite

# Remove a label from a node
kubectl label node istio-ecommerce-worker environment-

# Select nodes by label
kubectl get nodes -l tier=frontend
kubectl get nodes -l tier=backend
kubectl get nodes -l ingress-ready=true
```

### 8.4 Create a New Cluster from Config

```bash
# Create cluster from config file
kind create cluster --config ~/istio-lab/cluster/kind-istio-cluster.yaml

# Create cluster with a specific name (overrides name in config)
kind create cluster --config ~/istio-lab/cluster/kind-istio-cluster.yaml --name my-test-cluster

# Create cluster with a specific Kubernetes version
kind create cluster --image kindest/node:v1.36.1@sha256:3489c7674813ba5d8b1a9977baea8a6e553784dab7b84759d1014dbd78f7ebd5

# Create cluster and wait for control plane to be ready (with timeout)
kind create cluster --config ~/istio-lab/cluster/kind-istio-cluster.yaml --wait 5m

# Create a quick single-node cluster for testing (no config file needed)
kind create cluster --name quick-test
```

### 8.5 Load Docker Images into Kind

kind uses its own container image store. If you build local images or want to avoid pulling from registry, load them directly:

```bash
# Load a single image into the cluster
kind load docker-image my-app:v1.0 --name istio-ecommerce

# Load multiple images
kind load docker-image product-service:v1 cart-service:v1 order-service:v1 --name istio-ecommerce

# Load from a tar archive
kind load image-archive my-images.tar --name istio-ecommerce

# Verify the image exists on a node
docker exec istio-ecommerce-worker crictl images | grep my-app
```

**Note:** This uses `kind load` to push images directly into kind nodes. For a persistent registry-based workflow, see [Part 9.1 - Local Container Registry](#91-local-container-registry).


### 8.6 Cluster Lifecycle Management

```bash
# --- Stop Cluster (preserve state, save resources) ---
docker stop istio-ecommerce-control-plane istio-ecommerce-worker istio-ecommerce-worker2

# --- Start Cluster Again ---
docker start istio-ecommerce-control-plane istio-ecommerce-worker istio-ecommerce-worker2

# Wait for nodes to become Ready after restart
kubectl wait --for=condition=Ready nodes --all --timeout=120s

# --- Recreate Cluster (reset to clean state) ---
kind delete cluster --name istio-ecommerce
kind create cluster --config ~/istio-lab/cluster/kind-istio-cluster.yaml

# --- Delete Cluster ---
kind delete cluster --name istio-ecommerce

# --- Delete ALL kind clusters on this host ---
kind delete clusters --all
```

### 8.7 Debugging Commands

Quick-reference commands for debugging kind cluster issues. For specific issue+fix pairs, see [Part 9.7 - Known Issues and Fixes](#97-known-issues-and-fixes).

```bash
# Export cluster logs to a directory (useful for debugging failures)
kind export logs ./kind-logs --name istio-ecommerce

# View kubelet logs on a specific node
docker exec istio-ecommerce-worker journalctl -u kubelet --no-pager -n 50

# Get a shell inside a kind node container
docker exec -it istio-ecommerce-control-plane bash
docker exec -it istio-ecommerce-worker bash

# Check containerd status inside a node
docker exec istio-ecommerce-worker systemctl status containerd

# List containers running inside a kind node
docker exec istio-ecommerce-worker crictl ps

# Check pod resource consumption
kubectl top pods --all-namespaces

# Check events for scheduling/startup issues
kubectl get events --all-namespaces --sort-by='.lastTimestamp' | tail -20

# Verify cluster DNS is working
kubectl run dns-test --image=busybox:1.36 --restart=Never --rm -it -- nslookup kubernetes.default

# Check cluster component health
kubectl get componentstatuses 2>/dev/null || kubectl get --raw='/readyz?verbose'
```

### 8.8 Multiple Clusters on Same Host

```bash
# Create multiple clusters for different purposes
kind create cluster --config ~/istio-lab/cluster/kind-istio-cluster.yaml
kind create cluster --name quick-test

# List all clusters
kind get clusters

# Switch between clusters
kubectl config use-context kind-istio-ecommerce
kubectl config use-context kind-quick-test

# Delete only one
kind delete cluster --name quick-test
```

### 8.9 Backup and Restore Cluster Config

```bash
# The cluster config YAML is the only thing you need to backup.
# kind does not persist cluster state between delete/create cycles.

# Backup config
cp ~/istio-lab/cluster/kind-istio-cluster.yaml ~/istio-lab/cluster/kind-istio-cluster.yaml.bak

# Version control it (recommended)
cd ~/istio-lab && git init && git add . && git commit -m "Initial cluster config"
```

### 8.10 Quick Reference Table

| Task | Command |
|------|---------|
| List clusters | `kind get clusters` |
| Create cluster | `kind create cluster --config <file>` |
| Delete cluster | `kind delete cluster --name <name>` |
| Delete all clusters | `kind delete clusters --all` |
| Get nodes | `kind get nodes --name <name>` |
| Get kubeconfig | `kind get kubeconfig --name <name>` |
| Load image | `kind load docker-image <image> --name <name>` |
| Export logs | `kind export logs <dir> --name <name>` |
| Check version | `kind version` |
| Stop cluster | `docker stop <node-containers>` |
| Start cluster | `docker start <node-containers>` |
| Shell into node | `docker exec -it <node-container> bash` |
| View port maps | `docker port <control-plane-container>` |
| Node labels | `kubectl get nodes --show-labels` |
| Add label | `kubectl label node <node> key=value` |
| Remove label | `kubectl label node <node> key-` |


---

## Part 9 - Kind Administration Guide

This section covers advanced administrative tasks for kind clusters based on official documentation at https://kind.sigs.k8s.io/docs/

### 9.1 Local Container Registry

A local registry allows you to push images locally and use them in your kind cluster without pulling from Docker Hub or other remote registries. This is essential for development workflows.

Reference: https://kind.sigs.k8s.io/docs/user/local-registry/

**Create a Local Registry and Connect to Kind:**

```bash
#!/bin/bash
# Create a local Docker registry
reg_name='kind-registry'
reg_port='5001'

# Start registry container if not running
if [ "$(docker inspect -f '{{.State.Running}}' "${reg_name}" 2>/dev/null || true)" != 'true' ]; then
  docker run -d --restart=always -p "127.0.0.1:${reg_port}:5000" --network bridge --name "${reg_name}" registry:3
fi

# Connect registry to the kind network
if [ "$(docker inspect -f='{{json .NetworkSettings.Networks.kind}}' "${reg_name}")" = 'null' ]; then
  docker network connect "kind" "${reg_name}"
fi

# Document the registry in the cluster
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${reg_port}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF
```

**Using the Local Registry:**

```bash
# Pull an image
docker pull gcr.io/google-samples/hello-app:1.0

# Tag it for local registry
docker tag gcr.io/google-samples/hello-app:1.0 localhost:5001/hello-app:1.0

# Push to local registry
docker push localhost:5001/hello-app:1.0

# Use in Kubernetes (pods will pull from local registry)
kubectl create deployment hello-server --image=localhost:5001/hello-app:1.0
```

**Verify Registry:**

```bash
# Check registry is running
docker ps | grep kind-registry

# List images in registry
curl -s http://localhost:5001/v2/_catalog

# Check registry connectivity from kind node
docker exec istio-ecommerce-control-plane curl -s http://kind-registry:5000/v2/_catalog
```

---

### 9.2 Ingress Setup

Reference: https://kind.sigs.k8s.io/docs/user/ingress/

Since cloud-provider-kind v0.9.0+, Ingress is natively supported. No third-party ingress controllers are required by default.

**Deploy Ingress Example:**

```bash
# Apply ingress example from official docs
kubectl apply -f https://kind.sigs.k8s.io/examples/ingress/usage.yaml

# Check the External IP assigned to the Ingress
kubectl get ingress

# Get Ingress IP
INGRESS_IP=$(kubectl get ingress example-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Test routing
curl ${INGRESS_IP}/foo    # should output "foo-app"
curl ${INGRESS_IP}/bar    # should output "bar-app"

# Cleanup
kubectl delete -f https://kind.sigs.k8s.io/examples/ingress/usage.yaml
```

**Note:** Gateway API is also natively supported alongside Ingress.

---

### 9.3 Resource Management

**Monitor Docker Resources Used by Kind:**

```bash
# Check disk usage by kind containers
docker system df

# Check resource usage per container
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}" | grep istio-ecommerce

# Check overall Docker disk usage
docker system df -v | head -30

# Free up unused Docker resources
docker system prune -f              # Remove stopped containers, unused networks, dangling images
docker image prune -f               # Remove dangling images only
docker volume prune -f              # Remove unused volumes
```

**Check Kubernetes Resource Allocation:**

```bash
# Node resource capacity and allocation
kubectl describe nodes | grep -A 5 "Allocated resources"

# Per-node resource usage (requires metrics-server)
kubectl top nodes

# Per-pod resource usage
kubectl top pods --all-namespaces --sort-by=memory

# Check resource requests vs limits for all pods
kubectl get pods --all-namespaces -o custom-columns=\
"NAMESPACE:.metadata.namespace,NAME:.metadata.name,CPU_REQ:.spec.containers[*].resources.requests.cpu,MEM_REQ:.spec.containers[*].resources.requests.memory"
```

**Install Metrics Server (required for `kubectl top`):**

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Patch for kind (disable TLS verification since kind uses self-signed certs)
kubectl patch deployment metrics-server -n kube-system --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

# Wait for metrics-server to be ready
kubectl wait --for=condition=Available deployment/metrics-server -n kube-system --timeout=120s

# Verify
kubectl top nodes
```

---

### 9.4 Networking Administration

**Inspect Kind Docker Network:**

```bash
# View kind network details
docker network inspect kind

# List all containers on kind network
docker network inspect kind -f '{{range .Containers}}{{.Name}}: {{.IPv4Address}}{{"\n"}}{{end}}'

# Check inter-node connectivity
docker exec istio-ecommerce-control-plane ping -c 2 istio-ecommerce-worker
docker exec istio-ecommerce-worker ping -c 2 istio-ecommerce-worker2
```

**DNS Administration:**

```bash
# Check CoreDNS pods
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Test DNS resolution inside the cluster
kubectl run dns-test --image=busybox:1.36 --restart=Never --rm -it -- nslookup kubernetes.default.svc.cluster.local

# Check CoreDNS configmap
kubectl get configmap coredns -n kube-system -o yaml

# Restart CoreDNS (if DNS issues)
kubectl rollout restart deployment coredns -n kube-system
```

**Service and Endpoint Debugging:**

```bash
# List all services across namespaces
kubectl get svc --all-namespaces

# Check endpoints for a service
kubectl get endpoints <service-name> -n <namespace>

# Test service connectivity from within cluster
kubectl run curl-test --image=curlimages/curl --restart=Never --rm -it -- curl -s http://<service-name>.<namespace>.svc.cluster.local:<port>
```

---

### 9.5 Storage Administration

**StorageClass Management:**

```bash
# List StorageClasses
kubectl get storageclass

# Describe default StorageClass (kind provides 'standard' by default)
kubectl describe storageclass standard

# List PersistentVolumes
kubectl get pv

# List PersistentVolumeClaims
kubectl get pvc --all-namespaces
```

**Using Host Path Storage (for persistent data across pod restarts):**

```bash
# Create a PVC using the default StorageClass
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF

# Verify PVC is bound
kubectl get pvc test-pvc
```

---

### 9.6 Node Administration

**Node Cordon/Drain (simulate maintenance):**

```bash
# Mark node as unschedulable (cordon)
kubectl cordon istio-ecommerce-worker

# Drain pods from node (evicts pods gracefully)
kubectl drain istio-ecommerce-worker --ignore-daemonsets --delete-emptydir-data

# Uncordon node (mark schedulable again)
kubectl uncordon istio-ecommerce-worker
```

**Node Taints and Tolerations:**

```bash
# Add a taint to a node
kubectl taint nodes istio-ecommerce-worker2 dedicated=backend:NoSchedule

# View taints on a node
kubectl describe node istio-ecommerce-worker2 | grep -A 3 Taints

# Remove a taint
kubectl taint nodes istio-ecommerce-worker2 dedicated=backend:NoSchedule-
```

**Restart a Kind Node:**

```bash
# Restart a specific node
docker restart istio-ecommerce-worker

# Wait for it to rejoin
kubectl wait --for=condition=Ready node/istio-ecommerce-worker --timeout=120s
```

---

### 9.7 Known Issues and Fixes

Reference: https://kind.sigs.k8s.io/docs/user/known-issues/

For general debugging commands, see [Part 8.7 - Debugging Commands](#87-debugging-commands). This section covers specific known issues with their resolutions.

**Pod Errors Due to "too many open files":**

Caused by running out of inotify resources. Fix:

```bash
# Temporary fix
sudo sysctl fs.inotify.max_user_watches=524288
sudo sysctl fs.inotify.max_user_instances=512

# Permanent fix (add to /etc/sysctl.conf)
echo "fs.inotify.max_user_watches = 524288" | sudo tee -a /etc/sysctl.conf
echo "fs.inotify.max_user_instances = 512" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

**Cluster Fails to Start Properly (resource starvation):**

```bash
# Free up Docker resources
docker system prune -af
docker volume prune -f

# Check available disk space
df -h /

# Check available memory
free -h
```

**Docker Permission Denied:**

```bash
# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Or fix permissions on docker socket
sudo chmod 666 /var/run/docker.sock
```

**Unable to Pull Images (for named clusters):**

```bash
# Must specify cluster name when loading images
kind load docker-image my-app:v1 --name istio-ecommerce
```

**Local Subnet Clashes (VPN conflicts):**

If kind network (172.17.x.x) conflicts with VPN or other networks, add to `/etc/docker/daemon.json`:

```json
{
  "default-address-pools": [
    {
      "base": "10.253.0.0/16",
      "size": 24
    }
  ]
}
```

Then restart Docker:
```bash
sudo systemctl restart docker
```

**Export Cluster Logs for Debugging:**

```bash
# Export all logs to a directory
kind export logs ./kind-debug-logs --name istio-ecommerce

# View key log files
ls ./kind-debug-logs/
cat ./kind-debug-logs/istio-ecommerce-control-plane/kubelet.log | tail -50
cat ./kind-debug-logs/istio-ecommerce-control-plane/containerd.log | tail -50
```


---


## Part 10 - Cleanup

### Delete kind Cluster

```bash
kind delete cluster --name istio-ecommerce
```

### Terminate EC2 Instance (if applicable)

1. Release Elastic IP to avoid charges.
2. Terminate the instance from EC2 Console.

### Delete EKS Cluster (if applicable)

```bash
eksctl delete cluster --name istio-lab-eks --region ap-south-1
```

### Delete GKE Cluster (if applicable)

```bash
gcloud container clusters delete $CLUSTER_NAME --zone $ZONE --project $PROJECT_ID
```

---

## Appendix A - Minimal kind Configuration (Single Node)

For quick testing when resources are limited. Not recommended for Istio production practice but works for basic exploration:

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: istio-minimal
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 80
        hostPort: 80
        listenAddress: "0.0.0.0"
        protocol: TCP
      - containerPort: 443
        hostPort: 443
        listenAddress: "0.0.0.0"
        protocol: TCP
```

---

## Appendix B - High Availability kind Configuration

For testing Istio in an HA cluster (multi-control-plane). Requires more resources (minimum 16 GB RAM on host):

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: istio-ha
networking:
  podSubnet: "10.244.0.0/16"
  serviceSubnet: "10.96.0.0/16"
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 80
        hostPort: 80
        listenAddress: "0.0.0.0"
        protocol: TCP
      - containerPort: 443
        hostPort: 443
        listenAddress: "0.0.0.0"
        protocol: TCP
  - role: control-plane
  - role: control-plane
  - role: worker
    labels:
      tier: frontend
    kubeadmConfigPatches:
      - |
        kind: JoinConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "tier=frontend"
  - role: worker
    labels:
      tier: backend
    kubeadmConfigPatches:
      - |
        kind: JoinConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "tier=backend"
  - role: worker
    labels:
      tier: backend
    kubeadmConfigPatches:
      - |
        kind: JoinConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "tier=backend"
```

Note: kind v0.32.0 uses Envoy as the load balancer for multi-control-plane clusters (replaced HAProxy).

---


## Appendix C - Alternative Kubernetes Platforms

### Minikube

**Official Istio Docs:** https://istio.io/latest/docs/setup/platform-setup/minikube/

#### Install Minikube

```bash
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
rm minikube-linux-amd64
```

#### Start Minikube (per Istio official docs)

The Istio documentation recommends 16384 MB of memory and 4 CPUs:

```bash
minikube start --memory=16384 --cpus=4 --driver=docker
```

If insufficient RAM is allocated, common failures include image pull errors, healthcheck timeouts, general network instability, and VM lockups.

#### LoadBalancer Support

To expose LoadBalancer services (such as Istio Ingress Gateway), run `minikube tunnel` in a separate terminal:

```bash
minikube tunnel
```

To clean up tunnel networking:
```bash
minikube tunnel --cleanup
```

---

### Amazon EKS

**Official Istio Docs:** https://istio.io/latest/docs/setup/platform-setup/amazon-eks/

The Istio documentation directs users to the AWS-maintained repository:

https://github.com/aws-samples/istio-on-eks

#### Quick Setup with eksctl

```bash
# Install eksctl
curl --silent --location "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

# Create EKS cluster
eksctl create cluster \
  --name istio-lab-eks \
  --region ap-south-1 \
  --nodegroup-name workers \
  --node-type t3.medium \
  --nodes 3 \
  --managed

# Verify
kubectl get nodes
```

**Note:** EKS incurs ongoing costs (control plane + worker nodes). Destroy the cluster when not in use.

---

### Docker Desktop

**Official Istio Docs:** https://istio.io/latest/docs/setup/platform-setup/docker/

#### Setup Steps

1. Install Docker Desktop (Windows or macOS).
2. Open Settings, then Kubernetes, then check "Enable Kubernetes".
3. Under Resources, allocate minimum 8 GB RAM and 4 CPUs.
4. Apply changes and wait for Kubernetes to start.

#### Key Considerations

- Single-node cluster only.
- Suitable for quick experimentation on a local workstation.
- Ensure Docker memory limit is increased sufficiently for Istio workloads.

---

### Google Kubernetes Engine (GKE)

**Official Istio Docs:** https://istio.io/latest/docs/setup/platform-setup/gke/

#### Create GKE Cluster (per Istio official docs)

```bash
export PROJECT_ID=$(gcloud config get-value project)
export M_TYPE=n1-standard-2
export ZONE=us-west2-a
export CLUSTER_NAME=${PROJECT_ID}-istio-lab

gcloud services enable container.googleapis.com

gcloud container clusters create $CLUSTER_NAME \
  --cluster-version latest \
  --machine-type=$M_TYPE \
  --num-nodes 4 \
  --zone $ZONE \
  --project $PROJECT_ID
```

The default Istio installation requires nodes with more than 1 vCPU. The `n1-standard-2` machine type satisfies this requirement.

#### Retrieve Credentials

```bash
gcloud container clusters get-credentials $CLUSTER_NAME \
    --zone $ZONE \
    --project $PROJECT_ID
```

#### Grant Cluster Admin Permissions

```bash
kubectl create clusterrolebinding cluster-admin-binding \
    --clusterrole=cluster-admin \
    --user=$(gcloud config get-value core/account)
```

#### Private GKE Clusters (Additional Step)

For private GKE clusters, the automatically created firewall rule does not open port 15017. This port is required by the Istio webhook for sidecar injection.

```bash
# List firewall rules for the cluster
gcloud compute firewall-rules list --filter="name~gke-${CLUSTER_NAME}-[0-9a-z]*-master"

# Update the rule to allow port 15017
gcloud compute firewall-rules update <firewall-rule-name> --allow tcp:10250,tcp:443,tcp:15017
```

---


## Troubleshooting

| Issue | Cause | Resolution |
|-------|-------|------------|
| kind cluster fails to start | Docker not running | Start Docker: `sudo systemctl start docker` |
| Pods stuck in Pending | Insufficient node resources | Increase instance type or add worker nodes |
| istioctl precheck fails | RBAC not configured | Run `kubectl create clusterrolebinding` with cluster-admin |
| LoadBalancer stuck in Pending (kind) | No LB controller installed | Install Cloud Provider KIND or use NodePort |
| Image pull errors (minikube) | Insufficient memory | Restart with `--memory=16384` |
| Connection refused on port 15017 (GKE) | Firewall rule missing | Update GKE firewall rule to allow tcp:15017 |
| `/usr/local/bin/cloud-provider-kind: line 1: Not: command not found` | Broken binary from failed download | `sudo rm -f /usr/local/bin/cloud-provider-kind` then reinstall via `go install` |
| `go install` fails with "go: command not found" | Go not installed | Follow [Part 3.5](#35-install-go) to install Go |
| EXTERNAL-IP stays `<pending>` | cloud-provider-kind not running | Run `sudo cloud-provider-kind &` |
| EXTERNAL-IP shows IP but curl times out | Exclusion label on control-plane node | Remove label per Part 4.5 |
| cloud-provider-kind exits immediately | Port conflict or Docker socket permission | Run with `sudo`; check `docker ps` |

---

## References

| Resource | URL |
|----------|-----|
| Istio Platform Setup Overview | https://istio.io/latest/docs/setup/platform-setup/ |
| Istio - kind Setup | https://istio.io/latest/docs/setup/platform-setup/kind/ |
| Istio - Minikube Setup | https://istio.io/latest/docs/setup/platform-setup/minikube/ |
| Istio - Amazon EKS Setup | https://istio.io/latest/docs/setup/platform-setup/amazon-eks/ |
| Istio - Docker Desktop Setup | https://istio.io/latest/docs/setup/platform-setup/docker/ |
| Istio - GKE Setup | https://istio.io/latest/docs/setup/platform-setup/gke/ |
| Istio Download Page | https://istio.io/latest/docs/setup/additional-setup/download-istio-release/ |
| Istio Locality Load Balancing | https://istio.io/latest/docs/tasks/traffic-management/locality-load-balancing/ |
| kind Quick Start | https://kind.sigs.k8s.io/docs/user/quick-start/ |
| kind Configuration Reference | https://kind.sigs.k8s.io/docs/user/configuration/ |
| kind LoadBalancer Guide | https://kind.sigs.k8s.io/docs/user/loadbalancer/ |
| kind Ingress Guide | https://kind.sigs.k8s.io/docs/user/ingress/ |
| kind Releases | https://github.com/kubernetes-sigs/kind/releases |
| Cloud Provider KIND | https://github.com/kubernetes-sigs/cloud-provider-kind |
| Docker Installation (Ubuntu) | https://docs.docker.com/engine/install/ubuntu/ |
| kubectl Installation | https://kubernetes.io/docs/tasks/tools/ |
| Kubernetes Node Affinity | https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/ |
| AWS Istio on EKS | https://github.com/aws-samples/istio-on-eks |

---

## What Comes Next

In the next lab module (`002-Istio-Installation`), the following topics are covered:

- Installing Istio on the cluster using different configuration profiles
- Understanding Istio architecture (istiod, Ingress Gateway, Egress Gateway)
- Enabling automatic sidecar injection
- Deploying the Bookinfo sample application for validation

---

**Tip:** If using EC2, create an AMI snapshot after completing this setup. This provides a clean baseline to restore from if subsequent labs require a fresh environment.

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
> **Next:** Move to `002-Istio-Installation` to install Istio on the cluster, understand its architecture, and deploy your first service mesh application.
