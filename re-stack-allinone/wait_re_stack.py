import socket, time, os
# Wait for the in-container RE MCP upstreams to listen, then start the aggregator on 4038.
ports = [4012, 4013, 4016, 4017, 4018, 4050]
for p in ports:
    for _ in range(120):
        try:
            socket.create_connection(('127.0.0.1', p), 2).close(); break
        except Exception:
            time.sleep(2)
os.execvp('node', ['node', '/app/mcp_http_bridge.js', '4038', 'node', '/app/web_stack_mcp.js'])
