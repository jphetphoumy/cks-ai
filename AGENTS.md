# About this repository

This repository is an ai tutor driven workflow to learn about CKS ( Certificate Kubernetes Security )

The user have pass the CKA last week.

The user only have 3 Days to learn enough to have the CKS.

Here the learning topics you need to teach : 

**Cluster Setup (15%)**
    - Use Network security policies to restrict cluster level access
    - Use CIS benchmark to review the security configuration of Kubernetes components (etcd, kubelet, kubedns, kubeapi)
    - Properly set up Ingress with TLS
    - Protect node metadata and endpoints
    - Verify platform binaries before deploying
**Cluster Hardening (15%)**
    - Use Role Based Access Controls to minimize exposure
    - Exercise caution in using service accounts e.g. disable defaults, minimize permissions on newly created ones
    - Restrict access to Kubernetes API
    - Upgrade Kubernetes to avoid vulnerabilities
**System Hardening (10%)**
    - Minimize host OS footprint (reduce attack surface)
    - Using least-privilege identity and access management
    - Minimize external access to the network
    - Appropriately use kernel hardening tools such as AppArmor, seccomp
**Minimize Microservice Vulnerabilities (20%)**
    - Use appropriate pod security standards
    - Manage Kubernetes secrets
    - Understand and implement isolation techniques (multi-tenancy, sandboxed containers, etc.)
    - Implement Pod-to-Pod encryption (Cilium, Istio)
**Supply Chain Security (20%)**
    - Minimize base image footprint
    - Understand your supply chain (e.g. SBOM, CI/CD, artifact repositories)
    - Secure your supply chain (permitted registries, sign and validate artifacts, etc.)
    - Perform static analysis of user workloads and container images (e.g. Kubesec, KubeLinter)
**Monitoring, Logging and Runtime Security (20%)**
    - Perform behavioral analytics to detect malicious activities
    - Detect threats within physical infrastructure, apps, networks, data, users and workloads
    - Investigate and identify phases of attack and bad actors within the environment
    - Ensure immutability of containers at runtime
    - Use Kubernetes audit logs to monitor access

## Your Goal

A @PLAN.md as been created before to drive the learning for the CKS.

Base on the PLAN.md, do a focus learning with the user to make them pass the CKS.

All the labs are in the labs folder.

You can access the lab as my user and use sudo on the remote server.
The node addresses and SSH user live in `nodes.env` at the repo root (gitignored,
copied from `nodes.env.example`). Source it — `. ./nodes.env` — then use
`$MASTER_IP`, `$AGENT_IP` and `$SSH_USER`. Never hardcode the real addresses in
tracked files.
The Two servers are VM IaC based, if they break we can recreate them

Using the knowledge you have about my current skill, suggest the lab I need to learn.

Check the roadmap completion ( If the roadmap doesn't exist, create it )

The cluster should be ready to be use with calico

Make sure to use the `cks-setup` skill to check the current state of the cluster
