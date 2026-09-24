# CKS Learning — AI-Driven Kata Track

> Intensive 3-day Kubernetes Security (CKS) certification study plan with interactive labs and runtime validation.

## About

This repository contains a structured learning path for the **Certified Kubernetes Security (CKS)** exam, designed for engineers with CKA experience who need to master CKS in 3 days.

**Learning Model:** Kata-style labs — repeat each one multiple times until commands become muscle memory.

## Structure

- **PLAN.md** — Complete 3-day learning roadmap with lab sequence and muscle memory targets
- **AGENTS.md** — Learning framework and coaching approach
- **labs/** — 16 hands-on security labs covering all CKS domains
- **app-roadmap/** — Progress tracking and roadmap completion status

## Domains Covered

- **Cluster Setup (15%)** — NetworkPolicies, CIS benchmarks, Ingress TLS
- **Cluster Hardening (15%)** — RBAC, ServiceAccounts, API server security
- **System Hardening (10%)** — AppArmor, Seccomp, kernel hardening
- **Minimize Microservice Vulnerabilities (20%)** — Pod Security Standards, secrets encryption, immutable containers
- **Supply Chain Security (20%)** — Image scanning (Trivy), signing (cosign), static analysis (kubesec)
- **Monitoring & Runtime Security (20%)** — Falco rules, audit logging, threat detection

## Quick Start

1. Follow **PLAN.md** for the day-by-day schedule
2. Work through labs in **labs/** sequentially
3. Use the skill commands (e.g., `cks-lab`, `cks-validate`) for interactive guidance
4. Track progress in **ROADMAP.md**

## Node Configuration

Nothing in this repo hardcodes real node addresses. The labs, skills and `setup.sh` all
refer to `$MASTER_IP`, `$AGENT_IP` and `$SSH_USER`, which come from a **gitignored**
`nodes.env` at the repo root:

```bash
cp nodes.env.example nodes.env
$EDITOR nodes.env       # set MASTER_IP, AGENT_IP, SSH_USER
. ./nodes.env           # source it before running lab commands by hand
```

`nodes.env.example` is tracked and carries placeholders (`10.0.0.10` / `10.0.0.11`).
`.claude/skills/cks-setup/setup.sh` sources `nodes.env` automatically and fails fast
with a clear message if it is missing. Keep your real addresses, hostnames and SSH user
in `nodes.env` only — never in a tracked file.

## Claude Code Setup

The `.claude/skills/` and `.claude/commands/` directories **are** tracked in git — they provide the interactive tutor (`cks-lab`, `cks-validate`, `cks-complete`, `cks-exam`, `cks-setup`, …).

`.claude/settings.local.json` is **not** tracked — it holds machine-local permission grants (SSH to the lab nodes, skill invocations). Create your own after cloning:

```json
{
  "permissions": {
    "allow": [
      "Bash(ssh -o StrictHostKeyChecking=no 10.0.0.10:*)",
      "Bash(ssh -o StrictHostKeyChecking=no 10.0.0.11:*)",
      "Skill(cks-setup)",
      "Skill(cks-lab)",
      "Skill(cks-validate)",
      "Skill(cks-complete)",
      "Skill(cks-exam)",
      "Skill(kubectl-exec-debug)"
    ]
  }
}
```

Replace `10.0.0.10` / `10.0.0.11` with the addresses you put in `nodes.env`. Bash allow-rules are **prefix matches** against the literal command string — they cannot read `$MASTER_IP`, so the real addresses go here, in this local, untracked file. Pin them to those two VMs. Avoid a blanket `Bash(ssh:*)` — the labs run `sudo` on the far end, so that rule is standing approval to run anything as root on *any* host you can reach, not just the throwaway lab nodes. Match the exact command form the skills use (including the flags before the host) or the rule won't fire; add a second line for a bare `ssh <node-ip>:*` form if you also use it.

Without this file, Claude Code just prompts for approval on each SSH command and skill invocation — it only saves you the clicks. Keep it out of git: it is environment-specific (lab IPs) and ignored via `*.local.json`.

## Requirements

- Kubernetes cluster (2 nodes: k8s-master, k8s-agent)
- Calico CNI installed
- Tools: kube-bench, Trivy, Falco, cosign, kubesec, Helm
- Labs expect sudo access on cluster nodes

## Exam Tips

- Docs allowed: kubernetes.io, falco.org, aquasecurity.github.io
- Time: 2 hours, ~15-20 questions
- Focus: High-weight domains first (Vulnerabilities, Supply Chain, Monitoring)
- Your edge: CTF/webapp hacking background → think like attackers, defend accordingly

---

**Status:** Work in progress | Last updated: March 2026
