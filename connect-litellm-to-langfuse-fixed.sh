#!/bin/bash

# Connect LiteLLM to Langfuse (Fixed)

set -e

echo "=================================="
echo "Connecting LiteLLM to Langfuse"
echo "=================================="

echo -e "\n[1/3] Creating Langfuse credentials secret..."

kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: langfuse-credentials
  namespace: default
type: Opaque
stringData:
  LANGFUSE_PUBLIC_KEY: "pk-lf-75aa5bd0-ced9-461a-9a8b-a6c2327bc0ed"
  LANGFUSE_SECRET_KEY: "sk-lf-bf1c3649-0b50-41d4-9a62-0b2aaf2cb69f"
  LANGFUSE_HOST: "http://langfuse-web.langfuse.svc.cluster.local:3000"
EOF

echo "✅ Secret created"

echo -e "\n[2/3] Checking current LiteLLM deployment..."

kubectl get deployment litellm -n default -o yaml > /tmp/litellm-backup.yaml
echo "✅ Backup saved to /tmp/litellm-backup.yaml"

echo -e "\n[3/3] Adding Langfuse environment variables to LiteLLM..."

# Patch the deployment using kubectl patch
kubectl patch deployment litellm -n default --type=json -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/env/-",
    "value": {
      "name": "LANGFUSE_PUBLIC_KEY",
      "valueFrom": {
        "secretKeyRef": {
          "name": "langfuse-credentials",
          "key": "LANGFUSE_PUBLIC_KEY"
        }
      }
    }
  },
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/env/-",
    "value": {
      "name": "LANGFUSE_SECRET_KEY",
      "valueFrom": {
        "secretKeyRef": {
          "name": "langfuse-credentials",
          "key": "LANGFUSE_SECRET_KEY"
        }
      }
    }
  },
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/env/-",
    "value": {
      "name": "LANGFUSE_HOST",
      "valueFrom": {
        "secretKeyRef": {
          "name": "langfuse-credentials",
          "key": "LANGFUSE_HOST"
        }
      }
    }
  }
]'

echo "✅ Environment variables added"

echo -e "\nWaiting for LiteLLM to restart..."
kubectl rollout status deployment/litellm -n default --timeout=2m

echo -e "\n=================================="
echo "✅ LiteLLM Connected to Langfuse!"
echo "=================================="

echo -e "\nTest it:"
echo "  1. Make a request through your LiteLLM proxy"
echo "  2. Check Langfuse UI at http://localhost:3000"
echo "  3. You should see the trace appear within seconds"

echo -e "\nTo verify LiteLLM has the credentials:"
echo "  kubectl exec -it deployment/litellm -n default -- env | grep LANGFUSE"

echo -e "\nTo see LiteLLM logs:"
echo "  kubectl logs -n default deployment/litellm --follow"
