# LAB-08 — Kubernetes Audit Logging

**CKS Domain:** Monitoring, Logging and Runtime Security (20%)

## Objective
Configure the kube-apiserver audit policy, generate audit events, and analyze logs to identify suspicious activity.

## Background
Kubernetes audit logging records every API request. The audit policy defines what to log and at what detail level.

**Stages:** `RequestReceived`, `ResponseStarted`, `ResponseComplete`, `Panic`

**Levels:**
- `None`: Don't log
- `Metadata`: Log request metadata only (user, verb, resource) — use for secrets
- `Request`: Metadata + request body
- `RequestResponse`: Metadata + request + response body (verbose — avoid for secrets)

## Tasks

### Part A — Create audit policy

1. Create directories on k8s-master:
   ```bash
   sudo mkdir -p /etc/kubernetes/audit
   sudo mkdir -p /var/log/kubernetes/audit
   ```

2. Write the audit policy:
   ```bash
   sudo tee /etc/kubernetes/audit/audit-policy.yaml << 'EOF'
   apiVersion: audit.k8s.io/v1
   kind: Policy
   rules:
   # Don't log health checks
   - level: None
     nonResourceURLs:
     - /healthz*
     - /readyz*
     - /livez*
     - /version
     - /swagger*

   # Log secret/configmap access at Metadata ONLY (never log content)
   - level: Metadata
     resources:
     - group: ""
       resources: ["secrets", "configmaps"]

   # Log pod create/delete at RequestResponse
   - level: RequestResponse
     verbs: ["create", "update", "delete"]
     resources:
     - group: ""
       resources: ["pods"]

   # Log everything else at Metadata
   - level: Metadata
   EOF
   ```

### Part B — Configure kube-apiserver

3. Backup the manifest:
   ```bash
   sudo cp /etc/kubernetes/manifests/kube-apiserver.yaml \
     /etc/kubernetes/manifests/kube-apiserver.yaml.bak
   ```

4. Edit the manifest:
   ```bash
   sudo vim /etc/kubernetes/manifests/kube-apiserver.yaml
   ```

5. Add to `spec.containers[0].command`:
   ```yaml
   - --audit-policy-file=/etc/kubernetes/audit/audit-policy.yaml
   - --audit-log-path=/var/log/kubernetes/audit/audit.log
   - --audit-log-maxage=7
   - --audit-log-maxbackup=3
   - --audit-log-maxsize=100
   ```

6. Add to `spec.containers[0].volumeMounts`:
   ```yaml
   - name: audit-policy
     mountPath: /etc/kubernetes/audit
     readOnly: true
   - name: audit-log
     mountPath: /var/log/kubernetes/audit
   ```

7. Add to `spec.volumes`:
   ```yaml
   - name: audit-policy
     hostPath:
       path: /etc/kubernetes/audit
       type: DirectoryOrCreate
   - name: audit-log
     hostPath:
       path: /var/log/kubernetes/audit
       type: DirectoryOrCreate
   ```

8. Wait for kube-apiserver to restart:
   ```bash
   sleep 10 && watch "sudo crictl ps | grep kube-apiserver"
   ```

9. Verify audit log is being written:
   ```bash
   sudo ls -la /var/log/kubernetes/audit/
   ```

### Part C — Generate and analyze audit events

10. Trigger audit events:
    ```bash
    kubectl create secret generic audit-test --from-literal=key=value
    kubectl get secret audit-test
    kubectl run audit-pod --image=alpine:3.19 -- sleep 3600
    kubectl delete pod audit-pod
    ```

11. Read audit events:
    ```bash
    sudo tail -5 /var/log/kubernetes/audit/audit.log | python3 -m json.tool
    ```

12. Find secret access events:
    ```bash
    sudo grep '"resource":"secrets"' /var/log/kubernetes/audit/audit.log | \
      python3 -c "
    import json, sys
    for line in sys.stdin:
        e = json.loads(line)
        print(e['stageTimestamp'], e['user']['username'], e['verb'],
              e['objectRef'].get('name',''))
    "
    ```

13. Find who deleted a pod:
    ```bash
    sudo grep '"verb":"delete"' /var/log/kubernetes/audit/audit.log | \
      grep '"resource":"pods"' | \
      python3 -c "
    import json, sys
    for line in sys.stdin:
        e = json.loads(line)
        print('User:', e['user']['username'],
              '| Pod:', e['objectRef'].get('name'),
              '| Time:', e['stageTimestamp'])
    "
    ```

14. Find failed auth attempts (403/401):
    ```bash
    sudo grep -E '"code":(401|403)' /var/log/kubernetes/audit/audit.log | \
      python3 -c "
    import json, sys
    for line in sys.stdin:
        e = json.loads(line)
        status = e.get('responseStatus', {})
        if status.get('code') in [401, 403]:
            print(status['code'], e['user']['username'],
                  e['verb'], e['objectRef'].get('resource'))
    "
    ```

### Part D — Exam scenario: investigate suspicious access

15. Find all secret reads in a specific namespace:
    ```bash
    NAMESPACE="default"
    sudo grep '"resource":"secrets"' /var/log/kubernetes/audit/audit.log | \
      python3 -c "
    import json, sys
    for line in sys.stdin:
        e = json.loads(line)
        ref = e.get('objectRef', {})
        if ref.get('namespace') == '$NAMESPACE' and e['verb'] in ['get', 'list']:
            print('Time:', e['stageTimestamp'])
            print('User:', e['user']['username'])
            print('Groups:', e['user'].get('groups', []))
            print('Source IP:', e.get('sourceIPs', []))
            print('Secret:', ref.get('name'))
            print('---')
    "
    ```

## Validation
```bash
# Audit log exists and has content
sudo ls -la /var/log/kubernetes/audit/audit.log
sudo wc -l /var/log/kubernetes/audit/audit.log

# Secret access events logged
kubectl create secret generic validation-secret --from-literal=x=y
sudo grep validation-secret /var/log/kubernetes/audit/audit.log | head -3

# kube-apiserver running with audit flags
sudo cat /etc/kubernetes/manifests/kube-apiserver.yaml | grep audit-log-path
```

## Exam Tips
- kube-apiserver is a **static pod** — edit `/etc/kubernetes/manifests/kube-apiserver.yaml` and it auto-restarts.
- **Always add both volumeMounts AND volumes** — forgetting either causes apiserver to fail.
- If apiserver fails to restart: `sudo crictl logs $(sudo crictl ps -a | grep kube-apiserver | head -1 | awk '{print $1}')`
- **Never use `RequestResponse` level for secrets** — would log secret values in plaintext.
- Audit log format: one JSON object per line.
- Key fields: `user.username`, `user.groups`, `verb`, `objectRef.resource`, `objectRef.namespace`, `sourceIPs`, `responseStatus.code`.
- Backup manifest before editing: `sudo cp /etc/kubernetes/manifests/kube-apiserver.yaml ~/kube-apiserver.yaml.bak`
