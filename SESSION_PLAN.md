# Session Plan — Feb 27 & 28 (Updated)

## Context for the next agent

- Read `app-roadmap/data.json` for current skill levels, XP, and debuffs
- Read `PLAN.md` for the full lab list and day structure
- The student has **CKA certified** + **CTF/hacking background** — strong attacker mindset, picks up concepts fast
- **Exam is Feb 28 at 10:00 CET** — hard deadline

### Current progress (as of Feb 27, 22:00)
- LAB-01 Network Policies ✅
- LAB-02 RBAC ✅
- LAB-03 ServiceAccount Hardening ✅
- LAB-04 Pod Security Standards ✅
- LAB-05 Secrets + etcd encryption ✅
- LAB-06 AppArmor ✅
- LAB-07 Seccomp ✅
- LAB-08 Audit Logging ✅
- LAB-16 API Server Hardening ✅
- **9/16 complete — 7 labs remaining**

### Known weak points (check debuffs in data.json)
- Typos under pressure — namespace names, resource names
- resourceNames confusion in RBAC
- AND/OR NetworkPolicy YAML trap

---

## Cluster state

- **Do not recreate or reset the cluster** — it is running and healthy
- Master: `$MASTER_IP` — all tools installed (trivy, helm, cosign, kubesec, kube-bench, falco)
- Agent: `$AGENT_IP` — falco installed
- Calico CNI running
- Node addresses / SSH user: `. ./nodes.env` (gitignored — see `nodes.env.example`)
- SSH access: `ssh $SSH_USER@$MASTER_IP`
- Run cluster commands via: `ssh $SSH_USER@$MASTER_IP 'sudo bash -s' <<'EOF' ... EOF`

---

## Feb 26 — Time Blocks

### Lunch 12:30–13:00 (~30min)
- [x] **LAB-16** — API Server Hardening (`labs/LAB_16_api_server_hardening.md`)
  - Short lab, high value — anonymous auth, admission plugins, kubelet config
  - If it runs over time, stop and finish in the evening

### Evening 17:20–23:00 (~5h40)

- [x] **LAB-05** — Secrets + etcd encryption (`labs/LAB_05_secrets_etcd_encryption.md`)
  - Priority 1 — almost always on the exam
  - Involves editing kube-apiserver static pod manifest — fiddly, allow 75min
  - Est: 17:20–18:35

- [x] **LAB-08** — Audit Logging (`labs/LAB_08_audit_logging.md`)
  - Priority 2 — high exam frequency
  - Also involves kube-apiserver manifest edit
  - Est: 18:35–19:35

- [x] **LAB-04** — Pod Security Standards (`labs/LAB_04_pod_security_standards.md`)
  - Priority 3 — namespace labels, enforce/warn/audit modes
  - Est: 19:35–20:20

- [x] **LAB-06** — AppArmor (`labs/LAB_06_apparmor.md`)
  - Priority 4 — profile loading, pod annotation
  - Est: 20:20–21:20

- [x] **LAB-07** — Seccomp (`labs/LAB_07_seccomp.md`)
  - Priority 5 — RuntimeDefault + custom profiles
  - Est: 21:20–22:05

- [ ] **LAB-15** — Immutable Containers (`labs/LAB_15_immutable_containers.md`)
  - Priority 1 (Next) — readOnlyRootFilesystem + emptyDir volumes
  - Est: 22:05–22:35 (or do immediately)

---

## Feb 27 — Batched Sprint Sessions (~4h 40min)

**Strategy: Power-run 7 remaining labs in 2 focused batch sessions. Supply chain labs done as workflow chain.**

### Session 1: Quick Wins (22:00–23:30, ~90min)

- [ ] **LAB-15** — Immutable Containers (`labs/LAB_15_immutable_containers.md`)
  - ⚡ **Fastest lab** — readOnlyRootFilesystem + emptyDir volumes
  - Est: 22:00–22:30 (30min)

- [ ] **LAB-11** — CIS Benchmark kube-bench (`labs/LAB_11_cis_benchmark.md`)
  - Procedural (run → read → fix) — high exam ROI
  - Est: 22:30–23:15 (45min)

- [ ] **LAB-12** — Ingress with TLS (`labs/LAB_12_ingress_tls.md`)
  - TLS certs + nginx Ingress — 15% weight, critical path
  - Est: 23:15–00:15 (60min, may run into night)

**Session 1 Total: 90–120min**

---

### Session 2: Supply Chain Workflow Chain (00:15–02:40, ~145min)

**Do these three back-to-back as ONE production workflow: Scan → Fix → Sign**

- [ ] **LAB-10** — Trivy Image Scanning (`labs/LAB_10_trivy_image_scanning.md`)
  - Phase 1: Scan images for CVEs, compare base images
  - Est: 00:15–01:00 (45min)

- [ ] **LAB-14** — Static Analysis kubesec (`labs/LAB_14_static_analysis.md`)
  - Phase 2: Fix manifests (kubesec scores → harden pods)
  - Est: 01:00–01:45 (45min)

- [ ] **LAB-13** — Image signing cosign (`labs/LAB_13_image_signing_cosign.md`)
  - Phase 3: Sign the fixed images, verify supply chain
  - Est: 01:45–02:40 (55min)

**Session 2 Total: 145min (2h 25min)**

**Rationale:** These three labs form a real supply chain workflow. Doing them sequentially means concepts stick — Trivy findings → kubesec fixes → cosign signs the result.

---

### Optional (Skip unless ahead of schedule)

- [ ] **LAB-09** — Falco Runtime Security (`labs/LAB_09_falco.md`)
  - DEPRIORITIZED — You already own syscall monitoring / threat detection (CTF edge)
  - Only if time permits after Session 2 finishes early
  - Est: 75min (skip for exam prep)

---

## Feb 28 — Exam Day

- 06:00–08:00 — Rest (sleep if possible)
- 08:00–09:30 — **Cheatsheet review ONLY** (`PLAN.md` quick reference section)
  - Key file paths: `/etc/kubernetes/manifests/`, `/var/lib/kubelet/`, `/etc/apparmor.d/`
  - Command cheatsheet: `kubectl auth can-i`, `etcdctl`, `openssl req`, `cosign verify`, `trivy image`
  - **No new labs. No deep dives.**
- 09:30 — Stop. Rest. Do not open labs.
- 10:00 — **Exam** — 2 hours, ~15-20 questions

---

## Instructions for Running Batch Sessions

### Before Each Session
1. Load the `cks-lab` skill at the start of EACH LAB
2. Verify cluster health: `kubectl get nodes` (both Ready, calico Running)
3. Check `app-roadmap/data.json` for current skill levels

### During Each Lab
1. **Guide interactively** — hints first, solutions only if explicitly asked
2. **Watch for typo patterns** — namespace names, resource names, AND/OR YAML traps
3. **Call out mistakes immediately** — student is fast but pressure-prone
4. **Time-box ruthlessly** — if lab runs over 10% of estimate, move to next (finish later if needed)

### After Each Lab
1. Update `SESSION_PLAN.md` — check off completed todos (edit file, replace `[ ]` with `[x]`)
2. Update `app-roadmap/data.json` (status: "done", score, notes, skill levels, XP)
3. Clean up cluster resources before starting the next lab

### Batch Session Rules
- **Session 1:** Do LAB-15 → LAB-11 → LAB-12 **sequentially** (no breaks, momentum matters)
- **Session 2 (Supply Chain):** Do LAB-10 → LAB-14 → LAB-13 **back-to-back without long breaks**
  - These three form a workflow: Trivy output feeds into kubesec fixes, which feeds into cosign signing
  - Switching contexts will break the conceptual chain — keep going
- If student finishes a lab fast, use remaining time for **quick kata repeat** (e.g., re-run validation tests), not new material

### Red Flags
- If any lab hits 120% of estimate, **stop and move to next** — come back later if time
- If cluster breaks during a lab, check `/var/log/pods` or crictl logs, but don't waste >15min debugging
- If student is making typos under time pressure, call them out **immediately** (namespace mismatches, resource name typos)
