# LAB-03 — ServiceAccount Hardening

**CKS Domain:** Cluster Hardening (15%)

## Objective
Disable automounting of service account tokens, minimize SA permissions, and prevent pods from accessing the Kubernetes API by default.

## Background
By default, every pod gets a ServiceAccount token mounted at `/var/run/secrets/kubernetes.io/serviceaccount/token`. This token can be used to call the Kubernetes API from inside the pod — a major attack vector.

**Attack path:** Code execution in pod → read SA token → call kube-apiserver → enumerate/modify cluster resources.

## Tasks

### Part A — Demonstrate the attack surface

1. Deploy a default pod (uses default SA with automount):
   ```bash
   kubectl run demo --image=alpine:3.19 --restart=Never -- sleep 3600
   kubectl exec demo -- ls /var/run/secrets/kubernetes.io/serviceaccount/
   ```
   Expected: ca.crt, namespace, token

2. Use the token to call the API:
   ```bash
   kubectl exec demo -- sh -c '
   TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
   curl -sk -H "Authorization: Bearer $TOKEN" \
     https://kubernetes.default.svc/api/v1/namespaces
   '
   ```

3. Clean up:
   ```bash
   kubectl delete pod demo
   ```

### Part B — Disable automount at ServiceAccount level

4. Patch the default SA in the default namespace:
   ```bash
   kubectl patch serviceaccount default -n default \
     -p '{"automountServiceAccountToken": false}'
   ```

5. Deploy a pod — token should NOT be mounted:
   ```bash
   kubectl run no-token --image=alpine:3.19 --restart=Never -- sleep 3600
   kubectl exec no-token -- ls /var/run/secrets/kubernetes.io/serviceaccount/ 2>&1
   ```
   Expected: No such file or directory

6. Clean up and restore:
   ```bash
   kubectl delete pod no-token
   kubectl patch serviceaccount default -n default -p '{"automountServiceAccountToken": null}'
   ```

### Part C — Disable automount at Pod level

7. Create a pod with explicit `automountServiceAccountToken: false`:
   ```yaml
   # no-token-pod.yaml
   apiVersion: v1
   kind: Pod
   metadata:
     name: no-token-pod
   spec:
     automountServiceAccountToken: false
     containers:
     - name: app
       image: alpine:3.19
       command: ["sleep", "3600"]
   ```
   ```bash
   kubectl apply -f no-token-pod.yaml
   kubectl exec no-token-pod -- ls /var/run/secrets/ 2>&1
   ```

### Part D — Create a minimal SA for a specific workload

8. Create a namespace and a minimal SA:
   ```bash
   kubectl create namespace apps
   kubectl create serviceaccount metrics-reader -n apps
   ```

9. Grant only get/list on pods and endpoints:
   ```yaml
   # metrics-reader-role.yaml
   apiVersion: rbac.authorization.k8s.io/v1
   kind: Role
   metadata:
     name: metrics-reader
     namespace: apps
   rules:
   - apiGroups: [""]
     resources: ["pods", "endpoints"]
     verbs: ["get", "list"]
   ```
   ```bash
   kubectl apply -f metrics-reader-role.yaml
   kubectl create rolebinding metrics-reader-binding \
     --role=metrics-reader \
     --serviceaccount=apps:metrics-reader \
     -n apps
   ```

10. Disable automount on the SA:
    ```bash
    kubectl patch sa metrics-reader -n apps \
      -p '{"automountServiceAccountToken": false}'
    ```

### Part E — Short-lived tokens (TokenRequest API)

11. Generate a short-lived token:
    ```bash
    kubectl create token metrics-reader -n apps --duration=1h
    ```

12. Find legacy long-lived SA token secrets:
    ```bash
    kubectl get secrets -A --field-selector type=kubernetes.io/service-account-token
    ```

### Part F — Exam scenario: audit and fix

13. Find all pods that automount the default SA token:
    ```bash
    kubectl get pods -A -o json | python3 -c "
    import json, sys
    data = json.load(sys.stdin)
    for p in data['items']:
        spec = p['spec']
        automount = spec.get('automountServiceAccountToken', True)
        sa = spec.get('serviceAccountName', 'default')
        ns = p['metadata']['namespace']
        name = p['metadata']['name']
        if automount and sa == 'default':
            print(f'{ns}/{name} uses default SA with automount')
    "
    ```

14. Fix by patching the deployment:
    ```bash
    kubectl patch deployment <name> -n <ns> \
      -p '{"spec":{"template":{"spec":{"automountServiceAccountToken":false}}}}'
    ```

## Validation
```bash
# No token mounted in no-token-pod
kubectl exec no-token-pod -- ls /var/run/secrets/kubernetes.io/ 2>&1  # should fail

# metrics-reader SA has automount disabled
kubectl get sa metrics-reader -n apps -o jsonpath='{.automountServiceAccountToken}'  # false

# SA permissions are correct
kubectl auth can-i list pods --as=system:serviceaccount:apps:metrics-reader -n apps  # yes
kubectl auth can-i delete pods --as=system:serviceaccount:apps:metrics-reader -n apps  # no
```

## Exam Tips
- `automountServiceAccountToken: false` can be set on both SA and Pod spec — pod spec takes precedence.
- Always patch the **default SA** in every namespace you control.
- Short-lived tokens via `kubectl create token <sa>` are preferred over Secret-based tokens.
- In exam: find pods with unnecessary API access and disable it.
- Token path: `/var/run/secrets/kubernetes.io/serviceaccount/token`
- `kubectl auth can-i --list --as=system:serviceaccount:<ns>:<sa>` shows what a SA can do.
