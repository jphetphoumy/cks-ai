---
name: kubectl-exec-debug
description: Diagnose and fix kubectl exec connection failures in Kubernetes clusters
disable-model-invocation: false
allowed-tools: Bash, AskUserQuestion, Read
---

# Goal

When `kubectl exec` fails with "unable to upgrade connection: Unauthorized", this skill diagnoses the root cause by checking kubelet authentication/authorization configuration, reports what's missing, and offers step-by-step fixes to restore exec functionality.

# Workflow

## 1. Gather cluster information

Ask the user:
- Which node should we check? (default: worker node IP or `k8s-agent`)
- What is the SSH username? (default: current user)
- What is the kubelet config path? (default: `/var/lib/kubelet/config.yaml`)

Store these as variables for the rest of the workflow.

Example bash to get this info:
```bash
read -p "Node IP or hostname (default k8s-agent): " NODE
NODE=${NODE:-k8s-agent}
read -p "SSH user (default $USER): " SSH_USER
SSH_USER=${SSH_USER:-$USER}
KUBELET_CONFIG="/var/lib/kubelet/config.yaml"
echo "Checking kubelet on: $NODE as $SSH_USER"
```

## 2. Fetch and display kubelet config

SSH to the node and retrieve the kubelet configuration:

```bash
ssh -o StrictHostKeyChecking=accept-new "$SSH_USER@$NODE" \
  "sudo cat /var/lib/kubelet/config.yaml" > /tmp/kubelet-config.yaml

echo "=== Current kubelet config on $NODE ==="
cat /tmp/kubelet-config.yaml
```

## 3. Run diagnostic checks

Check for required authentication/authorization settings:

```bash
echo "=== Diagnostic Checks ==="

# Check 1: x509 clientCAFile
if grep -q "clientCAFile:" /tmp/kubelet-config.yaml; then
  CERT=$(grep "clientCAFile:" /tmp/kubelet-config.yaml | awk '{print $NF}')
  echo "✓ x509.clientCAFile is configured: $CERT"
else
  echo "✗ MISSING: x509.clientCAFile (CRITICAL for kubectl exec)"
fi

# Check 2: Anonymous auth disabled
if grep -q "enabled: false" /tmp/kubelet-config.yaml | head -1; then
  echo "✓ anonymous.enabled = false"
else
  echo "⚠ MISSING: anonymous.enabled should be false"
fi

# Check 3: Webhook authentication
if grep -q "webhook:" /tmp/kubelet-config.yaml; then
  echo "✓ webhook authentication is configured"
else
  echo "⚠ MISSING: webhook authentication (recommended but not critical)"
fi

# Check 4: Authorization mode
if grep -q "mode: Webhook" /tmp/kubelet-config.yaml; then
  echo "✓ authorization.mode = Webhook"
else
  echo "⚠ MISSING: authorization.mode should be Webhook"
fi

echo ""
echo "=== Summary ==="
if ! grep -q "clientCAFile:" /tmp/kubelet-config.yaml; then
  echo "ROOT CAUSE: Missing x509.clientCAFile in kubelet config"
  echo "This prevents kubelet from trusting client certs from the API server."
  echo "kubectl exec will fail with 'Unauthorized' until this is added."
fi
```

## 4. Test kubectl exec (optional)

Ask the user if they want to test kubectl exec against a pod:

```bash
read -p "Test kubectl exec? (y/n): " TEST
if [[ $TEST == "y" ]]; then
  read -p "Pod name (default: test): " POD_NAME
  POD_NAME=${POD_NAME:-test}
  echo "Testing: kubectl exec $POD_NAME -- id"
  kubectl exec "$POD_NAME" -- id 2>&1 && echo "✓ kubectl exec works!" || echo "✗ kubectl exec still failing"
fi
```

## 5. Offer guided fixes

Present a checklist of fixes to the user:

```bash
cat << 'FIXES'

=== Guided Fixes (copy/paste for worker node) ===

To fix kubectl exec, the worker node kubelet.config.yaml needs:

1. COPY THIS COMPLETE CONFIG:

sudo cat > /var/lib/kubelet/config.yaml <<'CONFIG'
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: systemd
staticPodPath: /etc/kubernetes/manifests
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
    cacheTTL: 2m0s
  x509:
    clientCAFile: /etc/kubernetes/pki/ca.crt
authorization:
  mode: Webhook
  webhook:
    cacheAuthorizedTTL: 5m0s
    cacheUnauthorizedTTL: 30s
CONFIG

2. RESTART KUBELET:

sudo systemctl restart kubelet
sleep 5

3. VERIFY:

kubectl get nodes  # should show all nodes Ready

FIXES

echo ""
read -p "Apply fixes now? (y/n): " APPLY
if [[ $APPLY == "y" ]]; then
  echo "Instructions:"
  echo "1. SSH to $NODE as $SSH_USER"
  echo "2. Copy and paste the config from above"
  echo "3. Run: sudo systemctl restart kubelet"
  echo "4. Wait 5 seconds, then run: kubectl get nodes"
  echo "5. Test: kubectl exec <pod> -- id"
fi
```

## 6. Verification and next steps

Show the user the final status:

```bash
echo ""
echo "=== Next Steps ==="
echo "1. If kubectl exec works, the fix is complete."
echo "2. If still failing, run this skill again to re-check the config."
echo "3. Common issues:"
echo "   - Node not Ready: wait for kubelet to restart"
echo "   - Still 'Unauthorized': verify /etc/kubernetes/pki/ca.crt exists on worker"
echo "   - DNS issues: check if the node can reach the API server"
echo ""
echo "For deeper debugging, check kubelet logs:"
echo "  ssh $SSH_USER@$NODE 'sudo journalctl -u kubelet -n 50 | grep -i auth'"
```

---

## Implementation notes

This skill is designed to be **minimal and iterable**. Future enhancements could include:

- **Subskill for automated fixes**: `kubectl-exec-debug-apply` that SSHes and applies config changes
- **Subskill for kubelet logs**: `kubectl-exec-debug-logs` that tails kubelet journal for errors
- **Subskill for multi-node check**: check all worker nodes at once
- **Integration with cks-setup**: coordinate with existing lab setup skills

Start with manual copy/paste fixes, then add automation as needed.
