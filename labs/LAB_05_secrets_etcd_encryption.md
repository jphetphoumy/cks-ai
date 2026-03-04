# LAB-05 — Secrets Management & etcd Encryption at Rest

**CKS Domain:** Minimize Microservice Vulnerabilities (20%)

## Objective
Understand Kubernetes Secrets limitations, enable etcd encryption at rest, verify secrets are actually encrypted, and handle secrets securely in pods.

## Background
Kubernetes Secrets are **base64-encoded by default — NOT encrypted**. Anyone with direct etcd access can read them in plaintext.

**Attack path without encryption:** Access to etcd → `etcdctl get /registry/secrets/...` → plaintext secrets.

## Tasks

### Part A — Baseline: secrets are NOT encrypted

1. Create a test secret:
   ```bash
   kubectl create secret generic db-creds \
     --from-literal=username=admin \
     --from-literal=password=SuperSecret123
   ```

2. Show base64 is NOT encryption:
   ```bash
   kubectl get secret db-creds -o jsonpath='{.data.password}' | base64 -d
   ```
   Expected: `SuperSecret123` — trivially readable.

3. Read directly from etcd (plaintext):
   ```bash
   sudo ETCDCTL_API=3 etcdctl \
     --endpoints=https://127.0.0.1:2379 \
     --cacert=/etc/kubernetes/pki/etcd/ca.crt \
     --cert=/etc/kubernetes/pki/etcd/server.crt \
     --key=/etc/kubernetes/pki/etcd/server.key \
     get /registry/secrets/default/db-creds | strings
   ```
   Expected: password visible in plaintext.

### Part B — Use secrets in pods

4. Mount as environment variable (less secure):
   ```yaml
   # secret-env-pod.yaml
   apiVersion: v1
   kind: Pod
   metadata:
     name: secret-env-pod
   spec:
     containers:
     - name: app
       image: alpine:3.19
       command: ["sleep", "3600"]
       env:
       - name: DB_PASSWORD
         valueFrom:
           secretKeyRef:
             name: db-creds
             key: password
   ```
   ```bash
   kubectl apply -f secret-env-pod.yaml
   kubectl exec secret-env-pod -- env | grep DB_PASSWORD
   ```

5. Mount as volume (more secure — not in process env):
   ```yaml
   # secret-vol-pod.yaml
   apiVersion: v1
   kind: Pod
   metadata:
     name: secret-vol-pod
   spec:
     containers:
     - name: app
       image: alpine:3.19
       command: ["sleep", "3600"]
       volumeMounts:
       - name: secret-vol
         mountPath: /etc/secrets
         readOnly: true
     volumes:
     - name: secret-vol
       secret:
         secretName: db-creds
   ```
   ```bash
   kubectl apply -f secret-vol-pod.yaml
   kubectl exec secret-vol-pod -- cat /etc/secrets/password
   ```

6. Create an immutable secret:
   ```bash
   kubectl patch secret db-creds -p '{"immutable": true}'
   ```

### Part C — Enable etcd encryption at rest

7. Generate a 32-byte AES key:
   ```bash
   head -c 32 /dev/urandom | base64
   ```
   Save the output as `<AES_KEY>`.

8. Create the encryption config:
   ```bash
   sudo mkdir -p /etc/kubernetes/enc
   ```
   Create `/etc/kubernetes/enc/encryption-config.yaml`:
   ```yaml
   apiVersion: apiserver.config.k8s.io/v1
   kind: EncryptionConfiguration
   resources:
   - resources:
     - secrets
     - configmaps
     providers:
     - aescbc:
         keys:
         - name: key1
           secret: <AES_KEY>
     - identity: {}
   ```
   > `identity: {}` must be LAST — allows reading unencrypted existing data.

9. Edit kube-apiserver manifest:
   ```bash
   sudo cp /etc/kubernetes/manifests/kube-apiserver.yaml \
     /etc/kubernetes/manifests/kube-apiserver.yaml.bak
   sudo vim /etc/kubernetes/manifests/kube-apiserver.yaml
   ```
   Add to `spec.containers[0].command`:
   ```yaml
   - --encryption-provider-config=/etc/kubernetes/enc/encryption-config.yaml
   ```
   Add to `spec.containers[0].volumeMounts`:
   ```yaml
   - name: enc-config
     mountPath: /etc/kubernetes/enc
     readOnly: true
   ```
   Add to `spec.volumes`:
   ```yaml
   - name: enc-config
     hostPath:
       path: /etc/kubernetes/enc
       type: DirectoryOrCreate
   ```

10. Wait for kube-apiserver to restart:
    ```bash
    watch kubectl get pods -n kube-system | grep apiserver
    ```

11. Verify cluster still works:
    ```bash
    kubectl get nodes
    ```

### Part D — Verify encryption works

12. Create a NEW secret after enabling encryption:
    ```bash
    kubectl create secret generic encrypted-secret --from-literal=key=TopSecret
    ```

13. Read from etcd — should be encrypted now:
    ```bash
    sudo ETCDCTL_API=3 etcdctl \
      --endpoints=https://127.0.0.1:2379 \
      --cacert=/etc/kubernetes/pki/etcd/ca.crt \
      --cert=/etc/kubernetes/pki/etcd/server.crt \
      --key=/etc/kubernetes/pki/etcd/server.key \
      get /registry/secrets/default/encrypted-secret | strings
    ```
    Expected: garbled binary — NOT readable.

14. Re-encrypt all existing secrets:
    ```bash
    kubectl get secrets --all-namespaces -o json | kubectl replace -f -
    ```

15. Verify old secret is now encrypted:
    ```bash
    sudo ETCDCTL_API=3 etcdctl \
      --endpoints=https://127.0.0.1:2379 \
      --cacert=/etc/kubernetes/pki/etcd/ca.crt \
      --cert=/etc/kubernetes/pki/etcd/server.crt \
      --key=/etc/kubernetes/pki/etcd/server.key \
      get /registry/secrets/default/db-creds | strings
    ```
    Expected: encrypted (not readable).

## Validation
```bash
# Secret readable via kubectl (decrypted by apiserver)
kubectl get secret encrypted-secret -o jsonpath='{.data.key}' | base64 -d  # TopSecret

# Secret NOT readable in etcd directly
sudo ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/default/encrypted-secret | grep -c TopSecret
# Should return 0 (not found — encrypted)
```

## Exam Tips
- Encryption key: `head -c 32 /dev/urandom | base64`
- Provider order: FIRST = encrypt new data; ALL tried for decryption.
- `identity: {}` = plaintext — put it LAST to allow reading old unencrypted data.
- After enabling: re-encrypt existing secrets with `kubectl get secrets -A -o json | kubectl replace -f -`
- `aescbc` is the recommended provider for CKS.
- Add encryption config as a `hostPath` volume to the kube-apiserver static pod.
- Static pod restart: edit manifest → kubelet auto-restarts → wait ~30s → verify with `kubectl get nodes`.
- etcdctl flags to memorize: `--endpoints=https://127.0.0.1:2379 --cacert=... --cert=... --key=...`
