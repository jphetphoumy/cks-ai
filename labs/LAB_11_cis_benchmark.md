# LAB-11 — CIS Benchmark with kube-bench

**CKS Domain:** Cluster Setup (15%)

## Objective
Run kube-bench against the cluster, understand the most important CIS findings, and remediate common failures.

## Background
The **CIS Kubernetes Benchmark** defines security hardening standards. **kube-bench** automates checking against these standards.

**Benchmark sections:**
- Section 1: Control Plane Components (kube-apiserver, controller-manager, scheduler)
- Section 2: etcd
- Section 3: Control Plane Configuration (RBAC, encryption)
- Section 4: Worker Nodes (kubelet)
- Section 5: Policies

**Install kube-bench:**
```bash
curl -L https://github.com/aquasecurity/kube-bench/releases/latest/download/kube-bench_linux_amd64.tar.gz \
  | sudo tar xz -C /usr/local/bin/ kube-bench
kube-bench version
```

## Tasks

### Part A — Run full benchmark

1. Run all control plane checks:
   ```bash
   sudo kube-bench run --targets master 2>&1 | tee kube-bench-master.txt
   ```

2. Run worker node checks:
   ```bash
   ssh 192.168.1.41 "sudo kube-bench run --targets node 2>&1" | tee kube-bench-node.txt
   ```

3. Count PASS/FAIL/WARN:
   ```bash
   grep -E "^\[PASS\]|^\[FAIL\]|^\[WARN\]" kube-bench-master.txt | \
     sort | uniq -c
   ```

4. Show only FAIL items:
   ```bash
   grep -A5 "^\[FAIL\]" kube-bench-master.txt | head -80
   ```

### Part B — Run specific checks

5. Check 1.2.1 — API server anonymous auth:
   ```bash
   sudo kube-bench run --targets master --check 1.2.1
   ```
   Fix: `--anonymous-auth=false` on kube-apiserver.

6. Check 1.2.19 — Audit logging configured:
   ```bash
   sudo kube-bench run --targets master --check 1.2.19
   ```
   Fix: `--audit-log-path` must be set (done in LAB-08).

7. Check 1.2.22 — Audit log maxage:
   ```bash
   sudo kube-bench run --targets master --check 1.2.22
   ```

8. Check 3.2.1 — Audit policy configured:
   ```bash
   sudo kube-bench run --targets master --check 3.2.1
   ```

9. Check 4.2.1 — Kubelet anonymous auth:
   ```bash
   ssh 192.168.1.41 "sudo kube-bench run --targets node --check 4.2.1"
   ```

10. Check 4.2.2 — Kubelet authorization mode:
    ```bash
    ssh 192.168.1.41 "sudo kube-bench run --targets node --check 4.2.2"
    ```

### Part C — Remediate common failures

11. Fix: kube-apiserver anonymous auth:
    ```bash
    sudo grep "anonymous-auth" /etc/kubernetes/manifests/kube-apiserver.yaml || \
      echo "Flag missing — need to add --anonymous-auth=false"
    # Edit manifest to add the flag if missing
    sudo vim /etc/kubernetes/manifests/kube-apiserver.yaml
    ```

12. Fix: kube-apiserver profiling disabled:
    ```bash
    sudo grep "profiling" /etc/kubernetes/manifests/kube-apiserver.yaml || \
      echo "Need to add --profiling=false"
    ```

13. Fix: kubelet authorization on worker:
    ```bash
    ssh 192.168.1.41 "sudo grep -A2 'authorization:' /var/lib/kubelet/config.yaml"
    # Should show: mode: Webhook
    # If AlwaysAllow, fix it:
    ssh 192.168.1.41 "sudo sed -i 's/mode: AlwaysAllow/mode: Webhook/' \
      /var/lib/kubelet/config.yaml && sudo systemctl restart kubelet"
    ```

14. Fix: kubelet protectKernelDefaults:
    ```bash
    ssh 192.168.1.41 "sudo grep protectKernelDefaults /var/lib/kubelet/config.yaml"
    # If missing:
    ssh 192.168.1.41 "echo 'protectKernelDefaults: true' | \
      sudo tee -a /var/lib/kubelet/config.yaml && sudo systemctl restart kubelet"
    ```

15. Fix: kubelet readOnlyPort = 0:
    ```bash
    ssh 192.168.1.41 "grep -q readOnlyPort /var/lib/kubelet/config.yaml && \
      sudo sed -i 's/readOnlyPort:.*/readOnlyPort: 0/' /var/lib/kubelet/config.yaml || \
      echo 'readOnlyPort: 0' | sudo tee -a /var/lib/kubelet/config.yaml"
    ssh 192.168.1.41 "sudo systemctl restart kubelet"
    ```

### Part D — Re-run after fixes

16. Re-run master checks and compare:
    ```bash
    sudo kube-bench run --targets master 2>&1 | grep -E "^\[PASS\]|^\[FAIL\]" | wc -l
    ```

17. JSON output for full analysis:
    ```bash
    sudo kube-bench run --targets master --json 2>/dev/null | python3 -c "
    import json, sys
    data = json.load(sys.stdin)
    for section in data.get('Controls', []):
        for group in section.get('groups', []):
            for test in group.get('tests', []):
                if test['status'] == 'FAIL':
                    print(f'FAIL {test[\"test_number\"]}: {test[\"test_desc\"][:80]}')
    "
    ```

## Validation
```bash
# kube-bench installed
kube-bench version

# FAIL count (should decrease after fixes)
sudo kube-bench run --targets master 2>&1 | grep "^\[FAIL\]" | wc -l

# Specific checks pass
sudo kube-bench run --targets master --check 1.2.1 2>&1 | grep -E "PASS|FAIL"
```

## Exam Tips
- Key config files:
  - kube-apiserver: `/etc/kubernetes/manifests/kube-apiserver.yaml`
  - kubelet: `/var/lib/kubelet/config.yaml`
  - etcd: `/etc/kubernetes/manifests/etcd.yaml`
  - controller-manager: `/etc/kubernetes/manifests/kube-controller-manager.yaml`
  - scheduler: `/etc/kubernetes/manifests/kube-scheduler.yaml`
- After editing static pod manifests: wait ~30s for auto-restart.
- After editing kubelet config: `sudo systemctl restart kubelet`.
- kube-bench FAIL items include the **remediation text** — read it carefully for the exact fix.
- `kube-bench run --check <id>` runs only a specific check.
- In exam: you'll be given specific check IDs to remediate.
