# LAB-13 — Image Signing with cosign

**CKS Domain:** Supply Chain Security (20%)

## Objective
Sign container images with cosign, verify signatures, and understand how to enforce signature verification in Kubernetes.

## Background
**cosign** (Sigstore project) signs and verifies container images using cryptographic signatures stored as OCI artifacts in the registry. Ensures supply chain integrity: only trusted, signed images run in production.

**Install cosign:**
```bash
curl -Lo cosign https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64
chmod +x cosign && sudo mv cosign /usr/local/bin/
cosign version
```

## Tasks

### Part A — Generate key pair

1. Generate a cosign key pair:
   ```bash
   cosign generate-key-pair
   ```
   Creates:
   - `cosign.key` (private — keep secret)
   - `cosign.pub` (public — share with verifiers)

2. Inspect the public key:
   ```bash
   cat cosign.pub
   ```

### Part B — Sign and verify an image

3. Start a local registry for testing:
   ```bash
   kubectl run registry --image=registry:2 --port=5000 --restart=Never
   kubectl expose pod registry --port=5000 --type=NodePort
   REGISTRY_PORT=$(kubectl get svc registry -o jsonpath='{.spec.ports[0].nodePort}')
   REGISTRY="192.168.1.40:$REGISTRY_PORT"
   echo "Registry: $REGISTRY"
   ```

4. Pull, tag, and push a test image:
   ```bash
   docker pull alpine:3.19
   docker tag alpine:3.19 $REGISTRY/alpine:signed
   # Configure insecure registry if needed:
   # echo '{"insecure-registries": ["192.168.1.40:'$REGISTRY_PORT'"]}' | sudo tee /etc/docker/daemon.json
   # sudo systemctl restart docker
   docker push $REGISTRY/alpine:signed
   ```

5. Sign the image:
   ```bash
   COSIGN_PASSWORD="" cosign sign \
     --key cosign.key \
     --insecure-skip-tlog-upload=true \
     --allow-insecure-registry \
     $REGISTRY/alpine:signed
   ```

6. Verify the signature:
   ```bash
   COSIGN_PASSWORD="" cosign verify \
     --key cosign.pub \
     --insecure-ignore-tlog=true \
     --allow-insecure-registry \
     $REGISTRY/alpine:signed
   ```
   Expected: Verification for... [{"critical":...}]

7. Try to verify an unsigned image — should fail:
   ```bash
   COSIGN_PASSWORD="" cosign verify \
     --key cosign.pub \
     --insecure-ignore-tlog=true \
     alpine:latest 2>&1 | head -5
   ```
   Expected: no signatures found / verification failed.

### Part C — Understand signature storage

8. Signatures are stored as OCI artifacts in the same registry:
   ```bash
   cosign triangulate --allow-insecure-registry $REGISTRY/alpine:signed
   ```
   Shows the digest reference where the signature is stored (e.g., `sha256-<digest>.sig`).

### Part D — Enforce signature verification (Kyverno)

9. Install Kyverno (if Helm is installed):
   ```bash
   helm repo add kyverno https://kyverno.github.io/kyverno/
   helm install kyverno kyverno/kyverno -n kyverno --create-namespace
   kubectl wait --for=condition=Ready pod -n kyverno \
     -l app.kubernetes.io/name=kyverno --timeout=120s
   ```

10. Create a Kyverno ClusterPolicy to enforce image signatures:
    ```yaml
    # verify-signatures-policy.yaml
    apiVersion: kyverno.io/v1
    kind: ClusterPolicy
    metadata:
      name: verify-image-signatures
    spec:
      validationFailureAction: Enforce
      background: false
      rules:
      - name: verify-cosign-signature
        match:
          any:
          - resources:
              kinds:
              - Pod
              namespaces:
              - production
        verifyImages:
        - imageReferences:
          - "*"
          attestors:
          - count: 1
            entries:
            - keys:
                publicKeys: |-
                  -----BEGIN PUBLIC KEY-----
                  <paste content of cosign.pub here>
                  -----END PUBLIC KEY-----
    ```
    ```bash
    # Get public key content
    cat cosign.pub

    # Apply the policy after substituting the key
    kubectl apply -f verify-signatures-policy.yaml
    ```

11. Test: signed image allowed:
    ```bash
    kubectl create namespace production
    kubectl run signed-app \
      --image=$REGISTRY/alpine:signed \
      -n production -- sleep 3600
    ```

12. Test: unsigned image blocked:
    ```bash
    kubectl run unsigned-app \
      --image=nginx:latest \
      -n production -- sleep 3600
    # Expected: Error from Kyverno — image signature verification failed
    ```

### Part E — Key commands for exam

13. Practice from memory:
    ```bash
    # Generate keys
    cosign generate-key-pair

    # Sign
    COSIGN_PASSWORD="" cosign sign --key cosign.key <image>

    # Verify
    COSIGN_PASSWORD="" cosign verify --key cosign.pub <image>

    # Where is the signature stored?
    cosign triangulate <image>
    ```

## Validation
```bash
# cosign installed
cosign version

# Key pair exists
ls cosign.key cosign.pub

# Verify signed image succeeds
COSIGN_PASSWORD="" cosign verify --key cosign.pub \
  --insecure-ignore-tlog=true --allow-insecure-registry \
  $REGISTRY/alpine:signed

# Verify unsigned fails
COSIGN_PASSWORD="" cosign verify --key cosign.pub alpine:latest 2>&1 | \
  grep -i "no signatures\|error\|failed"
```

## Exam Tips
- `cosign generate-key-pair` → `cosign.key` and `cosign.pub` in current directory.
- `cosign sign --key cosign.key <image>` — requires registry push access.
- `cosign verify --key cosign.pub <image>` — the key verification command.
- Signatures are stored in the OCI registry alongside the image.
- Kyverno `ClusterPolicy` with `verifyImages` is the main K8s enforcement mechanism.
- `validationFailureAction: Enforce` blocks non-compliant pods; `Audit` just logs.
- In exam: you'll likely write a Kyverno policy given a public key, not sign images yourself.
- Public key goes in `attestors[].entries[].keys.publicKeys` as a PEM string.
