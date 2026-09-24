#!/usr/bin/env bash
# CKS Lab Environment Setup
# Installs all required tools on the cluster nodes.
# Idempotent: safe to run multiple times.
#
# Usage:
#   ./setup.sh              # full setup (tools + kubeconfig)
#   ./setup.sh --tools      # install tools on nodes only
#   ./setup.sh --kubeconfig # refresh kubeconfig only

set -euo pipefail

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

# Node addresses and SSH user come from nodes.env at the repo root (gitignored).
# Copy nodes.env.example → nodes.env and fill in your own values.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck source=/dev/null
[ -f "$REPO_ROOT/nodes.env" ] && . "$REPO_ROOT/nodes.env"

MASTER="${MASTER_IP:?MASTER_IP not set — create nodes.env from nodes.env.example}"
AGENT="${AGENT_IP:?AGENT_IP not set — create nodes.env from nodes.env.example}"
SSH_USER="${SSH_USER:?SSH_USER not set — create nodes.env from nodes.env.example}"
KUBECONFIG_PATH="$HOME/.kube/config"

# Pinned versions
KUBE_BENCH_VERSION="0.10.1"
TRIVY_VERSION="0.69.1"
HELM_VERSION="3.20.0"
COSIGN_VERSION="3.0.5"
KUBESEC_VERSION="2.14.2"
FALCO_VERSION="0.43.0"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${CYAN}[setup]${NC} $*"; }
ok()   { echo -e "${GREEN}[ok]${NC}    $*"; }
warn() { echo -e "${YELLOW}[warn]${NC}  $*"; }
err()  { echo -e "${RED}[error]${NC} $*" >&2; }

ssh_master() { ssh "${SSH_USER}@${MASTER}" "$@"; }
ssh_agent()  { ssh "${SSH_USER}@${AGENT}"  "$@"; }

# Run a command on a node and report pass/skip
install_if_missing() {
  local node="$1"
  local binary="$2"
  local install_cmd="$3"

  if ssh "${SSH_USER}@${node}" "which ${binary} >/dev/null 2>&1"; then
    local version
    version=$(ssh "${SSH_USER}@${node}" "${binary} version 2>/dev/null | head -1" || true)
    ok "${binary} already installed on ${node} — ${version}"
  else
    log "Installing ${binary} on ${node}..."
    ssh "${SSH_USER}@${node}" "sudo bash -c '${install_cmd}'"
    ok "${binary} installed on ${node}"
  fi
}

# ---------------------------------------------------------------------------
# Kubeconfig
# ---------------------------------------------------------------------------

setup_kubeconfig() {
  log "Fetching kubeconfig from ${MASTER}..."
  mkdir -p "$(dirname "$KUBECONFIG_PATH")"
  ssh_master "sudo cat /etc/kubernetes/admin.conf" > "$KUBECONFIG_PATH"
  chmod 600 "$KUBECONFIG_PATH"
  ok "Kubeconfig written to ${KUBECONFIG_PATH}"

  log "Verifying cluster access..."
  if nix shell nixpkgs#kubectl -c kubectl get nodes --request-timeout=5s >/dev/null 2>&1; then
    ok "Cluster reachable — $(nix shell nixpkgs#kubectl -c kubectl get nodes --no-headers 2>/dev/null | awk '{print $1, $2}' | tr '\n' '  ')"
  else
    err "Cannot reach cluster after kubeconfig refresh"
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# Tool installers (run on remote nodes via sudo bash)
# ---------------------------------------------------------------------------

install_kube_bench() {
  local node="$1"
  local cmd="
    if which kube-bench >/dev/null 2>&1; then exit 0; fi
    curl -sL https://github.com/aquasecurity/kube-bench/releases/download/v${KUBE_BENCH_VERSION}/kube-bench_${KUBE_BENCH_VERSION}_linux_amd64.tar.gz \
      | tar xz -C /usr/local/bin/ kube-bench
  "
  install_if_missing "$node" "kube-bench" "$cmd"
}

install_trivy() {
  local node="$1"
  local cmd="
    if which trivy >/dev/null 2>&1; then exit 0; fi
    curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh \
      | sh -s -- -b /usr/local/bin v${TRIVY_VERSION}
  "
  install_if_missing "$node" "trivy" "$cmd"
}

install_helm() {
  local node="$1"
  local cmd="
    if which helm >/dev/null 2>&1; then exit 0; fi
    curl -fsSL https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz \
      | tar xz -C /usr/local/bin/ --strip-components=1 linux-amd64/helm
  "
  install_if_missing "$node" "helm" "$cmd"
}

install_cosign() {
  local node="$1"
  local cmd="
    if which cosign >/dev/null 2>&1; then exit 0; fi
    curl -sLo /usr/local/bin/cosign \
      https://github.com/sigstore/cosign/releases/download/v${COSIGN_VERSION}/cosign-linux-amd64
    chmod +x /usr/local/bin/cosign
  "
  install_if_missing "$node" "cosign" "$cmd"
}

install_kubesec() {
  local node="$1"
  local cmd="
    if which kubesec >/dev/null 2>&1; then exit 0; fi
    curl -sL https://github.com/controlplaneio/kubesec/releases/download/v${KUBESEC_VERSION}/kubesec_linux_amd64.tar.gz \
      | tar xz -C /usr/local/bin/ kubesec
  "
  install_if_missing "$node" "kubesec" "$cmd"
}

install_falco() {
  local node="$1"
  log "Checking Falco on ${node}..."

  local active
  active=$(ssh "${SSH_USER}@${node}" "sudo systemctl is-active falco-modern-bpf.service 2>/dev/null || echo inactive")

  if [[ "$active" == "active" ]]; then
    ok "Falco already running on ${node}"
    return
  fi

  log "Installing Falco ${FALCO_VERSION} on ${node}..."
  ssh "${SSH_USER}@${node}" "sudo bash -s" <<EOF
set -e
curl -fsSL https://falco.org/repo/falcosecurity-packages.asc \
  | gpg --dearmor -o /usr/share/keyrings/falco-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/falco-archive-keyring.gpg] https://download.falco.org/packages/deb stable main" \
  | tee /etc/apt/sources.list.d/falcosecurity.list
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y falco=${FALCO_VERSION}
systemctl start falco-modern-bpf.service
EOF
  ok "Falco installed and started on ${node}"
}

# ---------------------------------------------------------------------------
# Verification
# ---------------------------------------------------------------------------

verify_all() {
  echo ""
  log "=== Verification ==="

  echo ""
  log "Master (${MASTER}):"
  ssh_master "sudo bash -s" <<'EOF'
for bin in kube-bench trivy helm cosign kubesec; do
  if which "$bin" >/dev/null 2>&1; then
    version=$($bin version 2>/dev/null | head -1 || $bin --version 2>/dev/null | head -1 || echo "?")
    printf "  %-12s %s\n" "$bin" "$version"
  else
    printf "  %-12s MISSING\n" "$bin"
  fi
done
falco_status=$(systemctl is-active falco-modern-bpf.service 2>/dev/null || echo inactive)
printf "  %-12s %s\n" "falco" "$falco_status"
EOF

  echo ""
  log "Agent (${AGENT}):"
  ssh_agent "sudo bash -s" <<'EOF'
falco_status=$(systemctl is-active falco-modern-bpf.service 2>/dev/null || echo inactive)
printf "  %-12s %s\n" "falco" "$falco_status"
EOF

  echo ""
  log "Local kubectl:"
  nix shell nixpkgs#kubectl -c kubectl get nodes 2>/dev/null || warn "kubectl not reachable"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

MODE="${1:-all}"

case "$MODE" in
  --kubeconfig)
    setup_kubeconfig
    ;;
  --tools)
    log "Installing tools on master (${MASTER})..."
    install_kube_bench "$MASTER"
    install_trivy      "$MASTER"
    install_helm       "$MASTER"
    install_cosign     "$MASTER"
    install_kubesec    "$MASTER"
    install_falco      "$MASTER"

    log "Installing tools on agent (${AGENT})..."
    install_falco "$AGENT"

    verify_all
    ;;
  all|"")
    setup_kubeconfig

    log "Installing tools on master (${MASTER})..."
    install_kube_bench "$MASTER"
    install_trivy      "$MASTER"
    install_helm       "$MASTER"
    install_cosign     "$MASTER"
    install_kubesec    "$MASTER"
    install_falco      "$MASTER"

    log "Installing tools on agent (${AGENT})..."
    install_falco "$AGENT"

    verify_all
    ;;
  *)
    echo "Usage: $0 [--kubeconfig | --tools | (default: all)]"
    exit 1
    ;;
esac

echo ""
ok "Setup complete."
