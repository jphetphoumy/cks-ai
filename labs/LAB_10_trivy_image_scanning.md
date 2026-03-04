# LAB-10 — Container Image Scanning with Trivy

**CKS Domain:** Supply Chain Security (20%)

## Objective
Use Trivy to scan container images for vulnerabilities, generate SBOMs, scan Kubernetes manifests for misconfigurations, and compare base image security.

## Background
Trivy is a comprehensive security scanner covering:
- Container images (CVEs)
- Kubernetes manifests, Dockerfiles, Helm charts (misconfigurations)
- SBOM (Software Bill of Materials) generation

**Install Trivy:**
```bash
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | \
  sh -s -- -b /usr/local/bin
trivy --version
```

## Tasks

### Part A — Basic image scanning

1. Scan a public image:
   ```bash
   trivy image nginx:latest
   ```
   Observe: vulnerability ID, severity, package, installed version, fixed version.

2. Filter by severity (exam-essential):
   ```bash
   trivy image --severity HIGH,CRITICAL nginx:latest
   ```

3. Only fixable vulnerabilities:
   ```bash
   trivy image --severity HIGH,CRITICAL --ignore-unfixed nginx:latest
   ```

4. Output as JSON:
   ```bash
   trivy image -f json -o nginx-results.json nginx:latest
   cat nginx-results.json | python3 -c "
   import json, sys
   data = json.load(sys.stdin)
   for result in data.get('Results', []):
       vulns = result.get('Vulnerabilities', [])
       critical = [v for v in vulns if v.get('Severity') == 'CRITICAL']
       print(f'Target: {result[\"Target\"]} — CRITICAL: {len(critical)}')
   "
   ```

5. Compare base images:
   ```bash
   echo "=== nginx:latest ===" && \
     trivy image --severity HIGH,CRITICAL nginx:latest 2>&1 | grep "Total:"
   echo "=== nginx:alpine ===" && \
     trivy image --severity HIGH,CRITICAL nginx:alpine 2>&1 | grep "Total:"
   echo "=== alpine:latest ===" && \
     trivy image --severity HIGH,CRITICAL alpine:latest 2>&1 | grep "Total:"
   ```
   Observation: fewer packages = fewer CVEs.

6. Scan a distroless image:
   ```bash
   trivy image gcr.io/distroless/static:nonroot
   ```
   Expected: very few or zero vulnerabilities.

### Part B — Find specific CVE details

7. Find the top CRITICAL CVEs in nginx:latest:
   ```bash
   trivy image -f json nginx:latest | python3 -c "
   import json, sys
   data = json.load(sys.stdin)
   vulns = []
   for r in data.get('Results', []):
       vulns.extend(r.get('Vulnerabilities', []))
   critical = [v for v in vulns if v.get('Severity') == 'CRITICAL']
   for v in critical[:5]:
       print(v['VulnerabilityID'], v['PkgName'],
             v.get('InstalledVersion'), '->', v.get('FixedVersion', 'no fix'))
   "
   ```

### Part C — Scan Kubernetes manifests

8. Create a "bad" pod manifest:
   ```yaml
   # bad-pod.yaml
   apiVersion: v1
   kind: Pod
   metadata:
     name: bad-pod
   spec:
     hostPID: true
     hostNetwork: true
     containers:
     - name: app
       image: ubuntu:latest
       securityContext:
         privileged: true
         runAsUser: 0
   ```

9. Scan it:
   ```bash
   trivy config bad-pod.yaml
   ```
   Observe: hostPID, hostNetwork, privileged, root user flagged.

10. Scan all manifests in a directory:
    ```bash
    trivy config ./
    ```

### Part D — Scan Dockerfiles

11. Create a bad Dockerfile:
    ```bash
    cat > Dockerfile.bad << 'EOF'
    FROM ubuntu:latest
    RUN apt-get update && apt-get install -y ssh curl wget
    ADD secret.txt /app/
    WORKDIR /app
    USER root
    EXPOSE 22
    CMD ["/bin/bash"]
    EOF
    ```

12. Scan it:
    ```bash
    trivy config Dockerfile.bad
    ```
    Issues: `latest` tag, root user, SSH exposed, ADD instead of COPY.

13. Fix the Dockerfile:
    ```bash
    cat > Dockerfile.good << 'EOF'
    FROM ubuntu:22.04
    RUN apt-get update \
        && apt-get install -y --no-install-recommends curl \
        && rm -rf /var/lib/apt/lists/*
    COPY . /app
    WORKDIR /app
    RUN groupadd -r appuser && useradd -r -g appuser -u 1001 appuser
    USER appuser
    EXPOSE 8080
    CMD ["/app/server"]
    EOF
    trivy config Dockerfile.good
    ```

### Part E — SBOM generation

14. Generate SBOM in CycloneDX format:
    ```bash
    trivy image --format cyclonedx --output sbom-cyclonedx.json nginx:alpine
    cat sbom-cyclonedx.json | python3 -c "
    import json, sys
    data = json.load(sys.stdin)
    components = data.get('components', [])
    print(f'Total components: {len(components)}')
    for c in components[:5]:
        print(c.get('name'), c.get('version'))
    "
    ```

15. Generate in SPDX format:
    ```bash
    trivy image --format spdx-json --output sbom-spdx.json nginx:alpine
    ```

### Part F — Scan running cluster

16. Scan the entire cluster:
    ```bash
    trivy k8s --report summary cluster
    ```

17. Scan a specific namespace:
    ```bash
    trivy k8s --report summary --namespace kube-system cluster
    ```

## Validation
```bash
# Trivy version
trivy --version

# Image scan returns results
trivy image --severity HIGH,CRITICAL nginx:latest | grep -E "Total|CRITICAL"

# Config scan finds issues in bad-pod.yaml
trivy config bad-pod.yaml | grep -E "CRITICAL|HIGH"

# SBOM generated
ls -la sbom-cyclonedx.json
```

## Exam Tips
- `trivy image --severity HIGH,CRITICAL --ignore-unfixed <image>` is the exam-standard command.
- `trivy config <file>` scans Kubernetes manifests, Dockerfiles, Helm charts.
- Smaller base images have fewer CVEs: `distroless` < `alpine` < `debian-slim` < `ubuntu`.
- An SBOM is an inventory of all packages in an image.
- In exam: identify which image has the most/highest CVEs, or find specific CVE details.
- `trivy image -f json <image>` for machine-readable output.
- `trivy k8s cluster` scans all running workloads.
- Always use specific image tags — `latest` makes reproducible scanning unreliable.
