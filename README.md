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
