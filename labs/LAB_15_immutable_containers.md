# LAB-15 — Immutable Containers at Runtime

**CKS Domain:** Monitoring, Logging and Runtime Security (20%)

## Objective
Configure containers to be immutable at runtime using `readOnlyRootFilesystem` and understand how immutability limits post-exploitation.

## Background
An immutable container cannot modify its own filesystem. This prevents attackers from:
- Writing backdoors or malicious scripts
- Modifying binaries in place
- Installing additional tools (curl, wget, nc)
- Persisting changes between restarts

**Key field:** `spec.containers[].securityContext.readOnlyRootFilesystem: true`

## Tasks

### Part A — Demonstrate mutable container risk

1. Deploy a mutable container (default behavior):
   ```bash
   kubectl run mutable --image=nginx:alpine --restart=Never -- sleep 3600
   kubectl wait --for=condition=Ready pod/mutable
   ```

2. Show an attacker can write anywhere:
   ```bash
   kubectl exec mutable -- sh -c "echo 'malware' > /usr/bin/evil.sh && chmod +x /usr/bin/evil.sh"
   kubectl exec mutable -- cat /usr/bin/evil.sh
   ```
   The filesystem is writable — attacker can persist.

3. Clean up:
   ```bash
   kubectl delete pod mutable
   ```

### Part B — Immutable container basics

4. Create an immutable pod:
   ```yaml
   # immutable-pod.yaml
   apiVersion: v1
   kind: Pod
   metadata:
     name: immutable-pod
   spec:
     containers:
     - name: app
       image: nginx:alpine
       securityContext:
         readOnlyRootFilesystem: true
   ```
   ```bash
   kubectl apply -f immutable-pod.yaml
   kubectl get pod immutable-pod
   ```
   This may CrashLoopBackOff because nginx needs to write temp files.

5. Fix: add emptyDir volumes for writable paths nginx needs:
   ```yaml
   # immutable-nginx-pod.yaml
   apiVersion: v1
   kind: Pod
   metadata:
     name: immutable-nginx
   spec:
     containers:
     - name: app
       image: nginx:alpine
       securityContext:
         readOnlyRootFilesystem: true
       volumeMounts:
       - name: nginx-cache
         mountPath: /var/cache/nginx
       - name: nginx-run
         mountPath: /var/run
       - name: nginx-tmp
         mountPath: /tmp
     volumes:
     - name: nginx-cache
       emptyDir: {}
     - name: nginx-run
       emptyDir: {}
     - name: nginx-tmp
       emptyDir: {}
   ```
   ```bash
   kubectl apply -f immutable-nginx-pod.yaml
   kubectl get pod immutable-nginx  # Should be Running
   ```

6. Test immutability:
   ```bash
   # Write outside emptyDir — should fail
   kubectl exec immutable-nginx -- touch /usr/bin/evil  # Read-only file system
   kubectl exec immutable-nginx -- sh -c "echo bad > /etc/nginx/evil.conf"  # Read-only file system

   # Write to emptyDir — should work
   kubectl exec immutable-nginx -- touch /tmp/temp-file  # OK
   kubectl exec immutable-nginx -- touch /var/cache/nginx/temp  # OK
   ```

### Part C — Fully hardened immutable pod

7. Create a fully hardened pod:
   ```yaml
   # hardened-pod.yaml
   apiVersion: v1
   kind: Pod
   metadata:
     name: hardened-pod
   spec:
     securityContext:
       runAsNonRoot: true
       runAsUser: 1000
       runAsGroup: 3000
       seccompProfile:
         type: RuntimeDefault
     containers:
     - name: app
       image: alpine:3.19
       command: ["sleep", "3600"]
       securityContext:
         readOnlyRootFilesystem: true
         allowPrivilegeEscalation: false
         capabilities:
           drop: ["ALL"]
       volumeMounts:
       - name: tmp
         mountPath: /tmp
     volumes:
     - name: tmp
       emptyDir: {}
   ```
   ```bash
   kubectl apply -f hardened-pod.yaml
   kubectl get pod hardened-pod
   ```

8. Verify all security properties:
   ```bash
   # Cannot write to root filesystem
   kubectl exec hardened-pod -- touch /etc/evil  # Read-only file system

   # Can write to emptyDir
   kubectl exec hardened-pod -- touch /tmp/ok

   # Running as non-root
   kubectl exec hardened-pod -- id  # uid=1000

   # Cannot escalate privileges
   kubectl exec hardened-pod -- sh -c "chmod u+s /bin/sh" 2>&1  # Permission denied
   ```

### Part D — Detect immutability violations with Falco

9. Falco can detect writes to container filesystems even without `readOnlyRootFilesystem`:
   ```bash
   kubectl run mutable2 --image=alpine:3.19 --restart=Never -- sleep 3600
   kubectl exec mutable2 -- touch /etc/evil-file

   # Check Falco for the alert
   sudo journalctl -u falco --since "1 minute ago" | grep "evil-file"
   kubectl delete pod mutable2
   ```

### Part E — Exam scenario: make a deployment immutable

10. Identify what paths an existing app writes to:
    ```bash
    kubectl run test-app --image=nginx:alpine --restart=Never -- sleep 3600
    kubectl wait --for=condition=Ready pod/test-app
    kubectl exec test-app -- find / -writable -not -path "*/proc/*" 2>/dev/null | head -20
    kubectl delete pod test-app
    ```

11. Patch an existing deployment to add immutability:
    ```bash
    kubectl patch deployment myapp -p '{
      "spec": {
        "template": {
          "spec": {
            "containers": [{
              "name": "myapp",
              "securityContext": {
                "readOnlyRootFilesystem": true
              }
            }],
            "volumes": [{
              "name": "tmp",
              "emptyDir": {}
            }]
          }
        }
      }
    }'
    ```

12. Verify the rollout:
    ```bash
    kubectl rollout status deployment/myapp
    kubectl exec deployment/myapp -- touch /usr/bin/evil  # Should fail
    ```

## Validation
```bash
# immutable-nginx is Running
kubectl get pod immutable-nginx  # Running

# Write to root FS fails
kubectl exec immutable-nginx -- touch /usr/bin/evil  # Read-only file system

# Write to emptyDir succeeds
kubectl exec immutable-nginx -- touch /tmp/ok  # OK

# hardened-pod runs as non-root
kubectl exec hardened-pod -- id | grep "uid=1000"
```

## Exam Tips
- `readOnlyRootFilesystem: true` is in `spec.containers[].securityContext` (not pod-level).
- Use `emptyDir: {}` volumes for paths the app needs to write to (`/tmp`, `/var/run`, `/var/cache`).
- Common writable paths for nginx: `/var/cache/nginx`, `/var/run`, `/tmp`.
- In exam: identify what paths an app writes to → add emptyDir for those → set readOnlyRootFilesystem.
- Combine with `allowPrivilegeEscalation: false` and `capabilities.drop: [ALL]` for full hardening.
- `readOnlyRootFilesystem` prevents writing backdoors, modifying binaries — major post-exploitation limiter.
