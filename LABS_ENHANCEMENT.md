# CKS Labs — Enhancements Required

These labs require additional tools or components to be installed on the cluster.

---

## Priority 1 — Install First (blocks other labs)

### CNI Plugin (Calico)
- **Required for:** ALL labs (nodes are NotReady without CNI)
- **Install on:** k8s-master ($MASTER_IP)
- **Command:**
  ```bash
  kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/calico.yaml
  ```
- **Enables:** Network Policies, all pod networking

---

## Priority 2 — Core CKS Tools

### kube-bench
- **Required for:** LAB-11 (CIS Benchmark)
- **Install on:** k8s-master ($MASTER_IP)
- **Method:** Download binary from GitHub releases
  ```bash
  curl -L https://github.com/aquasecurity/kube-bench/releases/latest/download/kube-bench_linux_amd64.tar.gz | tar xz
  sudo mv kube-bench /usr/local/bin/
  ```
- **Enables:** CIS benchmark checks against etcd, kubelet, kube-apiserver, kubedns

### Trivy
- **Required for:** LAB-10 (Image Scanning)
- **Install on:** k8s-master ($MASTER_IP)
- **Method:** apt or binary
  ```bash
  curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
  ```
- **Enables:** Image vulnerability scanning, SBOM generation

### Falco
- **Required for:** LAB-09 (Runtime Security)
- **Install on:** BOTH nodes ($MASTER_IP AND $AGENT_IP)
- **Method:** Official Falco apt repo
  ```bash
  curl -fsSL https://falco.org/repo/falcosecurity-packages.asc | sudo gpg --dearmor -o /usr/share/keyrings/falco-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/falco-archive-keyring.gpg] https://download.falco.org/packages/deb stable main" | sudo tee /etc/apt/sources.list.d/falcosecurity.list
  sudo apt update && sudo apt install -y falco
  ```
- **Enables:** Runtime behavioral analysis, syscall-level threat detection

### Helm
- **Required for:** cert-manager (LAB-12), Falco operator, Kyverno
- **Install on:** k8s-master ($MASTER_IP)
  ```bash
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  ```

---

## Priority 3 — Advanced CKS Tools

### cosign
- **Required for:** LAB-13 (Image Signing & Verification)
- **Install on:** k8s-master ($MASTER_IP)
  ```bash
  curl -Lo cosign https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64
  chmod +x cosign && sudo mv cosign /usr/local/bin/
  ```
- **Enables:** Sign container images, verify signatures in admission

### kubesec
- **Required for:** LAB-14 (Static Analysis)
- **Install on:** k8s-master ($MASTER_IP)
  ```bash
  curl -sSX POST --data-binary @pod.yaml https://v2.kubesec.io/scan
  # or install binary:
  curl -Lo kubesec https://github.com/controlplaneio/kubesec/releases/latest/download/kubesec_linux_amd64
  chmod +x kubesec && sudo mv kubesec /usr/local/bin/
  ```

### cert-manager (via Helm)
- **Required for:** LAB-12 (Ingress TLS with auto-cert)
- **Install on:** k8s-master ($MASTER_IP)
  ```bash
  helm repo add jetstack https://charts.jetstack.io
  helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --set crds.enabled=true
  ```

---

## Priority 4 — Pod-to-Pod Encryption

### Cilium (replaces Calico for mTLS labs)
- **Required for:** LAB-17 (Pod-to-Pod encryption with Wireguard)
- **Note:** If Calico is already installed, can add WireGuard encryption to Calico instead
- **Alternative approach:** Use Calico WireGuard feature (simpler, less reinstall)
  ```bash
  # Enable WireGuard on Calico (no reinstall needed)
  kubectl patch felixconfiguration default --type='merge' -p '{"spec":{"wireguardEnabled":true}}'
  ```

### Istio (for mTLS labs)
- **Required for:** LAB-17 alternative (Istio mTLS)
- **Install on:** k8s-master ($MASTER_IP)
  ```bash
  curl -L https://istio.io/downloadIstio | sh -
  sudo mv istio-*/bin/istioctl /usr/local/bin/
  istioctl install --set profile=minimal -y
  ```
- **Note:** Istio is resource-heavy on small VMs. WireGuard/Calico may be better for this lab env.

---

## Summary Table

| Tool | Nodes | Priority | Blocks Lab |
|------|-------|----------|------------|
| Calico CNI | master | CRITICAL | ALL |
| kube-bench | master | High | LAB-11 |
| Trivy | master | High | LAB-10 |
| Falco | both | High | LAB-09 |
| Helm | master | High | LAB-12, LAB-13 |
| cosign | master | Medium | LAB-13 |
| kubesec | master | Medium | LAB-14 |
| cert-manager | master | Medium | LAB-12 |
| Istio or Calico WireGuard | master | Low | LAB-17 |
