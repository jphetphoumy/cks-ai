---
name: cks-setup
description: Check and set up the CKS lab environment — kubeconfig, cluster tools (trivy, helm, cosign, kubesec, falco, kube-bench) on master and agent nodes.
disable-model-invocation: false
allowed-tools: Bash, AskUserQuestion
---

# Goal

Verify the CKS lab environment is ready to use. Check the state of the cluster nodes and installed tools, then offer to run the full setup if anything is missing.

# Workflow

## 1. Check current state

Run the following checks and collect the results:

**Local kubeconfig:**
```bash
nix shell nixpkgs#kubectl -c kubectl get nodes --request-timeout=5s 2>&1
```

**Tools on master ($MASTER_IP):**
```bash
ssh $SSH_USER@$MASTER_IP 'sudo bash -s' <<'EOF'
for bin in kube-bench trivy helm cosign kubesec; do
  version=$(which $bin >/dev/null 2>&1 && $bin version 2>/dev/null | head -1 || echo "NOT INSTALLED")
  printf "%-12s %s\n" "$bin" "$version"
done
printf "%-12s %s\n" "falco" "$(systemctl is-active falco-modern-bpf.service 2>/dev/null || echo inactive)"
EOF
```

**Falco on agent ($AGENT_IP):**
```bash
ssh $SSH_USER@$AGENT_IP 'sudo systemctl is-active falco-modern-bpf.service 2>/dev/null || echo inactive'
```

## 2. Display results

Show the user a clear status table with what is installed and what is missing. Mark each item as ✅ installed or ⬜ missing.

## 3. Ask the user what to do

Use the AskUserQuestion tool to ask:

> "Some tools are missing / Everything looks good — what would you like to do?"

Offer these options:
- **Full setup** — run setup.sh (kubeconfig + all tools)
- **Tools only** — run setup.sh --tools (skip kubeconfig refresh)
- **Kubeconfig only** — run setup.sh --kubeconfig
- **Nothing** — exit, cluster is ready

If everything is already installed and the cluster is reachable, still ask — the user may want to re-run to refresh.

## 4. Run setup if requested

If the user selects any setup option, run the script located next to this file:

```bash
SKILL_DIR="$(dirname "$0")"  # same directory as SKILL.md
bash "$SKILL_DIR/setup.sh" [--tools|--kubeconfig]   # no flag = full setup
```

Stream output to the user so they can follow progress.

## 5. Final verification

After setup completes (or if the user chose nothing), run the state check again and print the final status table so the user knows the environment is ready.
