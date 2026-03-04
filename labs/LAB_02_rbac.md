# LAB-02 — RBAC Least Privilege

**CKS Domain:** Cluster Hardening (15%)

## Objective
Master RBAC to enforce least-privilege access. Find over-privileged accounts, fix them, and create minimal-permission roles.

## Background
RBAC (Role-Based Access Control) is the primary authorization mechanism in Kubernetes. Key objects:
- **Role** / **ClusterRole**: Define permissions (rules: apiGroups, resources, verbs)
- **RoleBinding** / **ClusterRoleBinding**: Bind roles to subjects (users, groups, ServiceAccounts)
- **ClusterRole + ClusterRoleBinding** = cluster-wide permissions
- **ClusterRole + RoleBinding** = namespace-scoped permissions (despite ClusterRole name)

## Tasks

### Part A — Create least-privilege Role

1. Create a test namespace:
   ```bash
   kubectl create namespace rbac-test
   ```

2. Create a Role allowing only get/list/watch on pods:
   ```yaml
   # pod-reader-role.yaml
   apiVersion: rbac.authorization.k8s.io/v1
   kind: Role
   metadata:
     name: pod-reader
     namespace: rbac-test
   rules:
   - apiGroups: [""]
     resources: ["pods"]
     verbs: ["get", "list", "watch"]
   ```
   ```bash
   kubectl apply -f pod-reader-role.yaml
   ```

3. Create a ServiceAccount:
   ```bash
   kubectl create serviceaccount dev-sa -n rbac-test
   ```

4. Bind the Role to the ServiceAccount:
   ```bash
   kubectl create rolebinding dev-sa-binding \
     --role=pod-reader \
     --serviceaccount=rbac-test:dev-sa \
     -n rbac-test
   ```

5. Test — can list pods:
   ```bash
   kubectl auth can-i list pods --as=system:serviceaccount:rbac-test:dev-sa -n rbac-test
   ```
   Expected: yes

6. Test — cannot create pods:
   ```bash
   kubectl auth can-i create pods --as=system:serviceaccount:rbac-test:dev-sa -n rbac-test
   ```
   Expected: no

7. Test — cannot access secrets:
   ```bash
   kubectl auth can-i get secrets --as=system:serviceaccount:rbac-test:dev-sa -n rbac-test
   ```
   Expected: no

8. List ALL permissions for the SA:
   ```bash
   kubectl auth can-i --list --as=system:serviceaccount:rbac-test:dev-sa -n rbac-test
   ```

### Part B — Attack scenario: find cluster-admin bindings

9. Create a dangerous ClusterRoleBinding (simulate misconfiguration):
   ```bash
   kubectl create clusterrolebinding evil-binding \
     --clusterrole=cluster-admin \
     --serviceaccount=rbac-test:dev-sa
   ```

10. Find all subjects bound to cluster-admin:
    ```bash
    kubectl get clusterrolebindings -o json | python3 -c "
    import json, sys
    data = json.load(sys.stdin)
    for b in data['items']:
        if b['roleRef']['name'] == 'cluster-admin':
            print(b['metadata']['name'], '->', b.get('subjects', []))
    "
    ```

11. Fix: remove the dangerous binding:
    ```bash
    kubectl delete clusterrolebinding evil-binding
    ```

### Part C — Secret-reader Role (namespace-scoped)

12. Create a Role that ONLY allows reading secrets in rbac-test namespace:
    ```yaml
    # secret-reader-role.yaml
    apiVersion: rbac.authorization.k8s.io/v1
    kind: Role
    metadata:
      name: secret-reader
      namespace: rbac-test
    rules:
    - apiGroups: [""]
      resources: ["secrets"]
      verbs: ["get", "list"]
    ```
    ```bash
    kubectl apply -f secret-reader-role.yaml
    ```

13. Bind to a new SA and verify it cannot read secrets cluster-wide:
    ```bash
    kubectl create serviceaccount secret-sa -n rbac-test
    kubectl create rolebinding secret-sa-binding \
      --role=secret-reader \
      --serviceaccount=rbac-test:secret-sa \
      -n rbac-test

    # Can read secrets in rbac-test
    kubectl auth can-i get secrets --as=system:serviceaccount:rbac-test:secret-sa -n rbac-test
    # Cannot read secrets in default
    kubectl auth can-i get secrets --as=system:serviceaccount:rbac-test:secret-sa -n default
    ```

### Part D — Exam scenario: audit over-privileged accounts

14. Find all ClusterRoles with wildcard permissions:
    ```bash
    kubectl get clusterroles -o json | python3 -c "
    import json, sys
    data = json.load(sys.stdin)
    for r in data['items']:
        for rule in r.get('rules', []):
            if '*' in rule.get('verbs', []) or '*' in rule.get('resources', []):
                print('WILDCARD FOUND:', r['metadata']['name'], rule)
    "
    ```

15. Find who has what role in a namespace:
    ```bash
    kubectl get rolebindings -n rbac-test -o json | python3 -c "
    import json, sys
    data = json.load(sys.stdin)
    for b in data['items']:
        print(b['metadata']['name'], '->', b['roleRef']['name'], '->', b.get('subjects',''))
    "
    ```

16. Quick role/binding creation (exam speed):
    ```bash
    # Create role imperatively
    kubectl create role pod-writer --verb=get,list,create,delete --resource=pods -n rbac-test

    # Create binding imperatively
    kubectl create rolebinding pod-writer-binding \
      --role=pod-writer \
      --serviceaccount=rbac-test:dev-sa \
      -n rbac-test
    ```

## Validation
```bash
# pod-reader SA can only list pods
kubectl auth can-i list pods --as=system:serviceaccount:rbac-test:dev-sa -n rbac-test  # yes
kubectl auth can-i delete pods --as=system:serviceaccount:rbac-test:dev-sa -n rbac-test  # no
kubectl auth can-i get secrets --as=system:serviceaccount:rbac-test:dev-sa -n rbac-test  # no

# No unexpected cluster-admin bindings (except system defaults)
kubectl get clusterrolebindings -o json | python3 -c "
import json,sys
data=json.load(sys.stdin)
for b in data['items']:
    if b['roleRef']['name']=='cluster-admin':
        print(b['metadata']['name'])
"
```

## Exam Tips
- `kubectl auth can-i --list --as=<user>` is your primary investigation tool.
- `ClusterRole + ClusterRoleBinding` = cluster-wide; `ClusterRole + RoleBinding` = namespace-scoped.
- Wildcards `["*"]` in verbs or resources = full access = dangerous.
- `system:masters` group = always cluster-admin regardless of RBAC — cannot be restricted.
- `system:authenticated` group = all logged-in users — be careful what you bind to it.
- Always check both ClusterRoleBindings AND RoleBindings for a given subject.
- Quick imperative syntax: `kubectl create role <n> --verb=get,list --resource=pods -n <ns>`
- Quick binding: `kubectl create rolebinding <n> --role=<r> --serviceaccount=<ns>:<sa> -n <ns>`
