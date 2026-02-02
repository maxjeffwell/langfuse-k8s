# Integrating LiteLLM with Langfuse

This guide shows how to connect your existing LiteLLM proxy to Langfuse for observability.

## Overview

LiteLLM will automatically send traces to Langfuse for:
- All API calls through the proxy
- Token usage and costs
- Latency metrics
- Error tracking
- Model performance comparison

## Step 1: Get Langfuse API Keys

1. Access Langfuse UI:
   ```bash
   kubectl port-forward -n langfuse svc/langfuse 3000:3000
   ```

2. Open http://localhost:3000 in your browser

3. Create an account and a new project

4. Go to **Settings → API Keys**

5. Click **"Create new API key"** and note down:
   - `Public Key` (starts with `pk-lf-...`)
   - `Secret Key` (starts with `sk-lf-...`)

## Step 2: Configure LiteLLM

You need to add Langfuse configuration to your LiteLLM deployment. There are two methods:

### Method A: Using ConfigMap/Environment Variables

Add these environment variables to your LiteLLM deployment:

```yaml
env:
  - name: LANGFUSE_PUBLIC_KEY
    value: "pk-lf-your-public-key-here"
  - name: LANGFUSE_SECRET_KEY
    valueFrom:
      secretKeyRef:
        name: litellm-secrets
        key: langfuse-secret-key
  - name: LANGFUSE_HOST
    value: "http://langfuse.langfuse.svc.cluster.local:3000"
```

Create the secret:
```bash
kubectl create secret generic litellm-secrets \
  -n <your-litellm-namespace> \
  --from-literal=langfuse-secret-key='sk-lf-your-secret-key-here'
```

### Method B: Using LiteLLM Config File

If you're using a `litellm_config.yaml`, add this section:

```yaml
# litellm_config.yaml
model_list:
  - model_name: gpt-4
    litellm_params:
      model: openai/gpt-4
      api_key: os.environ/OPENAI_API_KEY
  # ... your other models ...

# Add Langfuse configuration
litellm_settings:
  success_callback: ["langfuse"]
  failure_callback: ["langfuse"]

  # Langfuse credentials
  langfuse_public_key: os.environ/LANGFUSE_PUBLIC_KEY
  langfuse_secret_key: os.environ/LANGFUSE_SECRET_KEY
  langfuse_host: "http://langfuse.langfuse.svc.cluster.local:3000"
```

Then update your LiteLLM deployment to use this config:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: litellm-config
  namespace: <your-namespace>
data:
  config.yaml: |
    # paste your litellm_config.yaml here
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: litellm
spec:
  template:
    spec:
      containers:
      - name: litellm
        volumeMounts:
        - name: config
          mountPath: /app/config.yaml
          subPath: config.yaml
        command:
          - litellm
          - --config
          - /app/config.yaml
      volumes:
      - name: config
        configMap:
          name: litellm-config
```

## Step 3: Restart LiteLLM

```bash
kubectl rollout restart deployment litellm -n <your-litellm-namespace>
```

## Step 4: Verify Integration

1. Make a test request through your LiteLLM proxy:
   ```bash
   curl http://your-litellm-proxy/v1/chat/completions \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer your-litellm-key" \
     -d '{
       "model": "gpt-4",
       "messages": [{"role": "user", "content": "Hello!"}]
     }'
   ```

2. Check Langfuse UI - you should see the trace appear within seconds

3. Check LiteLLM logs for any errors:
   ```bash
   kubectl logs -n <your-namespace> -l app=litellm --tail=50
   ```

## What You'll See in Langfuse

- **Traces**: Each request with full context
- **Generations**: Model outputs and inputs
- **Scores**: Token usage, latency
- **Sessions**: Grouped conversations
- **Users**: Track usage by API key/user

## Benefits

✅ **Model Comparison**: Compare performance across different models
✅ **Cost Tracking**: See costs per model, user, or project
✅ **Debugging**: Full request/response logs with errors
✅ **Analytics**: Usage patterns and trends
✅ **A/B Testing**: Compare prompt variations

## Troubleshooting

**Traces not appearing?**
- Check LiteLLM logs for Langfuse errors
- Verify network connectivity: `kubectl exec -it <litellm-pod> -- curl http://langfuse.langfuse.svc.cluster.local:3000`
- Confirm API keys are correct in Langfuse UI

**High latency?**
- Langfuse logging is async and shouldn't add latency
- Check if LiteLLM is waiting for Langfuse (shouldn't happen)
- Consider using batch mode in LiteLLM config

**Want to disable for specific models?**
```yaml
model_list:
  - model_name: gpt-4-no-logging
    litellm_params:
      model: openai/gpt-4
      success_callback: []  # Disable callbacks for this model
```

## Next Steps

- Set up alerts in Langfuse for high costs or errors
- Create custom dashboards
- Use Langfuse SDK in your applications for fine-grained tracking
- Explore prompt management features
