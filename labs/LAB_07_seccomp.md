# LAB-07 — Seccomp Profiles for Containers

**CKS Domain:** System Hardening (10%)

## Objective
Apply built-in and custom seccomp profiles to pods to restrict the Linux system calls (syscalls) a container can make.

## Background
Seccomp (Secure Computing Mode) is a Linux kernel feature that filters syscalls. If a container tries a blocked syscall, it gets `EPERM` or is killed.

**K8s seccomp profile types:**
- `RuntimeDefault`: Container runtime's built-in default profile (safe, recommended)
- `Localhost`: Custom JSON profile at `/var/lib/kubelet/seccomp/` on the node
- `Unconfined`: No filtering (dangerous — avoid)

The seccomp directory `/var/lib/kubelet/seccomp/` is **empty** on this cluster.

## Tasks

### Part A — RuntimeDefault profile (easiest)

1. Deploy a pod with RuntimeDefault seccomp:
   ```yaml
   # seccomp-runtime-pod.yaml
   apiVersion: v1
   kind: Pod
   metadata:
     name: seccomp-runtime
   spec:
     securityContext:
       seccompProfile:
         type: RuntimeDefault
     containers:
     - name: app
       image: alpine:3.19
       command: ["sleep", "3600"]
   ```
   ```bash
   kubectl apply -f seccomp-runtime-pod.yaml
   kubectl get pod seccomp-runtime
   ```

2. Verify it's running normally:
   ```bash
   kubectl exec seccomp-runtime -- ls /tmp
   kubectl exec seccomp-runtime -- cat /etc/hostname
   ```

### Part B — Custom localhost profile: deny chmod

3. Create the seccomp directory on the worker node:
   ```bash
   ssh $AGENT_IP "sudo mkdir -p /var/lib/kubelet/seccomp"
   ```

4. Create a profile blocking chmod/chown:
   ```bash
   ssh $AGENT_IP "sudo tee /var/lib/kubelet/seccomp/deny-chmod.json << 'EOF'
   {
     \"defaultAction\": \"SCMP_ACT_ALLOW\",
     \"syscalls\": [
       {
         \"names\": [\"chmod\", \"fchmod\", \"fchmodat\", \"chown\", \"lchown\", \"fchown\"],
         \"action\": \"SCMP_ACT_ERRNO\"
       }
     ]
   }
   EOF"
   ```

5. Verify the profile is in place:
   ```bash
   ssh $AGENT_IP "cat /var/lib/kubelet/seccomp/deny-chmod.json"
   ```

6. Deploy a pod using the localhost profile (force to worker node):
   ```yaml
   # seccomp-custom-pod.yaml
   apiVersion: v1
   kind: Pod
   metadata:
     name: seccomp-custom
   spec:
     nodeName: k8s-agent
     securityContext:
       seccompProfile:
         type: Localhost
         localhostProfile: deny-chmod.json
     containers:
     - name: app
       image: alpine:3.19
       command: ["sleep", "3600"]
   ```
   ```bash
   kubectl apply -f seccomp-custom-pod.yaml
   kubectl get pod seccomp-custom
   ```

7. Test: chmod should be blocked:
   ```bash
   kubectl exec seccomp-custom -- chmod 777 /etc/hostname
   ```
   Expected: `chmod: /etc/hostname: Operation not permitted`

8. Test: regular operations work:
   ```bash
   kubectl exec seccomp-custom -- ls /tmp
   kubectl exec seccomp-custom -- cat /etc/hostname
   ```

### Part C — Subdirectory organization

9. Profiles can be organized in subdirectories:
   ```bash
   ssh $AGENT_IP "sudo mkdir -p /var/lib/kubelet/seccomp/profiles"
   ssh $AGENT_IP "sudo cp /var/lib/kubelet/seccomp/deny-chmod.json /var/lib/kubelet/seccomp/profiles/"
   ```

10. Reference in pod spec:
    ```yaml
    securityContext:
      seccompProfile:
        type: Localhost
        localhostProfile: profiles/deny-chmod.json
    ```

### Part D — Audit profile (discover what syscalls an app uses)

11. Create an audit profile (log all syscalls, don't block):
    ```bash
    ssh $AGENT_IP "sudo tee /var/lib/kubelet/seccomp/audit-all.json << 'EOF'
    {
      \"defaultAction\": \"SCMP_ACT_LOG\"
    }
    EOF"
    ```

12. Deploy with the audit profile:
    ```yaml
    # seccomp-audit-pod.yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: seccomp-audit
    spec:
      nodeName: k8s-agent
      securityContext:
        seccompProfile:
          type: Localhost
          localhostProfile: audit-all.json
      containers:
      - name: app
        image: alpine:3.19
        command: ["sleep", "3600"]
    ```
    ```bash
    kubectl apply -f seccomp-audit-pod.yaml
    ```

13. Watch syscall logs:
    ```bash
    ssh $AGENT_IP "sudo journalctl -k | grep 'type=SECCOMP' | tail -20"
    ```

### Part E — Enable RuntimeDefault cluster-wide

14. Add `seccompDefault: true` to kubelet config on both nodes:
    ```bash
    # On master
    sudo grep -q "seccompDefault" /var/lib/kubelet/config.yaml || \
      echo "seccompDefault: true" | sudo tee -a /var/lib/kubelet/config.yaml
    sudo systemctl restart kubelet

    # On worker
    ssh $AGENT_IP "sudo grep -q seccompDefault /var/lib/kubelet/config.yaml || \
      echo 'seccompDefault: true' | sudo tee -a /var/lib/kubelet/config.yaml && \
      sudo systemctl restart kubelet"
    ```

## Validation
```bash
# RuntimeDefault pod running
kubectl get pod seccomp-runtime  # Running

# Custom profile blocks chmod
kubectl exec seccomp-custom -- chmod 777 /etc/hostname  # Operation not permitted

# Normal operations work
kubectl exec seccomp-custom -- ls /  # Works

# Profile exists on node
ssh $AGENT_IP "ls /var/lib/kubelet/seccomp/"
```

## Exam Tips
- Custom seccomp profiles MUST be on the **node** at `/var/lib/kubelet/seccomp/`.
- Subdirectories supported: `profiles/deny-chmod.json` → `localhostProfile: profiles/deny-chmod.json`.
- `RuntimeDefault` is safe for almost all workloads — prefer it over `Unconfined`.
- Profile format: `{"defaultAction": "SCMP_ACT_ALLOW", "syscalls": [{"names": ["chmod"], "action": "SCMP_ACT_ERRNO"}]}`
- Actions: `SCMP_ACT_ALLOW`, `SCMP_ACT_ERRNO` (return error), `SCMP_ACT_KILL`, `SCMP_ACT_LOG`.
- `seccompProfile` can be at pod-level OR container-level securityContext.
- In exam: SSH to the worker node, create the JSON file, then write the pod spec.
