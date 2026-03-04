# CKS Labs - Current Cluster Capabilities

> Cluster: k8s-master (192.168.1.40) + k8s-agent (192.168.1.41)
> K8s: v1.35.1 | OS: Debian 12 | Runtime: containerd 2.2.1
> Status: Nodes NotReady (no CNI) — install CNI first before all labs

## Prerequisite (must do first)

| Lab | Topic | File |
|-----|-------|------|
| LAB-00 | Install Calico CNI (makes cluster functional) | @labs/LAB_00_install_cni.md |

---

## Cluster Setup (15%) — Doable Now

| Lab | Topic | CKS Domain |
|-----|-------|------------|
| LAB-01 | Network Policies — restrict ingress/egress | Cluster Setup |
| LAB-12 | Ingress with TLS (self-signed + cert-manager) | Cluster Setup |
| LAB-16 | API Server hardening (anonymous auth, insecure port, admission) | Cluster Setup |

---

## Cluster Hardening (15%) — Doable Now

| Lab | Topic | CKS Domain |
|-----|-------|------------|
| LAB-02 | RBAC — least-privilege Roles and ClusterRoles | Cluster Hardening |
| LAB-03 | ServiceAccount hardening (disable automount, minimize permissions) | Cluster Hardening |
| LAB-16 | Restrict Kubernetes API access | Cluster Hardening |

---

## System Hardening (10%) — Doable Now (AppArmor installed)

| Lab | Topic | CKS Domain |
|-----|-------|------------|
| LAB-06 | AppArmor — write and enforce profiles for pods | System Hardening |
| LAB-07 | Seccomp — custom runtime/localhost profiles | System Hardening |

---

## Minimize Microservice Vulnerabilities (20%) — Doable Now

| Lab | Topic | CKS Domain |
|-----|-------|------------|
| LAB-04 | Pod Security Standards (baseline/restricted/privileged labels) | Minimize Vulns |
| LAB-05 | Secrets management + etcd encryption at rest | Minimize Vulns |
| LAB-15 | Immutable containers (readOnlyRootFilesystem, no privilege escalation) | Minimize Vulns |

---

## Monitoring, Logging and Runtime Security (20%) — Partially Doable

| Lab | Topic | CKS Domain |
|-----|-------|------------|
| LAB-08 | Kubernetes Audit Logging (configure policy + review logs) | Monitoring |
| LAB-15 | Immutable containers at runtime | Monitoring |
