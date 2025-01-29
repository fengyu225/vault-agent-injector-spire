# Vault Agent Injector with SPIRE Certificate Authentication

This guide demonstrates how to set up Vault Agent Injector using X.509 SVIDs issued by SPIRE for authentication with Vault. The Vault Agent Injector alters pod specifications to include Vault Agent containers that render Vault secrets to a shared memory volume.

## Overview

The Vault Agent Injector works by intercepting pod CREATE and UPDATE events in Kubernetes. The controller parses the event and looks for the metadata annotation `vault.hashicorp.com/agent-inject: true`. If found, the controller will alter the pod specification based on other annotations present.

### Key Components

- **SPIRE**: Issues X.509 SVIDs to workloads
- **spiffe-helper**: Sidecar container that fetches and updates SVIDs
- **vault-agent-injector**: Injects Vault Agent containers into pods
- **vault-agent**: Authenticates with Vault using SPIRE-issued certificates

### Supported Kubernetes Versions
- 1.31
- 1.30
- 1.29
- 1.28
- 1.27

## Setup Steps

### 1. Create Kubernetes Cluster and Install SPIRE

```bash
# Create Kind cluster
kind create cluster --config kind-config.yaml

# Deploy SPIRE components
kubectl apply -k certificate-auth/spire/

# Save SPIRE CA bundle for Vault configuration
kubectl get cm spire-bundle -n spire -o jsonpath='{.data.bundle\.crt}' > vault/certs/spire_ca.pem
```

### 2. Deploy Vault

```bash
# Start Vault
docker-compose up -d

# Get Vault IP and create service
VAULT_IP=$(docker inspect -f '{{range $network, $conf := .NetworkSettings.Networks}}{{if eq $network "kind"}}{{$conf.IPAddress}}{{end}}{{end}}' vault)
kubectl create namespace app
sed "s/VAULT_IP/$VAULT_IP/" certificate-auth/vault-service.yaml | kubectl apply -f -
```

### 3. Configure Vault

```bash
# Set Vault environment
export VAULT_ADDR='https://127.0.0.1:8200'
export VAULT_TOKEN='root'
export VAULT_SKIP_VERIFY=true

# Enable certificate authentication
vault auth enable cert

# Configure cert auth role
vault write auth/cert/certs/app \
    certificate=@vault/certs/spire_ca.pem \
    allowed_uri_sans="spiffe://example.org/workload/client" \
    policies="app-policy" \
    name_format="db-client" \
    display_name="app"

# Create policy
vault policy write app-policy certificate-auth/app-policy.hcl
```

### 4. Install Vault Agent Injector

```bash
# Add HashiCorp Helm repository
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

# Create namespace and install
kubectl create namespace vault-injector
helm install vault-injector hashicorp/vault \
    --namespace vault-injector \
    --values certificate-auth/vault-injector-values.yaml
```

## Requesting Secrets

There are two methods of configuring the Vault Agent containers to render secrets:

1. Using annotations
2. Using a configuration map containing Vault Agent configuration files

### Secrets via Annotations

To configure secret injection using annotations, provide:
- One or more secret annotations
- The Vault role used to access those secrets

Example format:
```yaml
vault.hashicorp.com/agent-inject-secret-<unique-name>: /path/to/secret
vault.hashicorp.com/role: 'app'
```

Multiple secrets example:
```yaml
vault.hashicorp.com/agent-inject-secret-foo: database/roles/app
vault.hashicorp.com/agent-inject-secret-bar: consul/creds/app
vault.hashicorp.com/role: 'app'
```

### Secret Templates

Vault Agent uses Consul Template for rendering secrets. Custom templates can be defined using:

```yaml
vault.hashicorp.com/agent-inject-template-<unique-name>: |
  {{- with secret "database/creds/db-app" -}}
  postgres://{{ .Data.username }}:{{ .Data.password }}@postgres:5432/mydb?sslmode=disable
  {{- end }}
```

## Vault Agent Features

### Secret Volume Mounting
- Mounts volume `vault-secrets` at `/vault/secrets`
- Contains plaintext secrets specified by annotations

### Container Injection
- Injects init container for initial secret fetch
- Injects sidecar container for runtime secret updates

### Dynamic Secret Updates
- Vault Agent sidecar continuously updates `/vault/secrets` when secret values change
- Automatic certificate rotation and token renewal

### Directory Structure
- `/vault/secrets/`: Contains rendered secrets
- `/vault/config/`: Vault Agent configuration
- `/vault/file/`: Persistent storage for token cache
- `/vault/logs/`: Agent logs for debugging

## Monitoring and Telemetry

The Vault Agent Injector provides Prometheus metrics:

- `vault_agent_injector_request_queue_length`: Pending webhook requests
- `vault_agent_injector_request_processing_duration_ms`: Request processing times
- `vault_agent_injector_injections_by_namespace_total`: Injection counts by namespace
- `vault_agent_injector_failed_injections_by_namespace_total`: Failed injection counts

To enable metrics collection, set `injector.metrics.enabled=true` in the Helm chart.

## Troubleshooting

To debug authentication issues:
1. Check SPIRE registration status
2. Verify SVID issuance in SPIFFE Helper logs
3. Check Vault Agent logs for authentication errors
4. Verify policy permissions in Vault