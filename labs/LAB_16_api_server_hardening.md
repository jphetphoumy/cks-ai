# LAB-16 — API Server & Node Hardening

**CKS Domain:** Cluster Hardening (15%)

## Objective
Harden the kube-apiserver, kubelet configuration, and protect against unauthorized API access and node metadata abuse.

## Background
The kube-apiserver is the cluster's central control plane component. Misconfigured flags are a major attack vector. This lab covers: anonymous auth, admission plugins, kubelet authorization, and node metadata protection.

## Tasks

### Part A — Audit current kube-apiserver configuration

1. Read current flags:
   ```bash
   sudo cat /etc/kubernetes/manifests/kube-apiserver.yaml | grep -A200 "command:"
   ```

2. Check critical security settings:
   ```bash
   # Anonymous auth (should be false)
   sudo grep "anonymous-auth" /etc/kubernetes/manifests/kube-apiserver.yaml

   # Admission plugins
   sudo grep "enable-admission-plugins" /etc/kubernetes/manifests/kube-apiserver.yaml

   # Profiling (should be false)
   sudo grep "profiling" /etc/kubernetes/manifests/kube-apiserver.yaml

   # Encryption at rest
   sudo grep "encryption-provider-config" /etc/kubernetes/manifests/kube-apiserver.yaml
   ```

3. Test anonymous API access:
   ```bash
   curl -k https://$MASTER_IP:6443/api/v1/namespaces
   ```
   Should return 401/403 — not actual data.

### Part B — Harden kube-apiserver

4. Backup the manifest:
   ```bash
   sudo cp /etc/kubernetes/manifests/kube-apiserver.yaml \
     /etc/kubernetes/manifests/kube-apiserver.yaml.bak
   ```

5. Edit and add/verify hardening flags:
   ```bash
   sudo vim /etc/kubernetes/manifests/kube-apiserver.yaml
   ```
   Flags to add to `spec.containers[0].command` if missing:
   ```yaml
   - --anonymous-auth=false
   - --profiling=false
   - --enable-admission-plugins=NodeRestriction,AlwaysPullImages
   ```

6. Wait for kube-apiserver to restart:
   ```bash
   sleep 10 && watch "sudo crictl ps | grep kube-apiserver"
   ```

7. Verify anonymous access is blocked:
   ```bash
   curl -k https://$MASTER_IP:6443/api/v1/namespaces
   # Should return 403 Forbidden
   ```

### Part C — Audit and harden kubelet

8. Check kubelet config on master:
   ```bash
   sudo cat /var/lib/kubelet/config.yaml
   ```

9. Check kubelet on worker:
   ```bash
   ssh $AGENT_IP "sudo cat /var/lib/kubelet/config.yaml"
   ```

10. Verify critical kubelet settings on both nodes:
    ```bash
    # Anonymous auth disabled (enabled: false)
    sudo grep -A3 "authentication:" /var/lib/kubelet/config.yaml

    # Authorization Webhook (not AlwaysAllow)
    sudo grep -A3 "authorization:" /var/lib/kubelet/config.yaml

    # Read-only port disabled
    sudo grep "readOnlyPort" /var/lib/kubelet/config.yaml
    # Should be 0 or absent
    ```

11. Fix on worker node if needed:
    ```bash
    # Fix authorization if AlwaysAllow
    ssh $AGENT_IP "sudo grep -A3 'authorization:' /var/lib/kubelet/config.yaml"
    ssh $AGENT_IP "sudo sed -i 's/mode: AlwaysAllow/mode: Webhook/g' /var/lib/kubelet/config.yaml"
    ssh $AGENT_IP "sudo systemctl restart kubelet"

    # Disable read-only port
    ssh $AGENT_IP "grep -q readOnlyPort /var/lib/kubelet/config.yaml && \
      sudo sed -i 's/readOnlyPort:.*/readOnlyPort: 0/' /var/lib/kubelet/config.yaml || \
      echo 'readOnlyPort: 0' | sudo tee -a /var/lib/kubelet/config.yaml"
    ssh $AGENT_IP "sudo systemctl restart kubelet"

    # Add protectKernelDefaults
    ssh $AGENT_IP "grep -q protectKernelDefaults /var/lib/kubelet/config.yaml || \
      echo 'protectKernelDefaults: true' | sudo tee -a /var/lib/kubelet/config.yaml"
    ssh $AGENT_IP "sudo systemctl restart kubelet"
    ```

12. Verify kubelet port 10255 is closed:
    ```bash
    curl http://$AGENT_IP:10255/metrics 2>&1 | head -3
    # Should fail / timeout
    ```

### Part D — Find and remove dangerous ClusterRoleBindings

13. Find all cluster-admin bindings:
    ```bash
    kubectl get clusterrolebindings -o json | python3 -c "
    import json, sys
    data = json.load(sys.stdin)
    for b in data['items']:
        if b['roleRef']['name'] == 'cluster-admin':
            subjects = b.get('subjects', [])
            print(b['metadata']['name'], '->', subjects)
    "
    ```

14. Find bindings to anonymous/unauthenticated users:
    ```bash
    kubectl get clusterrolebindings,rolebindings -A -o json | python3 -c "
    import json, sys
    data = json.load(sys.stdin)
    dangerous = ['system:anonymous', 'system:unauthenticated']
    for b in data['items']:
        for s in b.get('subjects', []):
            if s.get('name') in dangerous or s.get('group') in dangerous:
                print('DANGEROUS:', b['kind'], b['metadata']['name'], '->', s)
    "
    ```

15. Delete dangerous bindings:
    ```bash
    kubectl delete clusterrolebinding <name>
    ```

### Part E — Protect node metadata endpoint

16. Block pod access to cloud metadata service (169.254.169.254):
    ```yaml
    # block-metadata.yaml
    apiVersion: networking.k8s.io/v1
    kind: NetworkPolicy
    metadata:
      name: block-cloud-metadata
      namespace: default
    spec:
      podSelector: {}
      policyTypes:
      - Egress
      egress:
      - to:
        - ipBlock:
            cidr: 0.0.0.0/0
            except:
            - 169.254.169.254/32
      - ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
    ```
    ```bash
    kubectl apply -f block-metadata.yaml
    ```

17. Test (on a cloud node, this would block metadata access):
    ```bash
    kubectl run meta-test --image=alpine:3.19 --restart=Never -- sleep 3600
    kubectl exec meta-test -- wget -qO- --timeout=2 http://169.254.169.254/ 2>&1
    # Expected: timeout (blocked by NetworkPolicy)
    kubectl delete pod meta-test
    ```

### Part F — Exam scenario: full fix sequence

18. Practice this sequence from memory:
    ```bash
    # 1. Fix kube-apiserver anonymous auth
    sudo vim /etc/kubernetes/manifests/kube-apiserver.yaml
    # Add: --anonymous-auth=false

    # 2. Fix kubelet authorization on worker
    ssh $AGENT_IP "sudo sed -i 's/mode: AlwaysAllow/mode: Webhook/' \
      /var/lib/kubelet/config.yaml && sudo systemctl restart kubelet"

    # 3. Remove dangerous ClusterRoleBinding
    kubectl delete clusterrolebinding <dangerous-binding>

    # 4. Verify cluster still works
    kubectl get nodes
    curl -k https://$MASTER_IP:6443/api  # 403
    ```

## Validation
```bash
# Anonymous access blocked
curl -k https://$MASTER_IP:6443/api/v1/namespaces 2>&1 | grep -E "403|Forbidden|401"

# Kubelet uses Webhook authorization
ssh $AGENT_IP "grep -A3 'authorization:' /var/lib/kubelet/config.yaml | grep Webhook"

# No dangerous anonymous bindings
kubectl get clusterrolebindings -o json | python3 -c "
import json,sys
data=json.load(sys.stdin)
bad=[b['metadata']['name'] for b in data['items']
     if b['roleRef']['name']=='cluster-admin'
     and any(s.get('name') in ['system:anonymous','system:unauthenticated']
             for s in b.get('subjects',[]))]
print('Dangerous bindings:', bad or 'None — good!')
"
```

## Exam Tips
- kube-apiserver manifest: `/etc/kubernetes/manifests/kube-apiserver.yaml` — auto-restarts on edit.
- kubelet config: `/var/lib/kubelet/config.yaml` — requires `sudo systemctl restart kubelet`.
- Key kube-apiserver flags: `--anonymous-auth=false`, `--profiling=false`, `--enable-admission-plugins=NodeRestriction`.
- Key kubelet settings: `authentication.anonymous.enabled: false`, `authorization.mode: Webhook`, `readOnlyPort: 0`.
- Always back up apiserver manifest before editing.
- Monitor apiserver restart: `watch "sudo crictl ps | grep apiserver"`.
- If apiserver fails: `sudo crictl logs $(sudo crictl ps -a | grep kube-apiserver | awk '{print $1}')`.
- **NodeRestriction**: prevents nodes from modifying other nodes/pods — always enable.
- **AlwaysPullImages**: forces registry auth on every pod start — prevents cached image abuse in multi-tenant clusters.
