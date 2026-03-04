# CKS Learning Plan — 3-Day Kata Track

> **Profile:** CKA certified, CTF/webapp hacking background, container escape awareness, ISO 27001 supply chain context, daily securityContext usage. Needs: CKS-specific tooling, kernel hardening, runtime security, depth on all domains.
>
> **Approach:** Kata-style — do each lab multiple times until commands are muscle memory. Think like an attacker, defend accordingly.

---

## Prerequisites — Do Before Day 1

| Step | Action | Status |
|------|--------|--------|
| 1 | Install Calico CNI → @labs/LAB_00_install_cni.md | ✅ Done — both nodes Ready, calico-system Running |
| 2 | Install kube-bench, Trivy, Helm, cosign, kubesec on k8s-master (192.168.1.40) | ⬜ Pending |
| 3 | Install Falco on BOTH nodes (192.168.1.40 + 192.168.1.41) | ⬜ Pending |

Full installation commands in @LABS_ENHANCEMENT.md

---

## Day 1 — Cluster Setup & Hardening (30% of exam)

**Goal:** Lock down the API surface, enforce RBAC, restrict network traffic.

| # | Lab | CKS Domain | Weight | File |
|---|-----|------------|--------|------|
| 1 | Network Policies — default deny + allow rules | Cluster Setup | 15% | @labs/LAB_01_network_policies.md |
| 2 | RBAC — least-privilege Roles, find over-privileged accounts | Cluster Hardening | 15% | @labs/LAB_02_rbac.md |
| 3 | ServiceAccount hardening — disable automount, minimal permissions | Cluster Hardening | 15% | @labs/LAB_03_service_accounts.md ✅ |
| 4 | API Server hardening — anonymous auth, admission plugins, kubelet | Cluster Hardening | 15% | @labs/LAB_16_api_server_hardening.md |

**Day 1 Kata loop:** After completing all labs, reset and redo LAB_01 + LAB_02 from memory. Target: under 10 min each.

---

## Day 2 — Microservice Vulnerabilities & System Hardening (30% of exam)

**Goal:** Harden pods, encrypt secrets, restrict syscalls, configure audit logging.

| # | Lab | CKS Domain | Weight | File |
|---|-----|------------|--------|------|
| 5 | Pod Security Standards — enforce/warn/audit on namespaces | Minimize Vulns | 20% | @labs/LAB_04_pod_security_standards.md |
| 6 | Secrets + etcd encryption at rest | Minimize Vulns | 20% | @labs/LAB_05_secrets_etcd_encryption.md |
| 7 | AppArmor — write and enforce profiles on pods | System Hardening | 10% | @labs/LAB_06_apparmor.md |
| 8 | Seccomp — RuntimeDefault and custom localhost profiles | System Hardening | 10% | @labs/LAB_07_seccomp.md |
| 9 | Audit Logging — configure kube-apiserver audit policy | Monitoring | 20% | @labs/LAB_08_audit_logging.md |
| 10 | Immutable containers — readOnlyRootFilesystem + emptyDir | Monitoring | 20% | @labs/LAB_15_immutable_containers.md |

**Day 2 Kata loop:** Redo LAB_05 (etcd encryption) and LAB_06 (AppArmor) from memory. These involve multi-file edits that are easy to get wrong.

---

## Day 3 — Supply Chain & Runtime Security (40% of exam)

**Goal:** Image scanning, signing, static analysis, Falco detection, CIS benchmarks.

| # | Lab | CKS Domain | Weight | File |
|---|-----|------------|--------|------|
| 11 | Falco — install, default rules, custom rules, detect attacks | Monitoring | 20% | @labs/LAB_09_falco.md |
| 12 | Trivy — image scanning, SBOM generation, cluster scan | Supply Chain | 20% | @labs/LAB_10_trivy_image_scanning.md |
| 13 | CIS Benchmark with kube-bench — run, read, fix findings | Cluster Setup | 15% | @labs/LAB_11_cis_benchmark.md |
| 14 | Ingress with TLS — openssl cert, TLS secret, Ingress resource | Cluster Setup | 15% | @labs/LAB_12_ingress_tls.md |
| 15 | Image signing with cosign + kubesec static analysis | Supply Chain | 20% | @labs/LAB_13_image_signing_cosign.md |
| 16 | Static analysis — kubesec, trivy config, Dockerfile scanning | Supply Chain | 20% | @labs/LAB_14_static_analysis.md |

**Day 3 Kata loop:** Chain LAB_10 → LAB_14 → LAB_13 as a full supply chain workflow: scan → fix → sign.

---

## Labs Requiring Extra Installation

These labs need tools installed first (see @LABS_ENHANCEMENT.md for commands):

| Lab | Needs |
|-----|-------|
| LAB_09 (Falco) | falco on both nodes |
| LAB_10 (Trivy) | trivy binary |
| LAB_11 (kube-bench) | kube-bench binary |
| LAB_12 (Ingress TLS) | nginx ingress controller via kubectl apply |
| LAB_13 (cosign) | cosign binary, optionally Kyverno via Helm |
| LAB_14 (kubesec) | kubesec binary |

---

## CKS Exam Quick Reference

### Command Cheatsheet (muscle memory targets)

```bash
# RBAC
kubectl auth can-i --list --as=system:serviceaccount:<ns>:<sa>
kubectl get clusterrolebindings -o json | python3 -c "import json,sys; [print(b['metadata']['name'], b.get('subjects','')) for b in json.load(sys.stdin)['items'] if b['roleRef']['name']=='cluster-admin']"

# ServiceAccounts
kubectl patch sa default -n <ns> -p '{"automountServiceAccountToken": false}'

# PSA labels
kubectl label ns <ns> pod-security.kubernetes.io/enforce=restricted
kubectl label ns <ns> pod-security.kubernetes.io/warn=restricted
kubectl label ns <ns> pod-security.kubernetes.io/audit=restricted

# Secrets / etcd
kubectl create secret generic <name> --from-literal=key=val
sudo ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/default/<secret-name> | strings

# AppArmor
sudo apparmor_parser -r /etc/apparmor.d/<profile>
sudo aa-status | grep <profile>

# Seccomp dir
ls /var/lib/kubelet/seccomp/

# Audit log
sudo tail -f /var/log/kubernetes/audit/audit.log | python3 -m json.tool

# TLS cert
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt \
  -subj "/CN=<host>/O=<org>" -addext "subjectAltName=DNS:<host>"

# Trivy
trivy image --severity HIGH,CRITICAL --ignore-unfixed <image>
trivy config <file.yaml>

# kube-bench
sudo kube-bench run --targets master
sudo kube-bench run --targets node

# cosign
cosign generate-key-pair
cosign sign --key cosign.key <image>
cosign verify --key cosign.pub <image>

# Falco
sudo journalctl -fu falco | grep <pod-name>
```

### Key File Locations

| File | Purpose |
|------|---------|
| `/etc/kubernetes/manifests/kube-apiserver.yaml` | API server config (static pod) |
| `/etc/kubernetes/manifests/etcd.yaml` | etcd config |
| `/var/lib/kubelet/config.yaml` | kubelet config |
| `/etc/kubernetes/pki/` | Cluster certificates |
| `/etc/apparmor.d/` | AppArmor profiles |
| `/var/lib/kubelet/seccomp/` | Seccomp profiles |
| `/var/log/kubernetes/audit/audit.log` | Audit log |
| `/etc/falco/rules.d/` | Custom Falco rules |

---

## Exam Strategy

- **Time:** 2 hours, ~15-20 questions, browser-based terminal
- **Docs allowed:** kubernetes.io/docs, kubernetes.io/blog, falco.org, aquasecurity.github.io
- **Scoring:** Each question has a weight — tackle high-weight questions first
- **Your edge:** CTF mindset helps with "find and fix" questions — you already know what attackers do

### Prioritize by weight:
1. Minimize Microservice Vulnerabilities (20%) — PSA, Secrets, immutable containers
2. Supply Chain Security (20%) — Trivy, cosign, static analysis
3. Monitoring & Runtime Security (20%) — Falco, audit logs
4. Cluster Setup (15%) — Network Policies, Ingress TLS
5. Cluster Hardening (15%) — RBAC, ServiceAccounts, API hardening
6. System Hardening (10%) — AppArmor, Seccomp
