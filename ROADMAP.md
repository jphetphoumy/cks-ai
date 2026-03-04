# CKS Learning Roadmap — Progress Tracker

> Last updated: 2026-02-27
> Cluster: k8s-master (192.168.1.40) + k8s-agent (192.168.1.41) | K8s v1.35.1
> Exam target: CKS (3-day sprint)

---

## Cluster State

| Component | Status |
|-----------|--------|
| k8s-master (192.168.1.40) | ✅ Ready |
| k8s-agent (192.168.1.41) | ✅ Ready |
| Calico CNI | ✅ Running |
| kube-bench | ✅ v0.10.1 (master) |
| trivy | ✅ v0.69.1 (master) |
| helm | ✅ v3.20.0 (master) |
| cosign | ✅ v3.0.5 (master) |
| kubesec | ✅ v2.14.2 (master) |
| falco (master) | ✅ v0.43.0 — modern-bpf active |
| falco (agent) | ✅ v0.43.0 — modern-bpf active |

---

## Prerequisites

| # | Task | Status |
|---|------|--------|
| P1 | Install Calico CNI | ✅ Done |
| P2 | Install kube-bench on master | ✅ Done |
| P3 | Install Trivy on master | ✅ Done |
| P4 | Install Helm on master | ✅ Done |
| P5 | Install cosign on master | ✅ Done |
| P6 | Install kubesec on master | ✅ Done |
| P7 | Install Falco on master + agent | ✅ Done |

---

## Day 1 — Cluster Setup & Hardening (30% of exam)

| # | Lab | Domain | Weight | Status |
|---|-----|--------|--------|--------|
| 1 | LAB-01 Network Policies | Cluster Setup | 15% | ✅ Done — scored 3/4 (Q2 AND vs OR trap missed) |
| 2 | LAB-02 RBAC least-privilege | Cluster Hardening | 15% | ✅ Done — scored 3/4 (retries on naming + RoleBinding subject) |
| 3 | LAB-03 ServiceAccount hardening | Cluster Hardening | 15% | ✅ Done — scored 4/4 |
| 4 | LAB-16 API Server hardening | Cluster Hardening | 15% | ✅ Done — scored 6/6 |

---

## Day 2 — Microservice Vulnerabilities & System Hardening (30% of exam)

| # | Lab | Domain | Weight | Status |
|---|-----|--------|--------|--------|
| 5 | LAB-04 Pod Security Standards | Minimize Vulns | 20% | ✅ Done — scored 5/5 |
| 6 | LAB-05 Secrets + etcd encryption | Minimize Vulns | 20% | ✅ Done — scored 3/4 |
| 7 | LAB-06 AppArmor | System Hardening | 10% | ✅ Done — scored 4/4 |
| 8 | LAB-07 Seccomp | System Hardening | 10% | ✅ Done — scored 5/5 |
| 9 | LAB-08 Audit Logging | Monitoring | 20% | ✅ Done — scored 6/6 |
| 10 | LAB-15 Immutable containers | Monitoring | 20% | ⬜ Pending |

---

## Day 3 — Supply Chain & Runtime Security (40% of exam)

| # | Lab | Domain | Weight | Status |
|---|-----|--------|--------|--------|
| 11 | LAB-09 Falco runtime security | Monitoring | 20% | ⬜ Pending (needs Falco) |
| 12 | LAB-10 Trivy image scanning | Supply Chain | 20% | ⬜ Pending (needs Trivy) |
| 13 | LAB-11 CIS Benchmark kube-bench | Cluster Setup | 15% | ⬜ Pending |
| 14 | LAB-12 Ingress with TLS | Cluster Setup | 15% | ⬜ Pending |
| 15 | LAB-13 Image signing cosign | Supply Chain | 20% | ⬜ Pending (needs cosign) |
| 16 | LAB-14 Static analysis kubesec | Supply Chain | 20% | ⬜ Pending (needs kubesec) |

---

## Character Sheet — CKS Specialist

> Class: Kubernetes Security Engineer | Subclass: CTF-Hacker-turned-Defender
> Total XP: 470 / 1600 | Overall Level: 4

```
[===============>                           ] 29.4% to CKS Certification
```

### Skill Tree

| Skill | Level | XP | Notes |
|---|---|---|---|
| Network Policies | 3 / 10 | ██░░░░░░░░ | Solid fundamentals. Missed AND/OR YAML trap — needs 1 more rep |
| RBAC | 3 / 10 | ███░░░░░░░ | Completed. Good concept understanding. Needed retries on naming + RoleBinding subject mismatch |
| ServiceAccounts | 3 / 10 | ███░░░░░░░ | Completed. Strong attack-path thinking. Caught resourceNames trap. Investigated Calico perms. |
| API Server Hardening | 3 / 10 | ███░░░░░░░ | Clean execution. Hardened kube-apiserver (anonymous-auth, profiling, admission plugins), verified kubelet Webhook auth, blocked metadata endpoint. |
| Pod Security Standards | 3 / 10 | ███░░░░░░░ | Strong grasp of PSA concepts (warn/enforce/audit modes). Demonstrated real-world thinking on kube-system hardening. |
| Secrets / etcd Encryption | 2 / 10 | ██░░░░░░░░ | Enabled AES-CBC encryption in etcd. Proved plaintext vulnerability, configured provider, re-encrypted existing secrets. |
| AppArmor | 2 / 10 | ██░░░░░░░░ | Mastered AppArmor concepts. Fixed critical pod-spec placement bug (container-level vs pod-level securityContext). Debugged exec issues. Verified enforcement via crictl. |
| Seccomp | 2 / 10 | ██░░░░░░░░ | All seccomp profile types deployed and tested. Custom profiles blocking chmod confirmed via crictl. Enabled RuntimeDefault cluster-wide on master. |
| Audit Logging | 3 / 10 | ███░░░░░░░ | Clean execution. Quick grasp of jq filtering; understood audit policy configuration and log analysis. Demonstrated diagnostic thinking on distinguishing transient vs real RBAC issues. |
| Immutable Containers | 0 / 10 | ░░░░░░░░░░ | Locked |
| Falco Runtime Security | 0 / 10 | ░░░░░░░░░░ | Locked |
| Trivy Image Scanning | 0 / 10 | ░░░░░░░░░░ | Locked |
| CIS Benchmark | 0 / 10 | ░░░░░░░░░░ | Locked |
| Ingress TLS | 0 / 10 | ░░░░░░░░░░ | Locked |
| Image Signing (cosign) | 0 / 10 | ░░░░░░░░░░ | Locked |
| Static Analysis (kubesec) | 0 / 10 | ░░░░░░░░░░ | Locked |

### Passive Traits (from background)

| Trait | Bonus |
|---|---|
| CKA Certified | +10% XP on cluster mechanics |
| CTF / webapp hacking | +15% XP on attack-vector questions |
| SecNumCloud / ISO 27001 | +10% XP on supply chain topics |
| Daily securityContext usage | +5% XP on pod hardening labs |

### Known Weaknesses (Debuffs)

| Debuff | Effect | Cure |
|---|---|---|
| *(None — all cured!)* | | |

---

## Legend

- ✅ Done
- 🔄 In Progress
- ⬜ Pending
- ❌ Blocked (dependency missing)
