{
  description = "CKS (Certified Kubernetes Security) lab environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          name = "cks-lab";

          packages = with pkgs; [
            # Kubernetes
            kubectl
            kubernetes-helm
            kubeseal

            # Security scanning
            trivy
            cosign

            # TLS / certs
            openssl
            cfssl

            # Utilities
            jq
            yq-go
            python3
            curl
            wget
          ];

          shellHook = ''
            export KUBECONFIG="$HOME/.kube/config"
            echo "CKS lab environment ready"
            echo "kubectl: $(kubectl version --client --short 2>/dev/null)"
            echo "helm:    $(helm version --short 2>/dev/null)"
            echo "trivy:   $(trivy --version 2>/dev/null | head -1)"
            echo "cosign:  $(cosign version 2>/dev/null | head -1)"
          '';
        };
      }
    );
}
