#!/bin/bash
#=============================================================================
# Istio Lab - Platform Setup Script
# Run this on the EC2 instance after SSH login
# 
# Usage: chmod +x setup-istio-lab.sh && ./setup-istio-lab.sh
#=============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log_step() { echo -e "\n${GREEN}[STEP]${NC} $1"; }
log_info() { echo -e "${YELLOW}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "============================================="
echo " Istio Lab - Platform Setup"
echo " Ubuntu 24.04 | kind | Istio 1.30.3"
echo "============================================="
echo ""

#---------------------------------------------
# Part 2.1: System Update
#---------------------------------------------
log_step "Part 2.1 - System Update"
sudo apt update && sudo apt upgrade -y
echo ""

#---------------------------------------------
# Part 2.2: Install Docker
#---------------------------------------------
log_step "Part 2.2 - Installing Docker"

# Remove conflicting packages
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
  sudo apt-get remove -y $pkg 2>/dev/null || true
done

# Add Docker official GPG key and repository
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Allow current user to run Docker without sudo
sudo usermod -aG docker $USER

log_info "Docker installed: $(docker --version)"
echo ""

#---------------------------------------------
# Part 2.3: Install kubectl
#---------------------------------------------
log_step "Part 2.3 - Installing kubectl"

curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm -f kubectl

log_info "kubectl installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
echo ""

#---------------------------------------------
# Part 2.4: Install Helm
#---------------------------------------------
log_step "Part 2.4 - Installing Helm"

curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

log_info "Helm installed: $(helm version --short)"
echo ""

#---------------------------------------------
# Part 3.1: Install kind
#---------------------------------------------
log_step "Part 3.1 - Installing kind v0.32.0"

[ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.32.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

log_info "kind installed: $(kind version)"
echo ""

#---------------------------------------------
# Part 3.1b: Install Go (required for cloud-provider-kind)
#---------------------------------------------
log_step "Part 3.1b - Installing Go 1.23.0"

curl -LO https://go.dev/dl/go1.23.0.linux-amd64.tar.gz
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf go1.23.0.linux-amd64.tar.gz
rm go1.23.0.linux-amd64.tar.gz

export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin
if ! grep -q "/usr/local/go/bin" ~/.bashrc; then
  echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> ~/.bashrc
fi

log_info "Go installed: $(go version)"
echo ""

#---------------------------------------------
# Part 3.1c: Install Cloud Provider KIND
#---------------------------------------------
log_step "Part 3.1c - Installing Cloud Provider KIND (for LoadBalancer support)"

go install sigs.k8s.io/cloud-provider-kind@latest
sudo cp ~/go/bin/cloud-provider-kind /usr/local/bin/cloud-provider-kind

log_info "cloud-provider-kind installed: $(cloud-provider-kind --help 2>&1 | head -1)"
echo ""

#---------------------------------------------
# Part 3.2: Create kind Cluster
#---------------------------------------------
log_step "Part 3.2 - Creating kind cluster 'istio-testing'"

# Need docker group to take effect
if ! docker info > /dev/null 2>&1; then
  log_info "Activating docker group (newgrp). Re-run this script if cluster creation fails."
  sg docker -c "kind create cluster --name istio-testing"
else
  kind create cluster --name istio-testing
fi

log_info "kind cluster created successfully"
echo ""

#---------------------------------------------
# Part 3.3: Start Cloud Provider KIND
#---------------------------------------------
log_step "Part 3.3 - Starting Cloud Provider KIND"

sudo cloud-provider-kind &
sleep 3

# Remove control-plane exclusion label for LoadBalancer access
kubectl label node istio-ecommerce-control-plane node.kubernetes.io/exclude-from-external-load-balancers- 2>/dev/null || true

log_info "Cloud Provider KIND is running (LoadBalancer support enabled)"
echo ""

#---------------------------------------------
# Part 4: Verify Cluster Readiness
#---------------------------------------------
log_step "Part 4 - Verifying Cluster Readiness"

echo "Cluster Info:"
kubectl cluster-info --context kind-istio-testing

echo ""
echo "Nodes:"
kubectl get nodes -o wide

echo ""
echo "System Pods:"
kubectl get pods -n kube-system

echo ""

#---------------------------------------------
# Part 5: Install Istio CLI (istioctl)
#---------------------------------------------
log_step "Part 5 - Installing Istio 1.30.3"

cd $HOME
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.30.3 TARGET_ARCH=x86_64 sh -

# Add to PATH permanently
if ! grep -q "istio-1.30.3/bin" ~/.bashrc; then
  echo 'export PATH=$HOME/istio-1.30.3/bin:$PATH' >> ~/.bashrc
fi
export PATH=$HOME/istio-1.30.3/bin:$PATH

log_info "istioctl installed: $(istioctl version --remote=false)"
echo ""

#---------------------------------------------
# Part 5.1: Istio Pre-check
#---------------------------------------------
log_step "Part 5.1 - Running Istio Pre-flight Check"

istioctl x precheck

echo ""
echo "============================================="
echo " Setup Complete"
echo "============================================="
echo ""
echo " Docker:    $(docker --version)"
echo " kubectl:   $(kubectl version --client --short 2>/dev/null || echo 'installed')"
echo " Helm:      $(helm version --short)"
echo " kind:      $(kind version)"
echo " istioctl:  $(istioctl version --remote=false)"
echo " Cluster:   kind-istio-testing"
echo ""
echo " Next: Run 'source ~/.bashrc' or open a new terminal"
echo "       Then proceed to 002-Istio-Installation"
echo "============================================="
