# LAB-04 — Pod Security Standards (PSA)

**CKS Domain:** Minimize Microservice Vulnerabilities (20%)

## Objective
Apply Pod Security Admission (PSA) labels to namespaces. Understand the three levels (privileged/baseline/restricted) and three modes (enforce/warn/audit).

## Background
PodSecurityPolicy (PSP) was removed in K8s 1.25. Its replacement is **Pod Security Admission (PSA)**, a built-in admission controller. PSA operates at the namespace level via labels.

**Three levels:**
- `privileged`: No restrictions
- `baseline`: Minimal restrictions (prevents most privilege escalation)
- `restricted`: Hardened (no root, drop capabilities, seccomp required)

**Three modes:**
- `enforce`: Block non-compliant pods
- `warn`: Allow but show warning
- `audit`: Allow but log to audit log

**Label format:** `pod-security.kubernetes.io/<mode>=<level>`

## Tasks

### Part A — Explore warn mode

1. Create a test namespace:
   ```bash
   kubectl create namespace psa-test
   ```

2. Apply warn mode for restricted level:
   ```bash
   kubectl label namespace psa-test pod-security.kubernetes.io/warn=restricted
   ```

3. Try to deploy a privileged pod — see the warning:
   ```yaml
   # privileged-pod.yaml
   apiVersion: v1
   kind: Pod
   metadata:
     name: privileged-pod
     namespace: psa-test
   spec:
     containers:
     - name: app
       image: alpine:3.19
       command: ["sleep", "3600"]
       securityContext:
         privileged: true
   ```
   ```bash
   kubectl apply -f privileged-pod.yaml
   ```
   Observe the warning. Pod is still created.

4. Delete it:
   ```bash
   kubectl delete pod privileged-pod -n psa-test
   ```

### Part B — Enforce mode

5. Switch to enforce restricted:
   ```bash
   kubectl label namespace psa-test \
     pod-security.kubernetes.io/enforce=restricted --overwrite
   ```

6. Try privileged pod again — should be REJECTED:
   ```bash
   kubectl apply -f privileged-pod.yaml
   ```
   Expected: Error — pod is rejected.

7. Try root pod — also rejected:
   ```yaml
   # root-pod.yaml
   apiVersion: v1
   kind: Pod
   metadata:
     name: root-pod
     namespace: psa-test
   spec:
     containers:
     - name: app
       image: alpine:3.19
       command: ["sleep", "3600"]
       securityContext:
         runAsUser: 0
   ```
   ```bash
   kubectl apply -f root-pod.yaml
   ```
   Expected: Rejected (restricted forbids running as root).

### Part C — Create a compliant pod

8. Create a fully compliant pod for restricted level:
   ```yaml
   # compliant-pod.yaml
   apiVersion: v1
   kind: Pod
   metadata:
     name: compliant-pod
     namespace: psa-test
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
         allowPrivilegeEscalation: false
         readOnlyRootFilesystem: true
         capabilities:
           drop: ["ALL"]
   ```
   ```bash
   kubectl apply -f compliant-pod.yaml
   kubectl get pod compliant-pod -n psa-test
   ```
   Expected: Pod running.

### Part D — Audit mode on kube-system

9. Add audit mode on kube-system (safe — does not enforce):
   ```bash
   kubectl label namespace kube-system \
     pod-security.kubernetes.io/audit=restricted
   ```

10. Check PSA labels on all namespaces:
    ```bash
    kubectl get namespaces -o json | python3 -c "
    import json, sys
    data = json.load(sys.stdin)
    for ns in data['items']:
        labels = {k: v for k, v in ns['metadata'].get('labels', {}).items() if 'pod-security' in k}
        if labels:
            print(ns['metadata']['name'], labels)
    "
    ```

### Part E — Exam scenario: safe migration

11. A namespace has running privileged pods. Migrate safely:
    ```bash
    # Step 1: apply warn to discover violations
    kubectl label namespace psa-test pod-security.kubernetes.io/warn=baseline --overwrite

    # Step 2: dry-run existing pods to see warnings
    kubectl get pods -n psa-test -o yaml | kubectl apply --dry-run=server -f -

    # Step 3: fix violations, then enforce
    kubectl label namespace psa-test pod-security.kubernetes.io/enforce=baseline --overwrite
    ```

## Validation
```bash
# Privileged pod rejected in enforce mode
kubectl apply -f privileged-pod.yaml  # Error: violates PodSecurity

# Compliant pod accepted
kubectl get pod compliant-pod -n psa-test  # Running

# Check labels
kubectl get ns psa-test --show-labels
```

## Exam Tips
- Label syntax: `pod-security.kubernetes.io/<mode>=<level>`
- You can apply ALL three modes simultaneously on one namespace.
- **Restricted level requires:** `runAsNonRoot: true`, `allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]`, `seccompProfile: RuntimeDefault or Localhost`.
- **NEVER enforce restricted on kube-system** — will break system components.
- Use `warn` first to discover violations, then switch to `enforce`.
- PSA is enabled by default in K8s 1.23+ — no installation needed.
