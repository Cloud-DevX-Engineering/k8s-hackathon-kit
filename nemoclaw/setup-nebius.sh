#!/bin/bash
set -e

# =============================================================================
# Nebius Inference Provider Setup for NemoClaw
# =============================================================================
# Configures Nebius Token Factory as the inference provider for a NemoClaw
# sandbox. Uses the OpenAI-compatible API at api.tokenfactory.nebius.com.
#
# Prerequisites:
#   - NemoClaw installed and onboarded (run setup-nemoclaw.sh first)
#   - A sandbox already created (e.g. "huginn")
#
# Usage:
#   ./setup-nebius.sh <NEBIUS_API_KEY> [SANDBOX_NAME]
#
# Get your API key at: https://tokenfactory.nebius.com/
# =============================================================================

API_KEY="${1:-$NEBIUS_API_KEY}"
SANDBOX="${2:-huginn}"

if [ -z "$API_KEY" ]; then
    echo "Usage: $0 <NEBIUS_API_KEY> [SANDBOX_NAME]"
    echo "  or set NEBIUS_API_KEY environment variable"
    exit 1
fi

echo "═══════════════════════════════════════════════════════════"
echo "  Nebius Inference Setup for NemoClaw"
echo "═══════════════════════════════════════════════════════════"
echo ""

# ── Model catalog ──
MODEL_IDS=(
    "Qwen/Qwen3.5-397B-A17B"
    "Qwen/Qwen3-235B-A22B-Instruct-2507"
    "deepseek-ai/DeepSeek-V3.2"
    "moonshotai/Kimi-K2.5"
)
MODEL_NAMES=(
    "Qwen3.5 397B (Nebius)"
    "Qwen3 235B Instruct (Nebius)"
    "DeepSeek V3.2 (Nebius)"
    "Kimi K2.5 (Nebius)"
)
MODEL_TAGS=(
    "primary — best agentic, MCP, 262K ctx, \$0.60/\$3.60"
    "best value — 96.5% tool-calling, 262K ctx, \$0.20/\$0.60"
    "budget — thinking-with-tools, 163K ctx, \$0.30/\$0.45"
    "agentic — agent swarm, 262K ctx, \$0.50/\$2.50"
)

# ── Step 1: Validate API key ──
echo "◇ Validating Nebius API key..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "https://api.tokenfactory.nebius.com/v1/chat/completions" \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type: application/json" \
    -d '{"model":"Qwen/Qwen3.5-397B-A17B","messages":[{"role":"user","content":"hi"}],"max_tokens":5}')

if [ "$HTTP_CODE" -lt 400 ]; then
    echo "✓ API key is valid (HTTP ${HTTP_CODE})"
else
    echo "✗ API key validation failed (HTTP ${HTTP_CODE})"
    echo "  Check your key at https://tokenfactory.nebius.com/"
    exit 1
fi

# ── Step 2: Remove old nebius provider if exists ──
echo "◇ Configuring OpenShell provider..."
openshell provider delete nebius 2>/dev/null || true

# ── Step 3: Create provider ──
# IMPORTANT: The config key must be OPENAI_BASE_URL (not base_url)
# for the openai provider type to route to a custom endpoint.
export OPENAI_API_KEY="$API_KEY"
openshell provider create \
    --name nebius \
    --type openai \
    --credential OPENAI_API_KEY \
    --config "OPENAI_BASE_URL=https://api.tokenfactory.nebius.com/v1"

echo "✓ Provider created"

# ── Step 4: Choose model ──
echo ""
echo "  Choose your default model:"
echo ""
for i in "${!MODEL_IDS[@]}"; do
    NUM=$((i + 1))
    echo "  ${NUM}) ${MODEL_IDS[$i]}"
    echo "     ${MODEL_TAGS[$i]}"
    echo ""
done

read -r -p "  Select [1-${#MODEL_IDS[@]}] (default: 1): " CHOICE
CHOICE=${CHOICE:-1}

if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || [ "$CHOICE" -lt 1 ] || [ "$CHOICE" -gt "${#MODEL_IDS[@]}" ]; then
    echo "  Invalid choice, defaulting to 1"
    CHOICE=1
fi

IDX=$((CHOICE - 1))
SELECTED_MODEL="${MODEL_IDS[$IDX]}"

# ── Step 5: Set inference route ──
echo "◇ Setting inference to ${SELECTED_MODEL}..."
openshell inference set --provider nebius --model "$SELECTED_MODEL"
echo "✓ Inference configured"

# ── Step 6: Add Nebius to sandbox network policy ──
echo "◇ Updating sandbox network policy..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POLICY_FILE="${SCRIPT_DIR}/nebius-network-policy.yaml"

if [ ! -f "$POLICY_FILE" ]; then
    echo "✗ Policy file not found: $POLICY_FILE"
    echo "  Copy nebius-network-policy.yaml to the same directory as this script."
    exit 1
fi

openshell policy set "$SANDBOX" --policy "$POLICY_FILE" --wait
echo "✓ Network policy updated (api.tokenfactory.nebius.com allowed)"

# ── Step 7: Update OpenClaw config inside sandbox ──
echo "◇ Updating OpenClaw model config inside sandbox..."

# Create a temp script and upload it
TMPSCRIPT=$(mktemp /tmp/update-model-XXXXX.py)
cat > "$TMPSCRIPT" << PYEOF
import json

config_path = "/sandbox/.openclaw/openclaw.json"

with open(config_path) as f:
    c = json.load(f)

c["models"]["providers"]["inference"]["models"] = [{
    "id": "${SELECTED_MODEL}",
    "name": "${MODEL_NAMES[$IDX]}",
    "reasoning": False,
    "input": ["text"],
    "cost": {"input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0},
    "contextWindow": 262144,
    "maxTokens": 4096
}]

c["agents"]["defaults"]["model"]["primary"] = "inference/${SELECTED_MODEL}"
c["agents"]["defaults"]["models"] = {"inference/${SELECTED_MODEL}": {}}

with open(config_path, "w") as f:
    json.dump(c, f, indent=2)

print("Done")
PYEOF

openshell sandbox upload "$SANDBOX" "$TMPSCRIPT" /tmp/update-model.py
# upload creates a directory, so the file is inside it
REMOTE_SCRIPT="/tmp/update-model.py/$(basename "$TMPSCRIPT")"

# TODO: Run the script inside the sandbox. Currently requires manual step:
echo ""
echo "  ⚠  Run this inside the sandbox to finish setup:"
echo ""
echo "    nemoclaw ${SANDBOX} connect"
echo "    python3 ${REMOTE_SCRIPT}"
echo "    openclaw tui"
echo ""

rm -f "$TMPSCRIPT"

# ── Done ──
echo "═══════════════════════════════════════════════════════════"
echo "  Nebius inference setup complete!"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "  Endpoint:  https://api.tokenfactory.nebius.com/v1"
echo "  Provider:  nebius (type: openai)"
echo "  Model:     ${SELECTED_MODEL}"
echo "  Sandbox:   ${SANDBOX}"
echo ""
echo "  Test from sandbox:"
echo "    curl -s https://inference.local/v1/chat/completions \\"
echo "      -H 'Content-Type: application/json' \\"
echo "      -d '{\"model\":\"${SELECTED_MODEL}\",\"messages\":[{\"role\":\"user\",\"content\":\"hello\"}],\"max_tokens\":50}'"
echo ""
