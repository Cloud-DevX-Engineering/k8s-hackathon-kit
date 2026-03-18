#!/bin/bash
set -e

# =============================================================================
# Nebius Token Factory Setup for OpenClaw
# =============================================================================
# Configures OpenClaw with recommended Nebius models and lets you pick a default.
#
# Uses the global endpoint (api.tokenfactory.nebius.com) which has 56+ models.
# The regional endpoint (us-central1) only has ~8 models.
# =============================================================================

API_KEY="${1:-$NEBIUS_API_KEY}"

if [ -z "$API_KEY" ]; then
    echo "Usage: $0 [API_KEY]"
    echo "  or set NEBIUS_API_KEY environment variable"
    exit 1
fi

CONFIG_FILE="$HOME/.openclaw/openclaw.json"
BASE_URL="https://api.tokenfactory.nebius.com/v1"
VALIDATION_MODEL="Qwen/Qwen3.5-397B-A17B"

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

echo "◇ Validating API key against ${VALIDATION_MODEL}..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "${BASE_URL}/chat/completions" \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"${VALIDATION_MODEL}\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":5}")

if [ "$HTTP_CODE" -lt 400 ]; then
    echo "✓ API key is valid (HTTP ${HTTP_CODE})"
else
    echo "✗ API key validation failed (HTTP ${HTTP_CODE})"
    echo "  Check your key at https://tokenfactory.nebius.com/"
    exit 1
fi

# Ensure config directory exists
mkdir -p "$(dirname "$CONFIG_FILE")"

echo "◇ Updating OpenClaw config at ${CONFIG_FILE}..."

# Build JSON models array
MODELS_JSON="["
for i in "${!MODEL_IDS[@]}"; do
    [ "$i" -gt 0 ] && MODELS_JSON+=","
    MODELS_JSON+="{\"id\":\"${MODEL_IDS[$i]}\",\"name\":\"${MODEL_NAMES[$i]}\"}"
done
MODELS_JSON+="]"

python3 - "$API_KEY" "$BASE_URL" "$CONFIG_FILE" "$MODELS_JSON" << 'PYEOF'
import sys, json

api_key = sys.argv[1]
base_url = sys.argv[2]
config_path = sys.argv[3]
models = json.loads(sys.argv[4])

# Load existing config or start fresh
config = {}
try:
    with open(config_path) as f:
        config = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    pass

config.setdefault("models", {})
config["models"].setdefault("providers", {})

config["models"]["providers"]["nebius"] = {
    "baseUrl": base_url,
    "apiKey": "${NEBIUS_API_KEY}",
    "api": "openai-completions",
    "models": models
}

with open(config_path, "w") as f:
    json.dump(config, f, indent=2)

print("✓ Config updated with {} Nebius models".format(len(models)))
PYEOF

# ── Interactive model selection ──
echo ""
echo "════════════════════════════════════════════════════════════"
echo "  Choose your default model"
echo "════════════════════════════════════════════════════════════"
echo ""
for i in "${!MODEL_IDS[@]}"; do
    NUM=$((i + 1))
    echo "  ${NUM}) ${MODEL_IDS[$i]}"
    echo "     ${MODEL_TAGS[$i]}"
    echo ""
done

read -r -p "  Select [1-${#MODEL_IDS[@]}] (default: 1): " CHOICE
CHOICE=${CHOICE:-1}

# Validate input
if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || [ "$CHOICE" -lt 1 ] || [ "$CHOICE" -gt "${#MODEL_IDS[@]}" ]; then
    echo "  Invalid choice, defaulting to 1"
    CHOICE=1
fi

IDX=$((CHOICE - 1))
SELECTED_ID="${MODEL_IDS[$IDX]}"
SELECTED_FULL="nebius/${SELECTED_ID}"

echo ""
echo "◇ Setting default model to ${SELECTED_FULL}..."

python3 - "$CONFIG_FILE" "$SELECTED_FULL" << 'PYEOF'
import sys, json

config_path = sys.argv[1]
model_id = sys.argv[2]

with open(config_path) as f:
    config = json.load(f)

config.setdefault("agents", {}).setdefault("defaults", {})
config["agents"]["defaults"]["model"] = {"primary": model_id}
config["agents"]["defaults"]["models"] = {model_id: {}}

with open(config_path, "w") as f:
    json.dump(config, f, indent=2)

print("✓ Default model set to {}".format(model_id))
PYEOF

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  Nebius Token Factory setup complete!"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "  Endpoint: ${BASE_URL}"
echo "  Default:  ${SELECTED_FULL}"
echo ""
echo "  All models available:"
for i in "${!MODEL_IDS[@]}"; do
    MARKER="   "
    [ "$i" -eq "$IDX" ] && MARKER=" ▸ "
    echo "  ${MARKER} nebius/${MODEL_IDS[$i]}"
done
echo ""
echo "  Switch model anytime:"
echo "    openclaw models set nebius/<model-id>"
echo ""
echo "  Make sure NEBIUS_API_KEY is set in your environment:"
echo "    export NEBIUS_API_KEY='${API_KEY:0:8}...'"
echo ""
