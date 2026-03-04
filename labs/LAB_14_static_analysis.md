# LAB-14 — Static Analysis with kubesec and Trivy Config

**CKS Domain:** Supply Chain Security (20%)

## Objective
Perform static analysis on Kubernetes manifests to identify security misconfigurations before deployment.

## Background
Static analysis catches security issues at the source — before anything runs. Tools:
- **kubesec**: Risk score for K8s manifests (positive = secure, negative = dangerous)
- **trivy config**: Scans manifests, Dockerfiles, Helm charts for misconfigurations

## Tasks

### Part A — Install kubesec

1. Install kubesec binary:
   ```bash
   curl -Lo kubesec https://github.com/controlplaneio/kubesec/releases/latest/download/kubesec_linux_amd64
   chmod +x kubesec && sudo mv kubesec /usr/local/bin/
   kubesec version
   ```

### Part B — Scan a dangerous manifest

2. Create a maximally dangerous pod manifest:
   ```yaml
   # dangerous-pod.yaml
   apiVersion: v1
   kind: Pod
   metadata:
     name: dangerous-pod
   spec:
     hostPID: true
     hostNetwork: true
     hostIPC: true
     containers:
     - name: app
       image: ubuntu:latest
       command: ["sleep", "3600"]
       securityContext:
         privileged: true
         runAsUser: 0
         allowPrivilegeEscalation: true
       volumeMounts:
       - name: host-root
         mountPath: /host
     volumes:
     - name: host-root
       hostPath:
         path: /
   ```

3. Scan it with kubesec:
   ```bash
   kubesec scan dangerous-pod.yaml
   ```
   Observe: negative score, critical/advise sections.

4. Understand the output:
   - `score`: Overall risk score (negative = dangerous)
   - `critical`: High-severity issues that strongly affect score
   - `advise`: Recommendations to improve score

5. Also scan via API:
   ```bash
   curl -sSX POST --data-binary @dangerous-pod.yaml https://v2.kubesec.io/scan | \
     python3 -m json.tool
   ```

### Part C — Fix and rescan

6. Create a secure version:
   ```yaml
   # secure-pod.yaml
   apiVersion: v1
   kind: Pod
   metadata:
     name: secure-pod
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
       resources:
         limits:
           cpu: "100m"
           memory: "64Mi"
         requests:
           cpu: "50m"
           memory: "32Mi"
   ```

7. Scan the secure manifest:
   ```bash
   kubesec scan secure-pod.yaml
   ```
   Expected: positive score.

8. Compare scores:
   ```bash
   echo "Dangerous score:" && \
     kubesec scan dangerous-pod.yaml | python3 -c "import json,sys; print(json.load(sys.stdin)[0]['score'])"

   echo "Secure score:" && \
     kubesec scan secure-pod.yaml | python3 -c "import json,sys; print(json.load(sys.stdin)[0]['score'])"
   ```

### Part D — Trivy config scanning

9. Scan the dangerous manifest with Trivy:
   ```bash
   trivy config dangerous-pod.yaml
   ```

10. Scan a directory:
    ```bash
    mkdir manifests
    cp dangerous-pod.yaml secure-pod.yaml manifests/
    trivy config manifests/
    ```

11. Create and scan a bad Dockerfile:
    ```bash
    cat > Dockerfile.bad << 'EOF'
    FROM ubuntu:latest
    RUN apt-get update && apt-get install -y ssh sudo curl wget vim
    ADD secret.txt /app/
    WORKDIR /app
    USER root
    EXPOSE 22 80 443
    CMD ["/bin/bash"]
    EOF

    trivy config Dockerfile.bad
    ```

12. Fix the Dockerfile and rescan:
    ```bash
    cat > Dockerfile.good << 'EOF'
    FROM ubuntu:22.04
    RUN apt-get update \
        && apt-get install -y --no-install-recommends curl \
        && rm -rf /var/lib/apt/lists/*
    COPY --chown=appuser:appuser . /app
    WORKDIR /app
    RUN groupadd -r appuser && useradd -r -g appuser -u 1001 appuser
    USER appuser
    EXPOSE 8080
    CMD ["/app/server"]
    EOF

    trivy config Dockerfile.good
    ```

### Part E — Exam scenario: identify and fix

13. Find the most dangerous manifest from a set:
    ```bash
    for f in dangerous-pod.yaml secure-pod.yaml; do
      score=$(kubesec scan $f | python3 -c "import json,sys; print(json.load(sys.stdin)[0]['score'])")
      echo "$f: score=$score"
    done
    ```

14. Fix the top 3 issues in the worst-scoring manifest (standard CKS fixes):
    - Remove `privileged: true`
    - Add `runAsNonRoot: true` and non-zero `runAsUser`
    - Add `allowPrivilegeEscalation: false`
    - Add `capabilities: drop: [ALL]`
    - Add `readOnlyRootFilesystem: true`

15. Rescan and verify improvement:
    ```bash
    kubesec scan dangerous-pod-fixed.yaml | python3 -c "
    import json, sys
    d = json.load(sys.stdin)
    print('Score:', d[0]['score'])
    print('Critical issues:', [i['selector'] for i in d[0].get('scoring', {}).get('critical', [])])
    "
    ```

## Validation
```bash
# kubesec installed
kubesec version

# Dangerous pod has negative score
kubesec scan dangerous-pod.yaml | python3 -c "import json,sys; print(json.load(sys.stdin)[0]['score'])"
# Should be negative

# Secure pod has positive score
kubesec scan secure-pod.yaml | python3 -c "import json,sys; print(json.load(sys.stdin)[0]['score'])"
# Should be positive

# Trivy finds issues in bad Dockerfile
trivy config Dockerfile.bad | grep -E "HIGH|CRITICAL"
```

## Exam Tips
- `kubesec scan <file>` — positive score = secure, negative = dangerous.
- kubesec penalizes: `privileged`, `hostPID`, `hostNetwork`, `hostIPC`, root user, hostPath mounts.
- kubesec rewards: `readOnlyRootFilesystem`, `runAsNonRoot`, `capabilities.drop: ALL`, resource limits, seccomp.
- `trivy config <file>` scans K8s, Dockerfile, Helm for misconfigurations.
- In exam: static analysis = identify problems in YAML files, not run them.
- kubesec output JSON: `[{"score": N, "scoring": {"critical": [...], "advise": [...]}}]`
- Inline scan: `echo '<yaml>' | kubesec scan /dev/stdin`
