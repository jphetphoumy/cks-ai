# LAB-00 — Install Calico CNI

## Objective
Install Calico CNI on the cluster to make both nodes Ready and enable NetworkPolicy support.

## Background
The cluster has two nodes (k8s-master and k8s-agent) but no CNI plugin is installed. Without CNI, all pods are stuck Pending and nodes show NotReady. Calico provides both networking and NetworkPolicy enforcement, making it the ideal choice for CKS labs.

## Tasks

1. Verify current cluster state:
   ```bash
   kubectl get nodes
   kubectl get pods -A
   ```
   Expected: nodes NotReady, CoreDNS pods Pending.

2. Apply Calico manifest:
   ```bash
   kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/calico.yaml
   ```

3. Watch Calico pods come up:
   ```bash
   watch kubectl get pods -n kube-system -l k8s-app=calico-node
   ```
   Wait until both calico-node pods are Running (1/1).

4. Verify nodes are Ready:
   ```bash
   kubectl get nodes -w
   ```
   Both k8s-master and k8s-agent should become Ready within 1-2 minutes.

5. Verify CoreDNS is Running:
   ```bash
   kubectl get pods -n kube-system | grep coredns
   ```

6. Run a connectivity test:
   ```bash
   kubectl run test --image=busybox:1.36 --restart=Never -- sleep 3600
   kubectl exec test -- wget -qO- http://kubernetes.default.svc
   kubectl delete pod test
   ```

7. Verify NetworkPolicy support is active by checking calico-node logs:
   ```bash
   kubectl logs -n kube-system -l k8s-app=calico-node --tail=20
   ```

## Validation
- `kubectl get nodes` shows both nodes Ready
- `kubectl get pods -A` shows all kube-system pods Running
- Pod connectivity test succeeds

## Exam Tips
- In the CKS exam, CNI is already installed — this lab is for your environment setup only.
- If calico-node pods are CrashLooping, check logs: `kubectl logs -n kube-system <calico-pod>`
- Common issue: CIDR mismatch. If kubeadm used a non-default pod CIDR, you may need to patch the calico ConfigMap.
- Calico supports NetworkPolicies natively — required for LAB-01.
