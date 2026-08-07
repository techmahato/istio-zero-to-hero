#!/bin/bash
###############################################################################
# Script Name  : 02-setup-kind-cluster.sh
# Description  : Creates a Kind (Kubernetes in Docker) cluster named
#                'istio-ecommerce' with 1 control-plane and 2 worker nodes.
#                Configures port mappings for Istio ingress gateway and
#                applies node labels for workload scheduling.
# Usage        : chmod +x 02-setup-kind-cluster.sh && ./02-setup-kind-cluster.sh
# Prerequisites: Docker running, kind installed (via 'go install' or binary),
#                kubectl available in PATH
# Author       : TECH MAHATO
# Created      : 2026-08-08
###############################################################################

set -e

# ------------------------------------------------------------------------------
# Color Definitions
# ------------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ------------------------------------------------------------------------------
# Helper Functions
# ------------------------------------------------------------------------------
info()    { echo -e "${YELLOW}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

step() {
    echo ""
    echo -e "${GREEN}============================================================${NC}"
    echo -e "${GREEN} [STEP $1/$TOTAL_STEPS] $2${NC}"
    echo -e "${GREEN}============================================================${NC}"
    echo ""
}

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------
TOTAL_STEPS=5
CLUSTER_NAME="istio-ecommerce"
KIND_CONFIG="/tmp/kind-${CLUSTER_NAME}-config.yaml"

# ------------------------------------------------------------------------------
# Pre-flight Checks
# ------------------------------------------------------------------------------
info "Pre-flight checks..."

if ! command -v docker &>/dev/null; then
    error "Docker is not installed. Run 01-install-tools.sh first."
fi

if ! docker info &>/dev/null; then
    error "Docker daemon is not running. Start Docker first."
fi

if ! command -v kind &>/dev/null; then
    info "Kind not found. Installing kind..."
    if command -v go &>/dev/null; then
        go install sigs.k8s.io/kind@latest
        export PATH=$PATH:$(go env GOPATH)/bin
    else
        # Fallback: download binary
        KIND_VERSION=$(curl -fsSL https://api.github.com/repos/kubernetes-sigs/kind/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
        curl -fsSL -o /usr/local/bin/kind "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-amd64"
        chmod +x /usr/local/bin/kind
    fi
fi

if ! command -v kubectl &>/dev/null; then
    error "kubectl is not installed. Run 01-install-tools.sh first."
fi

success "Pre-flight checks passed."

# ==============================================================================
# STEP 1: Generate Kind Cluster Configuration
# ==============================================================================
step 1 "Generating Kind cluster configuration"

cat > "${KIND_CONFIG}" <<'EOF'
# Kind cluster configuration for Istio Service Mesh Lab
# Cluster: istio-ecommerce
# Topology: 1 control-plane + 2 worker nodes
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: istio-ecommerce
nodes:
  # Control Plane Node
  - role: control-plane
    kubeadmConfigPatches:
      - |
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"
    extraPortMappings:
      - containerPort: 80
        hostPort: 80
        protocol: TCP
        listenAddress: "0.0.0.0"
      - containerPort: 443
        hostPort: 443
        protocol: TCP
        listenAddress: "0.0.0.0"
      - containerPort: 30080
        hostPort: 30080
        protocol: TCP
        listenAddress: "0.0.0.0"
      - containerPort: 30443
        hostPort: 30443
        protocol: TCP
        listenAddress: "0.0.0.0"

  # Worker Node 1 - Frontend Tier
  - role: worker
    kubeadmConfigPatches:
      - |
        kind: JoinConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "tier=frontend"

  # Worker Node 2 - Backend Tier
  - role: worker
    kubeadmConfigPatches:
      - |
        kind: JoinConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "tier=backend"
EOF

info "Configuration written to: ${KIND_CONFIG}"
cat "${KIND_CONFIG}"
success "Cluster configuration generated."

# ==============================================================================
# STEP 2: Delete Existing Cluster (if present)
# ==============================================================================
step 2 "Checking for existing cluster"

if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    info "Existing cluster '${CLUSTER_NAME}' found. Deleting..."
    kind delete cluster --name "${CLUSTER_NAME}"
    success "Existing cluster deleted."
else
    info "No existing cluster '${CLUSTER_NAME}' found. Proceeding."
fi

# ==============================================================================
# STEP 3: Create Kind Cluster
# ==============================================================================
step 3 "Creating Kind cluster '${CLUSTER_NAME}'"

info "This may take 2-5 minutes depending on network speed..."
kind create cluster --config "${KIND_CONFIG}"

success "Kind cluster '${CLUSTER_NAME}' created."

# ==============================================================================
# STEP 4: Wait for All Nodes to be Ready
# ==============================================================================
step 4 "Waiting for all nodes to be Ready"

info "Setting kubectl context..."
kubectl cluster-info --context "kind-${CLUSTER_NAME}" &>/dev/null

info "Waiting for nodes to reach Ready state..."
TIMEOUT=120
ELAPSED=0
INTERVAL=5

while true; do
    NOT_READY=$(kubectl get nodes --no-headers 2>/dev/null | grep -v " Ready" | wc -l)
    if [ "${NOT_READY}" -eq 0 ]; then
        break
    fi

    if [ "${ELAPSED}" -ge "${TIMEOUT}" ]; then
        error "Timeout: Nodes did not become Ready within ${TIMEOUT}s."
    fi

    info "Waiting for ${NOT_READY} node(s) to be Ready... (${ELAPSED}s/${TIMEOUT}s)"
    sleep ${INTERVAL}
    ELAPSED=$((ELAPSED + INTERVAL))
done

success "All nodes are Ready."

# ==============================================================================
# STEP 5: Display Cluster Information
# ==============================================================================
step 5 "Displaying cluster information"

echo ""
info "--- Cluster Info ---"
kubectl cluster-info

echo ""
info "--- Node Status ---"
kubectl get nodes -o wide

echo ""
info "--- Node Labels ---"
kubectl get nodes --show-labels

echo ""
info "--- System Pods ---"
kubectl get pods -n kube-system

echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN} Kind Cluster '${CLUSTER_NAME}' is Ready!${NC}"
echo -e "${GREEN}============================================================${NC}"
echo ""
info "Cluster: ${CLUSTER_NAME}"
info "Context: kind-${CLUSTER_NAME}"
info "Nodes:   1 control-plane + 2 workers"
info "Ports:   80, 443, 30080, 30443 mapped to host"
info ""
info "Next: Run 03-setup-cloud-provider-kind.sh for LoadBalancer support."

# Cleanup config file
rm -f "${KIND_CONFIG}"
