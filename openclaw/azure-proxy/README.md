# Azure Partner Proxy

Proxy for OpenClaw to use Azure-hosted models (Mistral, Kimi, Grok) with tool call compatibility.

## Features

- Remaps Anthropic-style tool call IDs (long) to 9-char alphanumeric IDs (Mistral requirement)
- Handles both streaming and non-streaming responses
- Rewrites `max_completion_tokens` → `max_tokens` for Azure compatibility
- Removes unsupported params (`store`, `metadata`)

## Usage

1. Install Node.js (v20+)
2. Edit `proxy.js`:
   - Set `AZURE_BASE` to your Azure OpenAI endpoint
   - Set `AZURE_API_KEY` via environment variable (see below)
   - Update `DEPLOYMENTS` with your model → deployment mappings
3. Run:
   ```bash
   AZURE_API_KEY="your-key-here" node proxy.js
   ```
4. Configure OpenClaw to use `http://127.0.0.1:4001` as the `azure-partner` provider

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `AZURE_API_KEY` | Azure OpenAI API key (required) |

## Example OpenClaw Config

```json
{
  "models": {
    "providers": {
      "azure-partner": {
        "baseUrl": "http://127.0.0.1:4001",
        "apiKey": "not-used",
        "api": "openai-completions",
        "models": [
          {
            "id": "mistral-large-3",
            "name": "Mistral Large 3 (Azure)",
            "contextWindow": 128000
          }
        ]
      }
    }
  }
}
```

## License

MIT
