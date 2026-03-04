# LAB-01 — Network Policies

**CKS Domain:** Cluster Setup (15%)

## Objective
Implement NetworkPolicies to enforce least-privilege pod communication. Understand default-deny patterns and selective allow rules.

## Background
By default, all pods in Kubernetes can communicate with all other pods across all namespaces. NetworkPolicy is a namespaced resource that restricts ingress and/or egress traffic at the pod level using label selectors. Requires a CNI that supports NetworkPolicy (Calico does).

## Tasks

### Part A — Setup test environment

1. Create namespace and deployments:
   ```bash
   kubectl create namespace shop
   kubectl create deployment frontend --image=nginx:alpine -n shop
   kubectl create deployment backend --image=nginx:alpine -n shop
   kubectl expose deployment frontend --port=80 -n shop
   kubectl expose deployment backend --port=80 -n shop
   ```

2. Create an "attacker" pod in the default namespace:
   ```bash
   kubectl run attacker --image=busybox:1.36 --restart=Never -- sleep 3600
   ```

3. Verify unrestricted access (get backend ClusterIP first):
   ```bash
   BACKEND_IP=$(kubectl get svc backend -n shop -o jsonpath='{.spec.clusterIP}')
   kubectl exec attacker -- wget -qO- --timeout=2 http://$BACKEND_IP
   ```
   Expected: HTML response (access allowed).

### Part B — Default deny ingress

4. Apply default-deny-all ingress to shop namespace:
   ```yaml
   # deny-all-ingress.yaml
   apiVersion: networking.k8s.io/v1
   kind: NetworkPolicy
   metadata:
     name: default-deny-ingress
     namespace: shop
   spec:
     podSelector: {}
     policyTypes:
     - Ingress
   ```
   ```bash
   kubectl apply -f deny-all-ingress.yaml
   ```

5. Verify attacker is now blocked:
   ```bash
   kubectl exec attacker -- wget -qO- --timeout=2 http://$BACKEND_IP
   ```
   Expected: timeout / connection refused.

### Part C — Allow specific ingress

6. Allow only frontend pods in shop namespace to reach backend on port 80:
   ```yaml
   # allow-frontend-to-backend.yaml
   apiVersion: networking.k8s.io/v1
   kind: NetworkPolicy
   metadata:
     name: allow-frontend-to-backend
     namespace: shop
   spec:
     podSelector:
       matchLabels:
         app: backend
     policyTypes:
     - Ingress
     ingress:
     - from:
       - podSelector:
           matchLabels:
             app: frontend
         namespaceSelector:
           matchLabels:
             kubernetes.io/metadata.name: shop
       ports:
       - protocol: TCP
         port: 80
   ```
   ```bash
   kubectl apply -f allow-frontend-to-backend.yaml
   ```

7. Test: frontend can reach backend:
   ```bash
   FRONTEND_POD=$(kubectl get pod -n shop -l app=frontend -o jsonpath='{.items[0].metadata.name}')
   kubectl exec -n shop $FRONTEND_POD -- wget -qO- --timeout=2 http://backend
   ```
   Expected: HTML (allowed).

8. Test: attacker still blocked:
   ```bash
   kubectl exec attacker -- wget -qO- --timeout=2 http://$BACKEND_IP
   ```
   Expected: timeout.

### Part D — Default deny egress + DNS exception

9. Apply default-deny egress (with DNS exception) to shop namespace:
   ```yaml
   # deny-all-egress.yaml
   apiVersion: networking.k8s.io/v1
   kind: NetworkPolicy
   metadata:
     name: default-deny-egress
     namespace: shop
   spec:
     podSelector: {}
     policyTypes:
     - Egress
     egress:
     - ports:
       - protocol: UDP
         port: 53
       - protocol: TCP
         port: 53
   ```
   ```bash
   kubectl apply -f deny-all-egress.yaml
   ```

10. Allow frontend egress to backend only:
    ```yaml
    # allow-frontend-egress.yaml
    apiVersion: networking.k8s.io/v1
    kind: NetworkPolicy
    metadata:
      name: allow-frontend-egress-to-backend
      namespace: shop
    spec:
      podSelector:
        matchLabels:
          app: frontend
      policyTypes:
      - Egress
      egress:
      - to:
        - podSelector:
            matchLabels:
              app: backend
        ports:
        - protocol: TCP
          port: 80
      - ports:
        - protocol: UDP
          port: 53
    ```
    ```bash
    kubectl apply -f allow-frontend-egress.yaml
    ```

11. Verify frontend cannot reach the internet:
    ```bash
    kubectl exec -n shop $FRONTEND_POD -- wget -qO- --timeout=2 http://1.1.1.1
    ```
    Expected: timeout.

### Part E — Block node metadata endpoint (cloud hardening practice)

12. Block egress to 169.254.169.254 (cloud metadata service) from shop namespace:
    ```yaml
    # block-metadata.yaml
    apiVersion: networking.k8s.io/v1
    kind: NetworkPolicy
    metadata:
      name: block-cloud-metadata
      namespace: shop
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
    ```
    ```bash
    kubectl apply -f block-metadata.yaml
    ```

## Validation
```bash
# Show all NetworkPolicies in shop namespace
kubectl get networkpolicy -n shop

# Attacker blocked from backend
kubectl exec attacker -- wget -qO- --timeout=2 http://$BACKEND_IP  # timeout

# Frontend allowed to backend
kubectl exec -n shop $FRONTEND_POD -- wget -qO- --timeout=2 http://backend  # 200 OK
```

## Exam Tips
- `podSelector: {}` (empty) matches ALL pods in the namespace.
- NetworkPolicies are **additive** — multiple policies are OR'd together.
- If no policy selects a pod, all traffic is allowed.
- Always test with `kubectl exec -- wget --timeout=2` after applying.
- Egress DNS exception is critical: without allowing port 53, DNS resolution breaks.
- `namespaceSelector` and `podSelector` in the same `from` entry = AND; in separate list entries = OR.
- The `ipBlock` `except` field blocks specific IPs within an allowed CIDR.
