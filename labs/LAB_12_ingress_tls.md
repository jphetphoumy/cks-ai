# LAB-12 — Ingress with TLS

**CKS Domain:** Cluster Setup (15%)

## Objective
Set up an Ingress with TLS termination using a self-signed certificate. Create TLS secrets and configure Ingress resources.

## Background
Ingress exposes HTTP/HTTPS routes from outside the cluster to services inside. TLS termination at the Ingress means HTTPS is handled by the controller; traffic to the backend is HTTP.

**Prerequisites:** An Ingress controller must be installed.

## Tasks

### Part A — Install nginx ingress controller

1. Install nginx ingress controller (baremetal):
   ```bash
   kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.0/deploy/static/provider/baremetal/deploy.yaml
   ```

2. Wait for the controller to be ready:
   ```bash
   kubectl wait --namespace ingress-nginx \
     --for=condition=ready pod \
     --selector=app.kubernetes.io/component=controller \
     --timeout=120s
   ```

3. Get the NodePort:
   ```bash
   kubectl get svc -n ingress-nginx ingress-nginx-controller
   ```

### Part B — Generate TLS certificate

4. Generate a self-signed cert and key:
   ```bash
   openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
     -keyout tls.key -out tls.crt \
     -subj "/CN=myapp.example.com/O=myapp" \
     -addext "subjectAltName=DNS:myapp.example.com"
   ```

5. Verify the certificate:
   ```bash
   openssl x509 -in tls.crt -noout -text | grep -E "CN|Subject|DNS"
   ```

6. Create a Kubernetes TLS secret:
   ```bash
   kubectl create secret tls myapp-tls \
     --cert=tls.crt \
     --key=tls.key \
     -n default
   ```

7. Verify the secret type:
   ```bash
   kubectl get secret myapp-tls -o jsonpath='{.type}'
   # kubernetes.io/tls
   ```

### Part C — Deploy application and Ingress

8. Deploy a simple app:
   ```bash
   kubectl create deployment myapp --image=nginx:alpine
   kubectl expose deployment myapp --port=80
   ```

9. Create the Ingress with TLS:
   ```yaml
   # ingress-tls.yaml
   apiVersion: networking.k8s.io/v1
   kind: Ingress
   metadata:
     name: myapp-ingress
     annotations:
       nginx.ingress.kubernetes.io/ssl-redirect: "true"
   spec:
     ingressClassName: nginx
     tls:
     - hosts:
       - myapp.example.com
       secretName: myapp-tls
     rules:
     - host: myapp.example.com
       http:
         paths:
         - path: /
           pathType: Prefix
           backend:
             service:
               name: myapp
               port:
                 number: 80
   ```
   ```bash
   kubectl apply -f ingress-tls.yaml
   kubectl get ingress myapp-ingress
   ```

### Part D — Test TLS access

10. Get connection details:
    ```bash
    HTTPS_PORT=$(kubectl get svc -n ingress-nginx ingress-nginx-controller \
      -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')
    NODE_IP="$AGENT_IP"
    echo "HTTPS port: $HTTPS_PORT"
    ```

11. Test HTTPS access:
    ```bash
    curl -k --resolve myapp.example.com:$HTTPS_PORT:$NODE_IP \
      https://myapp.example.com:$HTTPS_PORT/
    ```
    Expected: nginx welcome page.

12. Verify the certificate served:
    ```bash
    openssl s_client -connect $NODE_IP:$HTTPS_PORT \
      -servername myapp.example.com 2>/dev/null | \
      openssl x509 -noout -subject -issuer
    ```

13. Test HTTP redirects to HTTPS:
    ```bash
    HTTP_PORT=$(kubectl get svc -n ingress-nginx ingress-nginx-controller \
      -o jsonpath='{.spec.ports[?(@.name=="http")].nodePort}')
    curl -v --resolve myapp.example.com:$HTTP_PORT:$NODE_IP \
      http://myapp.example.com:$HTTP_PORT/ 2>&1 | grep -E "< HTTP|Location"
    ```
    Expected: 308 redirect to https.

### Part E — Exam scenario: TLS for existing service

14. Add TLS to an existing service in another namespace:
    ```bash
    kubectl create namespace prod
    kubectl create deployment api-service --image=nginx:alpine -n prod
    kubectl expose deployment api-service --port=80 -n prod

    # Generate cert
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
      -keyout api-tls.key -out api-tls.crt \
      -subj "/CN=api.example.com/O=api" \
      -addext "subjectAltName=DNS:api.example.com"

    # Create secret IN THE SAME NAMESPACE as the Ingress
    kubectl create secret tls api-tls \
      --cert=api-tls.crt --key=api-tls.key -n prod
    ```

15. Create the Ingress in `prod` namespace:
    ```yaml
    # api-ingress.yaml
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: api-ingress
      namespace: prod
    spec:
      ingressClassName: nginx
      tls:
      - hosts:
        - api.example.com
        secretName: api-tls
      rules:
      - host: api.example.com
        http:
          paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: api-service
                port:
                  number: 80
    ```
    ```bash
    kubectl apply -f api-ingress.yaml
    ```

## Validation
```bash
# TLS secret type correct
kubectl get secret myapp-tls -o jsonpath='{.type}'  # kubernetes.io/tls

# Ingress configured with TLS
kubectl get ingress myapp-ingress -o yaml | grep -E "tls|secretName"

# HTTPS returns content
curl -k --resolve myapp.example.com:$HTTPS_PORT:$NODE_IP \
  https://myapp.example.com:$HTTPS_PORT/ | grep -i welcome
```

## Exam Tips
- TLS secret type must be `kubernetes.io/tls` — `kubectl create secret tls` creates this automatically.
- **Secret MUST be in the SAME namespace as the Ingress**.
- `spec.tls[].secretName` references the TLS secret name.
- `spec.tls[].hosts` must match `spec.rules[].host`.
- In exam: cert and key files are usually provided — create the secret and Ingress from them.
- openssl command to memorize: `openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt -subj "/CN=<host>"`
- `ingressClassName: nginx` is required for K8s 1.18+.
- `nginx.ingress.kubernetes.io/ssl-redirect: "true"` enforces HTTPS.
