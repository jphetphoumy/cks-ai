# LAB-09 — Falco Runtime Security

**CKS Domain:** Monitoring, Logging and Runtime Security (20%)

## Objective
Install Falco, understand built-in rules, write custom rules, and use Falco to detect malicious container behavior at runtime.

## Background
Falco is a CNCF runtime security tool that hooks into the Linux kernel via eBPF and evaluates syscall events against a rule engine. It's the primary runtime threat detection tool in CKS.

**Key concepts:**
- Rules: condition + output + priority
- Default rules cover: shell in container, sensitive file reads, package manager execution, privilege escalation
- Falco logs alerts to journald

## Tasks

### Part A — Install Falco on both nodes

1. On **k8s-master (192.168.1.40)**:
   ```bash
   curl -fsSL https://falco.org/repo/falcosecurity-packages.asc | \
     sudo gpg --dearmor -o /usr/share/keyrings/falco-archive-keyring.gpg
   echo "deb [signed-by=/usr/share/keyrings/falco-archive-keyring.gpg] \
     https://download.falco.org/packages/deb stable main" | \
     sudo tee /etc/apt/sources.list.d/falcosecurity.list
   sudo apt update && sudo apt install -y falco
   sudo systemctl enable --now falco
   sudo systemctl status falco
   ```

2. On **k8s-agent (192.168.1.41)**:
   ```bash
   ssh 192.168.1.41 "
   curl -fsSL https://falco.org/repo/falcosecurity-packages.asc | \
     sudo gpg --dearmor -o /usr/share/keyrings/falco-archive-keyring.gpg && \
   echo 'deb [signed-by=/usr/share/keyrings/falco-archive-keyring.gpg] \
     https://download.falco.org/packages/deb stable main' | \
     sudo tee /etc/apt/sources.list.d/falcosecurity.list && \
   sudo apt update && sudo apt install -y falco && \
   sudo systemctl enable --now falco
   "
   ```

3. Verify Falco running on both nodes:
   ```bash
   sudo systemctl status falco
   ssh 192.168.1.41 "sudo systemctl is-active falco"
   ```

### Part B — Trigger built-in rules

4. Start watching Falco alerts:
   ```bash
   sudo journalctl -fu falco &
   ```

5. Deploy a test pod:
   ```bash
   kubectl run trigger-pod --image=ubuntu:22.04 --restart=Never -- sleep 3600
   kubectl wait --for=condition=Ready pod/trigger-pod
   ```

6. Trigger "Terminal shell in container":
   ```bash
   kubectl exec -it trigger-pod -- /bin/bash
   # Just open it — Falco alerts immediately. Then exit.
   ```

7. Trigger "Read sensitive file untrusted":
   ```bash
   kubectl exec trigger-pod -- cat /etc/shadow
   ```

8. Trigger "Launch Package Management Process in Container":
   ```bash
   kubectl exec trigger-pod -- apt-get update
   ```

9. Trigger "Write below /etc":
   ```bash
   kubectl exec trigger-pod -- touch /etc/evil-file
   ```

10. Observe alert format in journal:
    ```bash
    sudo journalctl -u falco --since "5 minutes ago" | grep -E "Warning|Critical"
    ```
    Format: `timestamp severity rulename (evt.type=...) k8s.pod.name=... proc.name=... fd.name=...`

### Part C — Write custom Falco rules

11. Create a custom rules file:
    ```bash
    sudo tee /etc/falco/rules.d/custom-rules.yaml << 'EOF'
    # Rule 1: Alert when nginx container writes to /tmp
    - rule: Nginx writes to /tmp
      desc: Detects when an nginx container writes any file to /tmp
      condition: >
        evt.type in (open, openat, openat2) and
        evt.is_open_write = true and
        container.image.repository contains "nginx" and
        fd.name startswith /tmp
      output: >
        Nginx container writing to /tmp
        (user=%user.name pod=%k8s.pod.name container=%container.name
        image=%container.image.repository file=%fd.name)
      priority: WARNING
      tags: [custom, nginx]

    # Rule 2: Detect interactive shell spawned via kubectl exec
    - rule: Kubectl exec detected
      desc: Alert when kubectl exec spawns a shell in a container
      condition: >
        spawned_process and
        container and
        proc.name in (sh, bash, ash, dash, zsh) and
        proc.pname in (runc, containerd-shim, docker-runc)
      output: >
        Shell spawned via kubectl exec
        (user=%user.name pod=%k8s.pod.name container=%container.name
        shell=%proc.name parent=%proc.pname)
      priority: WARNING
      tags: [custom, exec]

    # Rule 3: Detect privileged container start
    - rule: Privileged container started
      desc: Alert when a privileged container starts
      condition: >
        container_started and container.privileged = true
      output: >
        Privileged container started
        (pod=%k8s.pod.name container=%container.name image=%container.image.repository)
      priority: CRITICAL
      tags: [custom, privilege]
    EOF
    ```

12. Reload Falco rules:
    ```bash
    sudo kill -1 $(pidof falco)
    # or:
    sudo systemctl reload falco
    ```

13. Verify custom rules loaded:
    ```bash
    sudo journalctl -u falco | grep -E "Loading rules|custom-rules"
    ```

14. Trigger the nginx write rule:
    ```bash
    kubectl run nginx-test --image=nginx:alpine --restart=Never -- sleep 3600
    kubectl wait --for=condition=Ready pod/nginx-test
    kubectl exec nginx-test -- touch /tmp/nginx-evil-file
    sudo journalctl -u falco --since "1 minute ago" | grep "Nginx writes to /tmp"
    ```

### Part D — Investigate suspicious activity

15. Filter logs for a specific pod:
    ```bash
    sudo journalctl -u falco | grep "k8s.pod.name=trigger-pod"
    ```

16. Filter by rule name:
    ```bash
    sudo journalctl -u falco | grep "Terminal shell in container"
    ```

17. Find all CRITICAL events:
    ```bash
    sudo journalctl -u falco | grep "Critical"
    ```

18. Get timeline for a pod:
    ```bash
    sudo journalctl -u falco --since "10 minutes ago" | grep "trigger-pod" | sort
    ```

### Part E — Exam scenario

19. A suspicious pod is active. Investigate with Falco:
    ```bash
    kubectl run attacker-pod --image=ubuntu:22.04 --restart=Never -- sleep 3600
    kubectl wait --for=condition=Ready pod/attacker-pod
    kubectl exec attacker-pod -- cat /etc/shadow
    kubectl exec attacker-pod -- bash -c "apt-get install -y netcat-openbsd 2>/dev/null; true"

    # Investigate
    sudo journalctl -u falco | grep "attacker-pod" | tail -20
    ```

## Validation
```bash
# Falco active on both nodes
sudo systemctl is-active falco  # active
ssh 192.168.1.41 "sudo systemctl is-active falco"  # active

# Alerts generated on sensitive file read
kubectl exec trigger-pod -- cat /etc/shadow
sudo journalctl -u falco --since "30 seconds ago" | grep shadow

# Custom rules loaded
sudo journalctl -u falco | grep "Loading rules from.*custom"
```

## Exam Tips
- Default rules: `/etc/falco/falco_rules.yaml` — **never edit directly**.
- Custom rules: `/etc/falco/rules.d/` — put your rules here.
- Rule structure: `rule`, `desc`, `condition`, `output`, `priority`.
- Priority levels: DEBUG < INFO < NOTICE < WARNING < ERROR < CRITICAL < ALERT < EMERGENCY.
- Reload rules: `sudo kill -1 $(pidof falco)` or `sudo systemctl reload falco`.
- Key Falco fields: `container.name`, `k8s.pod.name`, `proc.name`, `fd.name`, `user.name`, `container.image.repository`.
- In exam: filter Falco logs with `journalctl -u falco | grep <pod-name>`.
- Falco logs to journald by default.
