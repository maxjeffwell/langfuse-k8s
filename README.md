# Langfuse K8s

Kubernetes deployment configuration for [Langfuse](https://langfuse.com) LLM observability, deployed via Helm with external Neon PostgreSQL, shared Redis, in-cluster ClickHouse, and MinIO blob storage. Integrates with LiteLLM to trace all LLM requests across the portfolio platform.

**URL:** `https://langfuse.el-jefe.me` | **Namespace:** `langfuse`

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  langfuse namespace                                     │
│  ┌──────────────┐  ┌─────────────┐  ┌───────────────┐  │
│  │ Langfuse Web │  │ ClickHouse  │  │ MinIO (S3)    │  │
│  │ + Worker     │  │ (analytics) │  │ (blob storage)│  │
│  │ port 3000    │  │ 2Gi storage │  │               │  │
│  └──────┬───────┘  └─────────────┘  └───────────────┘  │
└─────────┼───────────────────────────────────────────────┘
          │
    ┌─────▼─────────────────────────────────────────┐
    │  External Services                             │
    │  ├── Neon PostgreSQL (metadata, sslmode=require)│
    │  └── Shared Redis (default namespace)          │
    └────────────────────────────────────────────────┘
```

## Components

| Component | Type | Purpose |
|:----------|:-----|:--------|
| **Langfuse Web + Worker** | Helm (in-cluster) | UI, API, trace processing |
| **ClickHouse** | Helm (in-cluster) | Analytics queries, 2Gi storage |
| **MinIO** | Helm (in-cluster) | S3-compatible blob storage |
| **PostgreSQL** | Neon (external) | Metadata and configuration |
| **Redis** | Shared cluster (external) | Session and cache management |

## Prerequisites

- Kubernetes cluster with Helm 3+
- External Neon PostgreSQL database with a `langfuse` database created
- Shared Redis accessible at `redis.default.svc.cluster.local`
- Secrets provisioned via Doppler + External Secrets Operator (or created manually)

## Secrets

All secrets are managed via External Secrets Operator syncing from Doppler:

| Secret | Keys | Purpose |
|:-------|:-----|:--------|
| `langfuse-salt` | `salt` | Data encryption salt |
| `langfuse-encryption` | `encryption-key` | Encryption key |
| `langfuse-nextauth` | `nextauth-secret` | NextAuth.js session secret |
| `langfuse-postgresql` | `postgres-password` | Neon database credential |
| `redis-secrets` | `redis-password` | Shared Redis credential |
| `langfuse-clickhouse` | `admin-password` | ClickHouse admin password |
| `langfuse-s3` | `root-user`, `root-password` | MinIO credentials |

## Deployment

```bash
# Install/upgrade using the stable values
helm upgrade --install langfuse langfuse/langfuse \
  -n langfuse --create-namespace \
  -f langfuse-values-stable.yaml
```

### Key Helm Values

```yaml
# External PostgreSQL (Neon)
postgresql:
  deploy: false
  host: "<neon-endpoint>"
  auth:
    existingSecret: langfuse-postgresql

# External Redis (shared)
redis:
  deploy: false
  host: "redis.default.svc.cluster.local"
  auth:
    existingSecret: redis-secrets

# In-cluster ClickHouse
clickhouse:
  deploy: true
  persistence:
    size: 2Gi
  resources:
    requests: { memory: "1Gi", cpu: "100m" }
    limits: { memory: "4Gi", cpu: "1" }
  startupProbe:
    enabled: true
    failureThreshold: 30  # 5 min for large dataset loading

# In-cluster MinIO
s3:
  deploy: true
  auth:
    existingSecret: langfuse-s3
```

## LiteLLM Integration

LiteLLM routes Claude and Groq requests and sends callbacks to Langfuse for trace collection.

**Configure LiteLLM:**

```yaml
# litellm config
litellm_settings:
  success_callback: ["langfuse"]
  failure_callback: ["langfuse"]
```

**Environment variables for LiteLLM:**

```bash
LANGFUSE_PUBLIC_KEY=pk-lf-...
LANGFUSE_SECRET_KEY=sk-lf-...
LANGFUSE_HOST=http://langfuse-web.langfuse.svc.cluster.local:3000
```

See `litellm-integration.md` for the full step-by-step guide.

## ClickHouse Startup

ClickHouse can load large datasets (3GB+) on startup. The startup probe allows up to 5 minutes (`failureThreshold: 30 × periodSeconds: 10`) before liveness checks begin. Without this, Kubernetes kills the container during initial data loading.

## Network Policy

Redis access is restricted via NetworkPolicy — only backend components and Langfuse workers can reach port 6379. See `redis-np.yaml`.

## Files

| File | Purpose |
|:-----|:--------|
| `langfuse-values-stable.yaml` | Production Helm values |
| `litellm-integration.md` | LiteLLM → Langfuse integration guide |
| `litellm-config-with-langfuse.yaml` | LiteLLM ConfigMap with callbacks enabled |
| `clickhouse-probe-fix.yaml` | ClickHouse probe configuration |
| `redis-np.yaml` | Redis NetworkPolicy |
| `connect-litellm-to-langfuse.sh` | Script to inject Langfuse credentials into LiteLLM |
| `enable-langfuse-callbacks.sh` | Enable Langfuse callbacks in LiteLLM config |

## Verification

```bash
# Check pod status
kubectl get pods -n langfuse

# Port-forward to UI
kubectl port-forward -n langfuse svc/langfuse 3000:3000

# Open http://localhost:3000
```

## What Langfuse Captures

| Data | Description |
|:-----|:------------|
| **Traces** | Full request lifecycle with timing |
| **Generations** | Model inputs, outputs, and parameters |
| **Token usage** | Prompt and completion token counts |
| **Latency** | End-to-end and per-generation timing |
| **Cost** | Estimated cost per model/request |
| **Sessions** | Grouped multi-turn conversations |
| **Errors** | Failed requests with error details |
