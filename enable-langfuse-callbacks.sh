#!/bin/bash

# Enable Langfuse callbacks in LiteLLM

set -e

echo "=================================="
echo "Enabling Langfuse Callbacks"
echo "=================================="

echo -e "\n[1/3] Backing up current config..."
kubectl get configmap litellm-config -n default -o yaml > /tmp/litellm-config-backup.yaml
echo "✅ Backup saved to /tmp/litellm-config-backup.yaml"

echo -e "\n[2/3] Applying updated config with Langfuse callbacks..."
kubectl apply -f litellm-config-with-langfuse.yaml
echo "✅ Config updated"

echo -e "\n[3/3] Restarting LiteLLM to apply changes..."
kubectl rollout restart deployment/litellm -n default
kubectl rollout status deployment/litellm -n default --timeout=2m
echo "✅ LiteLLM restarted"

echo -e "\n=================================="
echo "✅ Langfuse Callbacks Enabled!"
echo "=================================="

echo -e "\nWhat changed:"
echo "  Added success_callback: [\"langfuse\"]"
echo "  Added failure_callback: [\"langfuse\"]"

echo -e "\nTest it now:"
echo "  curl http://localhost:4000/v1/chat/completions \\"
echo "    -H \"Content-Type: application/json\" \\"
echo "    -d '{"
echo "      \"model\": \"claude-sonnet\","
echo "      \"messages\": [{\"role\": \"user\", \"content\": \"Hello Langfuse!\"}]"
echo "    }'"

echo -e "\nThen check Langfuse UI at http://localhost:3000"
echo "You should now see the trace! 🎉"
