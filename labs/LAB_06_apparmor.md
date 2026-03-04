# LAB-06 — AppArmor Profiles for Containers

**CKS Domain:** System Hardening (10%)

## Objective
Write a custom AppArmor profile, load it on the node, and enforce it on a Kubernetes pod container.

## Background
AppArmor is a Linux Mandatory Access Control (MAC) system. It restricts what a process can do: file reads/writes, network access, capabilities. In Kubernetes, AppArmor profiles are applied per-container.

**K8s 1.30+ syntax:** `securityContext.appArmorProfile` (container-level)
**Pre-1.30 syntax:** annotation `container.apparmor.security.beta.kubernetes.io/<container>: localhost/<profile-name>`

**Critical:** AppArmor profiles must be loaded on the **node where the pod runs**.

## Tasks

### Part A — Inspect current AppArmor state

1. Check loaded profiles on master:
   ```bash
   sudo aa-status
   ```

2. Check on worker node:
   ```bash
   ssh 192.168.1.41 "sudo aa-status"
   ```

3. Look at an existing profile for syntax reference:
   ```bash
   cat /etc/apparmor.d/usr.bin.tcpdump
   ```

### Part B — Write a custom deny-write profile

4. Create the profile on the **worker node (192.168.1.41)**:
   ```bash
   ssh 192.168.1.41 "sudo tee /etc/apparmor.d/k8s-deny-write << 'EOF'
   #include <tunables/global>

   profile k8s-deny-write flags=(attach_disconnected) {
     #include <abstractions/base>

     # Allow reads everywhere
     /** r,

     # Deny all writes
     deny /** w,
     deny /** wl,

     # Allow process execution
     /usr/bin/** ix,
     /bin/** ix,

     # Deny raw sockets
     deny network raw,
   }
   EOF"
   ```

5. Load the profile on the worker node:
   ```bash
   ssh 192.168.1.41 "sudo apparmor_parser -r /etc/apparmor.d/k8s-deny-write"
   ```

6. Verify it's in enforce mode:
   ```bash
   ssh 192.168.1.41 "sudo aa-status | grep k8s-deny-write"
   ```

### Part C — Apply profile to pod (K8s 1.30+ syntax)

7. Deploy a pod using the AppArmor profile on the worker node:
   ```yaml
   # apparmor-pod.yaml
   apiVersion: v1
   kind: Pod
   metadata:
     name: apparmor-pod
   spec:
     nodeName: k8s-agent
     containers:
     - name: app
       image: alpine:3.19
       command: ["sleep", "3600"]
       securityContext:
         appArmorProfile:
           type: Localhost
           localhostProfile: k8s-deny-write
   ```
   ```bash
   kubectl apply -f apparmor-pod.yaml
   kubectl get pod apparmor-pod
   ```

8. Test: writing a file should be denied:
   ```bash
   kubectl exec apparmor-pod -- touch /tmp/testfile
   ```
   Expected: `touch: /tmp/testfile: Permission denied`

9. Test: reading a file should work:
   ```bash
   kubectl exec apparmor-pod -- cat /etc/hostname
   ```
   Expected: hostname printed.

### Part D — Pre-1.30 annotation syntax

10. The annotation syntax still works in K8s 1.35:
    ```yaml
    # apparmor-annotation-pod.yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: apparmor-annotation-pod
      annotations:
        container.apparmor.security.beta.kubernetes.io/app: localhost/k8s-deny-write
    spec:
      nodeName: k8s-agent
      containers:
      - name: app
        image: alpine:3.19
        command: ["sleep", "3600"]
    ```
    ```bash
    kubectl apply -f apparmor-annotation-pod.yaml
    kubectl exec apparmor-annotation-pod -- touch /tmp/test  # Permission denied
    ```

### Part E — Complain mode (testing/auditing)

11. Switch to complain mode (logs but doesn't block):
    ```bash
    ssh 192.168.1.41 "sudo aa-complain /etc/apparmor.d/k8s-deny-write"
    ssh 192.168.1.41 "sudo aa-status | grep -A1 complain"
    ```

12. Switch back to enforce:
    ```bash
    ssh 192.168.1.41 "sudo aa-enforce /etc/apparmor.d/k8s-deny-write"
    ```

### Part F — Exam scenario: realistic profile

13. Write a profile allowing only reads from `/data/`, denying writes and raw sockets:
    ```bash
    ssh 192.168.1.41 "sudo tee /etc/apparmor.d/k8s-data-reader << 'EOF'
    #include <tunables/global>

    profile k8s-data-reader flags=(attach_disconnected) {
      #include <abstractions/base>

      /data/** r,
      deny /** w,
      deny /proc/sys/kernel/** rw,
      deny network raw,
      /usr/bin/** ix,
      /bin/** ix,
      /lib/** mr,
    }
    EOF"
    ssh 192.168.1.41 "sudo apparmor_parser -r /etc/apparmor.d/k8s-data-reader"
    ssh 192.168.1.41 "sudo aa-status | grep k8s-data-reader"
    ```

## Validation
```bash
# Profile loaded on worker node
ssh 192.168.1.41 "sudo aa-status | grep k8s-deny-write"  # enforce mode

# Pod running
kubectl get pod apparmor-pod  # Running

# Write blocked
kubectl exec apparmor-pod -- touch /tmp/test  # Permission denied

# Read allowed
kubectl exec apparmor-pod -- cat /etc/hostname  # OK
```

## Exam Tips
- **Profile MUST be loaded on the NODE where the pod runs** — SSH to the worker node first.
- Profile name in K8s must match the `profile` block name in the file.
- K8s 1.30+ uses `securityContext.appArmorProfile` — but annotation syntax still works in 1.35.
- `sudo apparmor_parser -r <file>` loads/reloads a profile into the kernel.
- `sudo aa-status` — verify profile is in enforce mode.
- `sudo aa-enforce <file>` — enforce mode; `sudo aa-complain <file>` — complain mode.
- Common mistake: loading profile on master but pod runs on worker node.
