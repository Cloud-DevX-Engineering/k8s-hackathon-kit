const http = require('http');
const https = require('https');

// Azure OpenAI configuration — EDIT THESE
const AZURE_BASE = 'https://your-resource.openai.azure.com';
const API_VERSION = '2024-05-01-preview';
const PORT = 4001;

// Model name → deployment name mapping — EDIT THESE
const DEPLOYMENTS = {
  'mistral-large-3': 'Mistral-Large-3',
  'kimi-k2.5': 'Kimi-K2.5',
  'grok-4-1-fast-reasoning': 'grok-4-1-fast-reasoning',
};

// Tool call ID remapping for models that require short IDs (e.g. Mistral: 9 alphanum)
const ID_LENGTH = 9;
const idMap = new Map();       // short → long
const reverseMap = new Map();  // long → short

function shortId() {
  const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let id = '';
  for (let i = 0; i < ID_LENGTH; i++) id += chars[Math.floor(Math.random() * chars.length)];
  return id;
}

function rewriteToolCallIds(data) {
  // Rewrite tool_calls in assistant messages (long → short)
  if (data.messages) {
    for (const msg of data.messages) {
      if (msg.tool_calls) {
        for (const tc of msg.tool_calls) {
          if (tc.id && tc.id.length > ID_LENGTH) {
            let short = reverseMap.get(tc.id);
            if (!short) {
              short = shortId();
              idMap.set(short, tc.id);
              reverseMap.set(tc.id, short);
            }
            tc.id = short;
          }
        }
      }
      // Rewrite tool_call_id in tool result messages
      if (msg.role === 'tool' && msg.tool_call_id && msg.tool_call_id.length > ID_LENGTH) {
        let short = reverseMap.get(msg.tool_call_id);
        if (!short) {
          short = shortId();
          idMap.set(short, msg.tool_call_id);
          reverseMap.set(msg.tool_call_id, short);
        }
        msg.tool_call_id = short;
      }
    }
  }
}

function restoreToolCallIds(body) {
  // Restore short IDs back to original long IDs in response
  try {
    const data = JSON.parse(body);
    if (data.choices) {
      for (const choice of data.choices) {
        const msg = choice.message || choice.delta;
        if (msg?.tool_calls) {
          for (const tc of msg.tool_calls) {
            if (tc.id && idMap.has(tc.id)) {
              tc.id = idMap.get(tc.id);
            }
          }
        }
      }
    }
    return JSON.stringify(data);
  } catch {
    return body;
  }
}

const server = http.createServer((req, res) => {
  if (req.method !== 'POST') {
    res.writeHead(405);
    res.end('Method not allowed');
    return;
  }

  let body = '';
  req.on('data', chunk => body += chunk);
  req.on('end', () => {
    try {
      const data = JSON.parse(body);
      
      // Get deployment name from model
      const modelName = data.model?.toLowerCase();
      const deployment = DEPLOYMENTS[modelName];
      
      if (!deployment) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: { message: `Unknown model: ${data.model}` } }));
        return;
      }

      // Rewrite max_completion_tokens → max_tokens
      if (data.max_completion_tokens !== undefined) {
        data.max_tokens = data.max_completion_tokens;
        delete data.max_completion_tokens;
      }

      // Remove unsupported params
      delete data.store;
      delete data.metadata;

      // Remap tool call IDs for Mistral compatibility
      rewriteToolCallIds(data);
      
      const payload = JSON.stringify(data);
      const azureUrl = new URL(
        `/openai/deployments/${deployment}/chat/completions?api-version=${API_VERSION}`,
        AZURE_BASE
      );

      const options = {
        hostname: azureUrl.hostname,
        path: azureUrl.pathname + azureUrl.search,
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(payload),
          'api-key': process.env.AZURE_API_KEY,
        },
      };

      const proxyReq = https.request(options, (proxyRes) => {
        const isStreaming = (proxyRes.headers['content-type'] || '').includes('text/event-stream');
        
        if (isStreaming) {
          // For streaming: rewrite each SSE chunk
          res.writeHead(proxyRes.statusCode, proxyRes.headers);
          let buffer = '';
          proxyRes.on('data', (chunk) => {
            buffer += chunk.toString();
            const lines = buffer.split('\n');
            buffer = lines.pop(); // keep incomplete line
            for (const line of lines) {
              if (line.startsWith('data: ') && line !== 'data: [DONE]') {
                const restored = restoreToolCallIds(line.slice(6));
                res.write('data: ' + restored + '\n');
              } else {
                res.write(line + '\n');
              }
            }
          });
          proxyRes.on('end', () => {
            if (buffer) res.write(buffer);
            res.end();
          });
        } else {
          // For non-streaming: buffer, rewrite, send
          let body = '';
          proxyRes.on('data', (chunk) => body += chunk);
          proxyRes.on('end', () => {
            const restored = restoreToolCallIds(body);
            const headers = { ...proxyRes.headers };
            headers['content-length'] = Buffer.byteLength(restored);
            res.writeHead(proxyRes.statusCode, headers);
            res.end(restored);
          });
        }
      });

      proxyReq.on('error', (e) => {
        console.error('Proxy error:', e.message);
        res.writeHead(502, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: { message: `Proxy error: ${e.message}` } }));
      });

      proxyReq.write(payload);
      proxyReq.end();

    } catch (e) {
      console.error('Parse error:', e.message);
      res.writeHead(400, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: { message: `Parse error: ${e.message}` } }));
    }
  });
});

server.listen(PORT, '127.0.0.1', () => {
  console.log(`Azure partner proxy running on http://127.0.0.1:${PORT}`);
  console.log('Supported models:', Object.keys(DEPLOYMENTS).join(', '));
  console.log('\nSet AZURE_API_KEY environment variable:');
  console.log('  export AZURE_API_KEY="your-azure-api-key"');
});