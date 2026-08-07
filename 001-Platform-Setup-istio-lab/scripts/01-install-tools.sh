#!/bin/bash
###############################################################################
# Script Name  : 01-install-tools.sh
# Description  : Installs all required tools for the Istio Service Mesh lab
#                environment including Docker CE, kubectl, Helm 3, Go 1.23.0,
#                and essential system utilities.
# Usage        : chmod +x 01-install-tools.sh && sudo ./01-install-tools.sh
# Prerequisites: Ubuntu 24.04 LTS, sudo/root access, internet connectivity
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
# Pre-flight Checks
# ------------------------------------------------------------------------------
TOTAL_STEPS=6

if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root or with sudo."
fi

info "Starting tool installation for Istio Service Mesh Lab"
info "Target OS: Ubuntu 24.04 LTS"
echo ""

# ==============================================================================
# STEP 1: Install System Utilities
# ==============================================================================
step 1 "Installing system utilities"

UTILITIES="curl wget git unzip jq tree htop tmux net-tools"

info "Updating package index..."
apt-get update -qq

info "Installing: ${UTILITIES}"
apt-get install -y -qq ${UTILITIES} ca-certificates gnupg lsb-release apt-transport-https

success "System utilities installed."

# ==============================================================================
# STEP 2: Install Docker CE
# ==============================================================================
step 2 "Installing Docker CE (official docker.com repository)"

if command -v docker &>/dev/null; then
    info "Docker already installed: $(docker --version)"
else
    info "Adding Docker official GPG key..."
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc

    info "Adding Docker repository..."
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "${VERSION_CODENAME}") stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update -qq

    info "Installing Docker CE packages..."
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    info "Enabling and starting Docker service..."
    systemctl enable docker
    systemctl start docker

    # Add current sudo user to docker group if applicable
    if [ -n "${SUDO_USER}" ]; then
        usermod -aG docker "${SUDO_USER}"
        info "Added user '${SUDO_USER}' to docker group (re-login required)."
    fi

    success "Docker CE installed."
fi

# ==============================================================================
# STEP 3: Install kubectl (latest stable)
# ==============================================================================
step 3 "Installing kubectl (latest stable)"

if command -v kubectl &>/dev/null; then
    info "kubectl already installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
else
    info "Downloading latest stable kubectl..."
    KUBECTL_VERSION=$(curl -fsSL https://dl.k8s.io/release/stable.txt)
    curl -fsSL -o /usr/local/bin/kubectl \
        "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
    chmod +x /usr/local/bin/kubectl

    success "kubectl ${KUBECTL_VERSION} installed."
fi

# ==============================================================================
# STEP 4: Install Helm 3
# ==============================================================================
step 4 "Installing Helm 3"

if command -v helm &>/dev/null; then
    info "Helm already installed: $(helm version --short)"
else
    info "Downloading and installing Helm 3..."
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

    success "Helm 3 installed."
fi

# ==============================================================================
# STEP 5: Install Go 1.23.0
# ==============================================================================
step 5 "Installing Go 1.23.0"

GO_VERSION="1.23.0"
GO_INSTALL_DIR="/usr/local/go"

if [ -d "${GO_INSTALL_DIR}" ] && "${GO_INSTALL_DIR}/bin/go" version 2>/dev/null | grep -q "${GO_VERSION}"; then
    info "Go ${GO_VERSION} already installed: $(${GO_INSTALL_DIR}/bin/go version)"
else
    info "Downloading Go ${GO_VERSION}..."
    curl -fsSL -o /tmp/go${GO_VERSION}.linux-amd64.tar.gz \
        "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz"

    info "Removing any existing Go installation..."
    rm -rf ${GO_INSTALL_DIR}

    info "Extracting Go ${GO_VERSION} to /usr/local..."
    tar -C /usr/local -xzf /tmp/go${GO_VERSION}.linux-amd64.tar.gz
    rm -f /tmp/go${GO_VERSION}.linux-amd64.tar.gz

    success "Go ${GO_VERSION} installed to ${GO_INSTALL_DIR}."
fi

# ==============================================================================
# STEP 6: Configure PATH and Verify Installations
# ==============================================================================
step 6 "Configuring PATH exports and verifying installations"

# Determine target user's home directory
if [ -n "${SUDO_USER}" ]; then
    USER_HOME=$(getent passwd "${SUDO_USER}" | cut -d: -f6)
else
    USER_HOME="${HOME}"
fi

BASHRC="${USER_HOME}/.bashrc"

info "Adding PATH exports to ${BASHRC}..."

# Define PATH entries to add
declare -a PATH_ENTRIES=(
    'export PATH=$PATH:/usr/local/go/bin'
    'export GOPATH=$HOME/go'
    'export PATH=$PATH:$GOPATH/bin'
    'export PATH=$PATH:/usr/local/bin'
)

for entry in "${PATH_ENTRIES[@]}"; do
    if ! grep -qF "${entry}" "${BASHRC}" 2>/dev/null; then
        echo "${entry}" >> "${BASHRC}"
        info "Added: ${entry}"
    else
        info "Already present: ${entry}"
    fi
done

# Source for current session
export PATH=$PATH:/usr/local/go/bin:${USER_HOME}/go/bin:/usr/local/bin

success "PATH configuration complete."

echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN} Installation Verification${NC}"
echo -e "${GREEN}============================================================${NC}"
echo ""

info "Docker:   $(docker --version 2>/dev/null || echo 'NOT FOUND')"
info "kubectl:  $(kubectl version --client 2>/dev/null | head -1 || echo 'NOT FOUND')"
info "Helm:     $(helm version --short 2>/dev/null || echo 'NOT FOUND')"
info "Go:       $(/usr/local/go/bin/go version 2>/dev/null || echo 'NOT FOUND')"
info "curl:     $(curl --version 2>/dev/null | head -1 || echo 'NOT FOUND')"
info "wget:     $(wget --version 2>/dev/null | head -1 || echo 'NOT FOUND')"
info "git:      $(git --version 2>/dev/null || echo 'NOT FOUND')"
info "jq:       $(jq --version 2>/dev/null || echo 'NOT FOUND')"
info "tree:     $(tree --version 2>/dev/null | head -1 || echo 'NOT FOUND')"
info "htop:     $(htop --version 2>/dev/null | head -1 || echo 'NOT FOUND')"
info "tmux:     $(tmux -V 2>/dev/null || echo 'NOT FOUND')"
info "unzip:    $(unzip -v 2>/dev/null | head -1 || echo 'NOT FOUND')"
info "net-tools: $(ifconfig --version 2>&1 | head -1 || echo 'installed')"

echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN} All tools installed successfully!${NC}"
echo -e "${GREEN}============================================================${NC}"
echo ""
info "NOTE: Log out and log back in for docker group membership to take effect."
info "Run 'source ~/.bashrc' to load PATH changes in current session."
