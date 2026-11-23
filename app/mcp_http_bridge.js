#!/usr/bin/env node
// mcp_http_bridge.js — front a stdio MCP server over Streamable HTTP.
// Usage: node mcp_http_bridge.js <PORT> <BIN> [ARGS...]
const { spawn } = require('child_process');
const http = require('http');

const port = parseInt(process.argv[2], 10);
const [bin, ...args] = process.argv.slice(3);
const child = spawn(bin, args, { stdio: ['pipe', 'pipe', 'inherit'], env: process.env });

let buf = '';
const pending = new Map();
let toolCache = null;
let nextId = 100;

child.stdout.on('data', d => {
  buf += d.toString();
  let idx;
  while ((idx = buf.indexOf('\n')) >= 0) {
    const line = buf.slice(0, idx).trim();
    buf = buf.slice(idx + 1);
    if (!line) continue;
    let msg;
    try { msg = JSON.parse(line); } catch { continue; }
    if (msg.id !== undefined && pending.has(msg.id)) {
      const done = pending.get(msg.id);
      pending.delete(msg.id);
      if (msg.error !== undefined) done({ ok: false, value: msg.error });
      else done({ ok: true, value: msg.result });
    }
  }
});

child.on('exit', (code) => { console.error('bridge: upstream exited (' + code + ') - shutting down'); process.exit(1); });
child.on('error', (err) => { console.error('bridge: upstream spawn failed - ' + err.message); process.exit(1); });

function rpc(id, method, params, signal) {
  return new Promise(resolve => {
    let timer = null;
    const settle = (value) => {
      if (timer) { clearTimeout(timer); timer = null; }
      if (signal) signal.removeEventListener('abort', onAbort);
      pending.delete(id);
      resolve(value);
    };
    const onAbort = () => { if (pending.has(id)) settle({ ok: false, value: { code: -32000, message: 'bridge: client aborted request' } }); };
    pending.set(id, (r) => { settle(r); });
    if (signal) { if (signal.aborted) return onAbort(); signal.addEventListener('abort', onAbort, { once: true }); }
    child.stdin.write(JSON.stringify({ jsonrpc: '2.0', id, method, params }) + '\n');
    timer = setTimeout(() => { if (pending.has(id)) settle({ ok: false, value: { code: -32000, message: 'bridge: upstream timeout' } }); }, 900000);
  });
}
function rpcNext(method, params, signal) { return rpc(nextId++, method, params, signal); }

function init() {
  rpc(1, 'initialize', { protocolVersion: '2024-11-05', capabilities: {}, clientInfo: { name: 'http-bridge', version: '1' } })
    .then(() => { child.stdin.write(JSON.stringify({ jsonrpc: '2.0', method: 'notifications/initialized' }) + '\n'); });
}
init();

function sendResult(res, msg, r) {
  res.setHeader('content-type', 'application/json');
  const body = { jsonrpc: '2.0', id: msg.id };
  if (r.ok) body.result = r.value;
  else body.error = r.value;
  res.end(JSON.stringify(body));
}

const server = http.createServer(async (req, res) => {
  const abort = new AbortController();
  let responseDone = false;
  res.on('finish', () => { responseDone = true; });
  res.on('close', () => { if (!responseDone) abort.abort(); });
  req.on('aborted', () => abort.abort());
  if (req.method === 'GET' && (req.url === '/mcp' || req.url === '/')) {
    res.writeHead(200, { 'content-type': 'text/event-stream' });
    res.write(': ok\n\n');
    return;
  }
  if (req.method !== 'POST') { res.writeHead(405); res.end(); return; }
  let body = '';
  req.on('data', c => body += c);
  req.on('end', async () => {
    let msg;
    try { msg = JSON.parse(body); } catch { res.writeHead(400); res.end(); return; }
    if (msg.method === 'initialize') {
      res.setHeader('content-type', 'application/json');
      res.end(JSON.stringify({ jsonrpc: '2.0', id: msg.id, result: { protocolVersion: '2024-11-05', capabilities: { tools: {} }, serverInfo: { name: 'bridge-' + port, version: '1' } } }));
      return;
    }
    if (msg.method === 'notifications/initialized' || (msg.method && msg.id === undefined)) { res.end(); return; }
    if (msg.method === 'tools/list') {
      if (!toolCache) { const r = await rpc(2, 'tools/list', {}); if (r.ok && r.value && r.value.tools) toolCache = r.value.tools; }
      res.setHeader('content-type', 'application/json');
      res.end(JSON.stringify({ jsonrpc: '2.0', id: msg.id, result: { tools: toolCache || [] } }));
      return;
    }
    if (msg.method === 'tools/call') { const r = await rpcNext('tools/call', msg.params, abort.signal); sendResult(res, msg, r); return; }
    if (msg.method === 'ping') { res.end(JSON.stringify({ jsonrpc: '2.0', id: msg.id, result: {} })); return; }
    const r = await rpcNext(msg.method, msg.params ?? {}, abort.signal);
    sendResult(res, msg, r);
  });
});
server.keepAliveTimeout = 65000;
server.headersTimeout = 66000;
server.on('clientError', (err, socket) => { try { if (socket.writable) socket.end('HTTP/1.1 400 Bad Request\r\nConnection: close\r\n\r\n'); } catch { } });
server.listen(port, '0.0.0.0', () => console.log('bridge', port, 'wrapping', bin, args.join(' ')));
