#!/bin/bash
###############################################################################
# Script Name  : 03-setup-cloud-provider-kind.sh
# Description  : Installs and configures cloud-provider-kind to enable
#                LoadBalancer service support in Kind clusters. This allows
#                Istio's ingress gateway to receive an EXTERNAL-IP address.
# Usage        : chmod +x 03-setup-cloud-provider-kind.sh && ./03-setup-cloud-provider-kind.sh
# Prerequisites: Kind cluster running, Go 1.23+ installed, kubectl in PATH
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
TOTAL_STEPS=7
CLUSTER_NAME="istio-ecommerce"
CLOUD_PROVIDER_BIN="cloud-provider-kind"
LOG_FILE="/tmp/cloud-provider-kind.log"

# ==============================================================================
# STEP 1: Pre-flight Checks
# ==============================================================================
step 1 "Pre-flight checks"

# Check Go installation
if ! command -v go &>/dev/null; then
    # Check common Go installation path
    if [ -x /usr/local/go/bin/go ]; then
        export PATH=$PATH:/usr/local/go/bin
    else
        error "Go is not installed. Install Go 1.23+ first using 01-install-tools.sh."
    fi
fi

GO_VERSION=$(go version | awk '{print $3}' | sed 's/go//')
info "Go version: ${GO_VERSION}"

# Ensure GOPATH is set
export GOPATH=${GOPATH:-$HOME/go}
export PATH=$PATH:${GOPATH}/bin

# Check kubectl
if ! command -v kubectl &>/dev/null; then
    error "kubectl is not installed. Run 01-install-tools.sh first."
fi

# Check Kind cluster is running
if ! kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    error "Kind cluster '${CLUSTER_NAME}' not found. Run 02-setup-kind-cluster.sh first."
fi

# Check Docker is running
if ! docker info &>/dev/null; then
    error "Docker daemon is not running."
fi

success "Pre-flight checks passed."

# ==============================================================================
# STEP 2: Install cloud-provider-kind
# ==============================================================================
step 2 "Installing cloud-provider-kind via go install"

if command -v ${CLOUD_PROVIDER_BIN} &>/dev/null || [ -f "/usr/local/bin/${CLOUD_PROVIDER_BIN}" ]; then
    info "cloud-provider-kind already installed."
else
    info "Building cloud-provider-kind from source..."
    go install sigs.k8s.io/cloud-provider-kind@latest

    if [ ! -f "${GOPATH}/bin/${CLOUD_PROVIDER_BIN}" ]; then
        error "Build failed. Binary not found at ${GOPATH}/bin/${CLOUD_PROVIDER_BIN}"
    fi

    success "cloud-provider-kind built successfully."
fi

# ==============================================================================
# STEP 3: Copy Binary to /usr/local/bin
# ==============================================================================
step 3 "Copying binary to /usr/local/bin"

if [ -f "${GOPATH}/bin/${CLOUD_PROVIDER_BIN}" ]; then
    if [ -w /usr/local/bin ] || [ "$(id -u)" -eq 0 ]; then
        cp "${GOPATH}/bin/${CLOUD_PROVIDER_BIN}" /usr/local/bin/
        chmod +x "/usr/local/bin/${CLOUD_PROVIDER_BIN}"
    else
        sudo cp "${GOPATH}/bin/${CLOUD_PROVIDER_BIN}" /usr/local/bin/
        sudo chmod +x "/usr/local/bin/${CLOUD_PROVIDER_BIN}"
    fi
    success "Binary copied to /usr/local/bin/${CLOUD_PROVIDER_BIN}"
else
    info "Binary already in /usr/local/bin or installed via PATH."
fi

info "Version check:"
${CLOUD_PROVIDER_BIN} --version 2>/dev/null || info "Binary ready (no --version flag supported)."

# ==============================================================================
# STEP 4: Remove Control-Plane Exclusion Label
# ==============================================================================
step 4 "Removing control-plane LoadBalancer exclusion label"

CONTROL_PLANE_NODE="${CLUSTER_NAME}-control-plane"

info "Removing node.kubernetes.io/exclude-from-external-load-balancers label..."
kubectl label node "${CONTROL_PLANE_NODE}" \
    node.kubernetes.io/exclude-from-external-load-balancers- \
    2>/dev/null || info "Label already removed or not present."

success "Control-plane exclusion label handled."

# ==============================================================================
# STEP 5: Start cloud-provider-kind in Background
# ==============================================================================
step 5 "Starting cloud-provider-kind in background"

# Kill any existing instance
if pgrep -f "${CLOUD_PROVIDER_BIN}" &>/dev/null; then
    info "Stopping existing cloud-provider-kind process..."
    pkill -f "${CLOUD_PROVIDER_BIN}" 2>/dev/null || true
    sleep 2
fi

info "Starting cloud-provider-kind (log: ${LOG_FILE})..."
nohup ${CLOUD_PROVIDER_BIN} > "${LOG_FILE}" 2>&1 &
CLOUD_PID=$!

sleep 3

if ps -p ${CLOUD_PID} &>/dev/null; then
    success "cloud-provider-kind running (PID: ${CLOUD_PID})."
else
    error "cloud-provider-kind failed to start. Check ${LOG_FILE} for details."
fi

# ==============================================================================
# STEP 6: Deploy Test LoadBalancer Service and Verify
# ==============================================================================
step 6 "Deploying test LoadBalancer service to verify functionality"

TEST_NAMESPACE="cpk-test"
TEST_DEPLOY="test-lb-deploy"
TEST_SVC="test-lb-service"

info "Creating test namespace..."
kubectl create namespace ${TEST_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

info "Deploying test pod..."
kubectl apply -n ${TEST_NAMESPACE} -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${TEST_DEPLOY}
  namespace: ${TEST_NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-lb
  template:
    metadata:
      labels:
        app: test-lb
    spec:
      containers:
        - name: nginx
          image: nginx:alpine
          ports:
            - containerPort: 80
EOF

info "Creating LoadBalancer service..."
kubectl apply -n ${TEST_NAMESPACE} -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: ${TEST_SVC}
  namespace: ${TEST_NAMESPACE}
spec:
  type: LoadBalancer
  selector:
    app: test-lb
  ports:
    - port: 80
      targetPort: 80
      protocol: TCP
EOF

info "Waiting for EXTERNAL-IP assignment..."
TIMEOUT=90
ELAPSED=0
INTERVAL=5
EXTERNAL_IP=""

while [ "${ELAPSED}" -lt "${TIMEOUT}" ]; do
    EXTERNAL_IP=$(kubectl get svc ${TEST_SVC} -n ${TEST_NAMESPACE} \
        -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)

    if [ -n "${EXTERNAL_IP}" ] && [ "${EXTERNAL_IP}" != "<pending>" ]; then
        break
    fi

    info "Waiting for EXTERNAL-IP... (${ELAPSED}s/${TIMEOUT}s)"
    sleep ${INTERVAL}
    ELAPSED=$((ELAPSED + INTERVAL))
done

if [ -n "${EXTERNAL_IP}" ] && [ "${EXTERNAL_IP}" != "<pending>" ]; then
    success "EXTERNAL-IP assigned: ${EXTERNAL_IP}"
    echo ""
    info "Service details:"
    kubectl get svc ${TEST_SVC} -n ${TEST_NAMESPACE} -o wide
else
    info "EXTERNAL-IP not assigned within ${TIMEOUT}s."
    info "Check cloud-provider-kind logs: ${LOG_FILE}"
    info "Service status:"
    kubectl get svc ${TEST_SVC} -n ${TEST_NAMESPACE} -o wide
fi

# ==============================================================================
# STEP 7: Cleanup Test Resources
# ==============================================================================
step 7 "Cleaning up test resources"

info "Deleting test namespace '${TEST_NAMESPACE}'..."
kubectl delete namespace ${TEST_NAMESPACE} --ignore-not-found=true

success "Test resources cleaned up."

# ==============================================================================
# Summary
# ==============================================================================
echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN} cloud-provider-kind Setup Complete!${NC}"
echo -e "${GREEN}============================================================${NC}"
echo ""
info "Status:    cloud-provider-kind running (PID: ${CLOUD_PID})"
info "Log file:  ${LOG_FILE}"
info "Cluster:   ${CLUSTER_NAME}"
info ""
info "LoadBalancer services will now receive EXTERNAL-IP addresses."
info "This enables Istio IngressGateway to get a routable IP."
info ""
info "To stop:   pkill -f cloud-provider-kind"
info "To check:  pgrep -f cloud-provider-kind"
info "To logs:   tail -f ${LOG_FILE}"
