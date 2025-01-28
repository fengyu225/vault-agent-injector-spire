#!/bin/bash

mkdir -p vault/config vault/data vault/certs

kind create cluster --config kind-config.yaml

kubectl create namespace demo
kubectl create namespace vault-system

kubectl apply -f rbac-setup.yaml

VAULT_IP=$(docker inspect -f '{{range $network, $conf := .NetworkSettings.Networks}}{{if eq $network "kind"}}{{$conf.IPAddress}}{{end}}{{end}}' vault)

sed "s/VAULT_IP/$VAULT_IP/" vault-service.yaml | kubectl apply -f -

export VAULT_ADDR='https://127.0.0.1:8200'
export VAULT_TOKEN='root'
export VAULT_SKIP_VERIFY=true

vault auth enable kubernetes

KIND_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' vault-demo-control-plane)

export KUBE_HOST=$(kubectl config view -o jsonpath='{.clusters[0].cluster.server}')

vault write auth/kubernetes/config \
    kubernetes_host="https://$KIND_IP:6443" \
    token_reviewer_jwt="$(kubectl get secret vault-auth-token -n demo -o jsonpath='{.data.token}' | base64 -d)" \
    kubernetes_ca_cert="$(kubectl get secret vault-auth-token -n demo -o jsonpath='{.data.ca\.crt}' | base64 -d)" \
    issuer="https://kubernetes.default.svc.cluster.local"

vault secrets enable -path=kv kv-v2
vault kv put kv/demo/config username="testuser" password="testpass123"

vault policy write demo-policy - <<EOF
path "kv/data/demo/*" {
  capabilities = ["read"]
}
EOF

vault write auth/kubernetes/role/demo-role \
    bound_service_account_names=vault-auth \
    bound_service_account_namespaces=demo \
    policies=demo-policy \
    ttl=24h

helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

cat > vault-injector-values.yaml <<EOF
injector:
  enabled: true

externalVaultAddr: "https://vault.demo:8200"

securityContext:
  container:
    seccompProfile:
      type: "RuntimeDefault"
    capabilities:
      drop: ["ALL"]
    privileged: false
    allowPrivilegeEscalation: false
EOF

helm install vault hashicorp/vault \
  -f vault-injector-values.yaml \
  --namespace vault-system \
  --set "global.externalVaultAddr=https://vault.demo:8200"

sleep 10
echo "Waiting for vault-agent-injector to be ready..."
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=vault-agent-injector -n vault-system --timeout=120s

echo "Verifying webhook configuration..."
kubectl get mutatingwebhookconfigurations vault-agent-injector-cfg

kubectl apply -f test-deployment.yaml

echo "Setup complete! Wait a few moments for all pods to start, then check the status with:"
echo "kubectl get pods -n demo"
echo "kubectl logs -n demo <pod-name> -c vault-agent-init"