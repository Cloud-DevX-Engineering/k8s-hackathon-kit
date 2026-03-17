#!/bin/bash
set -e

# =============================================================================
# Nebius GLM-5 Setup for OpenClaw
# =============================================================================

API_KEY="${1:-$NEBIUS_API_KEY}"

if [ -z "$API_KEY" ]; then
    echo "Usage: $0 [API_KEY]"
    echo "  or set NEBIUS_API_KEY environment variable"
    exit 1
fi

CONFIG_FILE="$HOME/.openclaw/openclaw.json"

echo "◇ Validating API key..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "https://api.tokenfactory.us-central1.nebius.com/v1/chat/completions" \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type: application/json" \
    -d '{"model":"zai-org/GLM-5","messages":[{"role":"user","content":"hi"}],"max_tokens":5}')

[ "$HTTP_CODE" -lt 400 ] && echo "✓ API key is valid" || { echo "Invalid key (HTTP $HTTP_CODE)"; exit 1; }

# Update config
echo "{}" > $CONFIG_FILE 2>/dev/null || true

python3 - "$API_KEY" << 'EOF'
import sys, json, os
api_key = sys.argv[1] if len(sys.argv) > 1 else None
config_path = os.path.expanduser("~/.openclaw/openclaw.json")

config = {"models": {"providers": {}}
try:
    with open(config_path) as f: config = json.load(f)
except: pass

config.setdefault("models", {})
config["models"]["providers"] = config["models"].get("providers", {})
config["models"]["providers"]["nebius"] = {
    "baseUrl": "https://api.tokenfactory.us-central1.nebius.com/v1",
    "apiKey": "${NEBIUS_API_KEY}",
    "api": "openai",
    "models": [{"id": "zai-org/GLM-5", "name": "GLM-5 (Nebius)"}]
}
with open(config_path, "w") as f:
    json.dump(config, f, indent=2)
print("✓ Config updated")
EOF

echo "✓ Setup complete. Activate: openclaw models set nebius/zai-orgGLM-5"
EOF
