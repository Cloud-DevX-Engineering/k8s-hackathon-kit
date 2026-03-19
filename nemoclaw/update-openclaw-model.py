"""
Update OpenClaw config inside a NemoClaw sandbox to use Nebius inference.

Upload to sandbox and run:
  openshell sandbox upload huginn update-openclaw-model.py /tmp/update-openclaw-model.py
  nemoclaw huginn connect
  python3 /tmp/update-openclaw-model.py/update-openclaw-model.py

Accepts optional args:
  python3 update-openclaw-model.py [MODEL_ID] [MODEL_NAME]

Defaults to Qwen/Qwen3.5-397B-A17B.
"""
import json
import sys

model_id = sys.argv[1] if len(sys.argv) > 1 else "Qwen/Qwen3.5-397B-A17B"
model_name = sys.argv[2] if len(sys.argv) > 2 else "Qwen3.5 397B (Nebius)"

config_path = "/sandbox/.openclaw/openclaw.json"

with open(config_path) as f:
    c = json.load(f)

c["models"]["providers"]["inference"]["models"] = [{
    "id": model_id,
    "name": model_name,
    "reasoning": False,
    "input": ["text"],
    "cost": {"input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0},
    "contextWindow": 262144,
    "maxTokens": 4096
}]

c["agents"]["defaults"]["model"]["primary"] = f"inference/{model_id}"
c["agents"]["defaults"]["models"] = {f"inference/{model_id}": {}}

with open(config_path, "w") as f:
    json.dump(c, f, indent=2)

print(f"Done - model set to {model_name} ({model_id})")
