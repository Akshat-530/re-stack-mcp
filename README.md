# RE-Stack

One container. One MCP endpoint. A full reverse-engineering workbench.

RE-Stack bundles the open-source reverse-engineering MCP ecosystem behind a single HTTP endpoint (`http://127.0.0.1:4038/mcp`) so one MCP client drives static analysis, decompilation, dynamic instrumentation, native debugging, fuzzing, and offline offensive tooling.

See the full documentation below and the other files in this repository (`Dockerfile`, `docker-compose.yml`, `bridge/`, `data/re-stack/config/config.json`).

## Quick start

```bash
git clone https://github.com/Akshat-530/re-stack-mcp.git
cd re-stack-mcp
docker compose up -d --build
```

Then connect any MCP client to `http://127.0.0.1:4038/mcp`.

> The complete README (architecture, Windows bridge, tool catalog, troubleshooting) is being committed in the next push.
