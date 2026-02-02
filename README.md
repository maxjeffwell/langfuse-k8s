# Langfuse Installation for Kubernetes

This directory contains everything you need to install Langfuse using your existing PostgreSQL on your Kubernetes cluster and integrate it with your existing LiteLLM proxy.

## 📁 Files

- `setup-with-existing-postgres.sh` - **START HERE** - Discovers your PostgreSQL and configures Langfuse
- `install-langfuse-only.sh` - Installs Langfuse (run after setup script)
- `langfuse-values.yaml` - Helm chart configuration for Langfuse
- `litellm-integration.md` - Guide to connect LiteLLM with Langfuse
- `postgres.yaml` - (Not needed - you have PostgreSQL already)
- `install.sh` - (Not needed - use the scripts above instead)
- `README.md` - This file

## 🚀 Quick Start (Using Your Existing PostgreSQL)

### 1. Copy files to your VPS

From your local machine:
```bash
scp -r /home/maxjeffwell/langfuse-k8s maxjeffwell@86.48.29.183:~/
```

### 2. SSH into your VPS

```bash
ssh maxjeffwell@86.48.29.183
cd ~/langfuse-k8s
```

### 3. Run the setup script

This will automatically:
- Find your existing PostgreSQL in the default namespace
- Extract credentials from secrets
- Create a new `langfuse` database
- Generate secure secrets
- Update langfuse-values.yaml with everything

```bash
chmod +x setup-with-existing-postgres.sh
./setup-with-existing-postgres.sh
```

The script will guide you through the process and handle any missing information.

### 4. Install Langfuse

```bash
chmod +x install-langfuse-only.sh
./install-langfuse-only.sh
```

This installs Langfuse using your existing PostgreSQL.

### 5. Access Langfuse

Port forward to access locally:
```bash
kubectl port-forward -n langfuse svc/langfuse 3000:3000
```

Then open http://localhost:3000 in your browser.

Or expose via NodePort (edit `langfuse-values.yaml` and set `service.type: NodePort`).

### 6. Connect LiteLLM

Follow the instructions in `litellm-integration.md` to connect your existing LiteLLM proxy to Langfuse.

## 🔍 Verification

Check that everything is running:
```bash
kubectl get pods -n langfuse
kubectl get svc -n langfuse
```

You should see:
- `postgres-0` - Running
- `langfuse-xxx` - Running

## 📊 Usage

1. Create a Langfuse account at http://localhost:3000
2. Create a new project
3. Get API keys from Settings → API Keys
4. Add keys to your LiteLLM configuration
5. Start seeing traces in Langfuse!

## 🛠️ Troubleshooting

**PostgreSQL not starting?**
```bash
kubectl logs -n langfuse postgres-0
kubectl describe pod -n langfuse postgres-0
```

**Langfuse not starting?**
```bash
kubectl logs -n langfuse -l app.kubernetes.io/name=langfuse
```

**Can't connect to database?**
- Check that DATABASE_URL password matches postgres.yaml
- Verify PostgreSQL service: `kubectl get svc -n langfuse postgres`

**Need to uninstall?**
```bash
helm uninstall langfuse -n langfuse
kubectl delete -f postgres.yaml
kubectl delete pvc postgres-pvc -n langfuse  # This deletes the data!
```

## 📚 Resources

- [Langfuse Docs](https://langfuse.com/docs)
- [LiteLLM Docs](https://docs.litellm.ai)
- [Langfuse + LiteLLM Integration](https://langfuse.com/docs/integrations/litellm)
