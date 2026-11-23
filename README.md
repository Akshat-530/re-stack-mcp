<div align="center">

# RE-Stack

### One container. One MCP endpoint. A full reverse-engineering workbench.

**≈454 tools** from **6 upstream MCP servers** fused into a single deduplicated catalog — plus an in-container **Windows bridge** for live debugging.

`docker compose up -d --build` → `http://127.0.0.1:4038/mcp` → point any MCP client at it.

</div>

---

## What is RE-Stack?

RE-Stack bundles the open-source reverse-engineering MCP ecosystem behind **one HTTP endpoint** so a single MCP client can drive everything: static analysis, decompilation, dynamic instrumentation, native debugging, fuzzing, and offline offensive tooling.

It is an **aggregator**: each upstream MCP server runs as a supervised process inside the container, and a thin aggregator (`app/web_stack_mcp.js`) merges their tool lists — renaming collisions, applying per-upstream include/exclude filters, and exposing **one** clean, duplicate-free catalog.

```
+--------------------------- re-stack container ----------------------------+
|  aggregator  :4038  -->  merged, deduped tool list (~454 tools)           |
|     |                                                                     |
|     +-- rea              :4012   AI-assisted RE + decompile orchestration |
|     +-- pycode           :4013   python code intelligence                 |
|     +-- x64dbg           :4016   Windows EXE/DLL debugger                 |
|     +-- frida            :4017   runtime instrumentation                  |
|     +-- open-reverselab  :4018   Ghidra-headless / rizin / adb            |
|     +-- hexstrike        :4050   payload / forensic / system tools        |
|  socat relays: 27042 / 27043 / 27044  --> host.docker.internal            |
+---------------------------------------------------------------------------+
```

---

## Highlights

- **One endpoint, one catalog** — no juggling 6 MCP servers in your client.
- **Static RE of any binary** — PE/DLL/EXE, ELF, Mach-O, .NET, firmware, wasm, APK.
- **Dynamic** — attach / hook / trace with Frida; native debugging with gdb (Linux) and x64dbg (Windows).
- **Windows bridge** — debug and instrument software running on your Windows host, straight from the container.
- **Offline offensive tooling** — payload generation, hash cracking (john/hashcat), AFL++, pwntools, angr, rop/one_gadget.
- **Portable** — builds from public sources; one `docker compose up`. Works on Linux, macOS and Windows (Docker Desktop).
- **Config-driven** — add/remove any tool by editing one JSON file, no rebuild.

---

## Quick start

**Requirements:** Docker + Docker Compose v2.

```bash
git clone https://github.com/Akshat-530/re-stack-mcp.git
cd re-stack-mcp
docker compose up -d --build          # first build pulls ~1.5 GB, ~5-10 min
```

Verify:

```bash
docker exec re-stack supervisorctl status          # 11 programs RUNNING
curl -s -X POST http://127.0.0.1:4038/mcp \
  -H 'content-type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
```

Put your targets in `./samples/` (they appear at `/work` and inside the open-reverselab sandbox).

---

## Connect an MCP client

RE-Stack is a **streamable-HTTP MCP server** at `http://127.0.0.1:4038/mcp`.

**Kilo / Kilo Code** (`kilo.jsonc`):

```jsonc
{
  "mcp": {
    "re-stack-mcp": {
      "type": "remote",
      "url": "http://127.0.0.1:4038/mcp",
      "enabled": true,
      "timeout": 1800000
    }
  }
}
```

**Claude Desktop** (via the stdio<->http proxy):

```json
{
  "mcpServers": {
    "re-stack": { "command": "npx", "args": ["-y", "mcp-remote", "http://127.0.0.1:4038/mcp"] }
  }
}
```

**Cursor / Cline / Continue / OpenCode / any client** — a remote HTTP MCP server at that URL, or `mcp-remote` for stdio-only clients.

> The container publishes **only** `127.0.0.1:4038` — never exposed beyond your machine.

---

## Configuration

Exposed tools are defined in **`data/re-stack/config/config.json`** (mounted live at `/data/config/config.json`):

```jsonc
{
  "server": { "name": "RE-Stack", "helperPrefix": "re_stack" },
  "upstreams": [
    {
      "name": "hexstrike",
      "url": "http://127.0.0.1:4050/mcp",
      "prefix": "",
      "include": ["binwalk_analyze", "john_crack"],
      "exclude": [],
      "enabled": true
    }
  ]
}
```

Apply changes **without a rebuild**:

```bash
docker compose restart re-stack      # then reconnect the MCP client
```

---

## Windows bridge (debug real Windows software)

Static RE of a Windows `.exe`/`.dll` needs **no bridge** — mount a drive and point the tools at `/host/c/...`:

```yaml
volumes:
  - "C:\\:/host/c"
```

For **dynamic** work (run it, watch it, hook it, execute in it), the container talks to three Windows-side services through in-container `socat` relays.

### 1. Copy the bridge to your Windows machine

Copy **`bridge/Bridge.bat`** and **`bridge/host_agent.ps1`** into one folder, e.g. `C:\re-bridge\`.

x64dbg must be installed (default `C:\x64dbg\release\` — edit the `X64`/`X32` paths at the top of `Bridge.bat` if yours differs).

### 2. Start it

```cmd
Bridge.bat start         :: x64dbg + frida-server + host agent  (x64 targets)
Bridge.bat start x32     :: also launch x32dbg
Bridge.bat status        :: check the three ports + agent health
Bridge.bat stop          :: stop everything
```

First run auto-downloads **frida-server** into the bridge folder and starts it on `127.0.0.1:27043`.

| Windows service | Port | What it gives the container |
|---|---|---|
| **x64dbg** (MCP plugin) | `27042` | run/step/breakpoint/patch a Windows EXE/DLL (`x64dbg_*`) |
| **frida-server** | `27043` | hook / instrument any running Windows process |
| **host agent** (`host_agent.ps1`) | `27044` | list processes, list a process's loaded DLLs, launch a program, run a command |

### 3. Use it from the MCP toolset

- **Debug:** `x64dbg_debug`, `x64dbg_registers`, `x64dbg_memory`, `x64dbg_breakpoints`, …
- **Runtime RE:** `execute_command` -> `curl "http://127.0.0.1:27044/processes"`, `.../modules?pid=NNN`, `.../run?path=C:\app.exe`, `.../exec?cmd=...`
- **Frida:** `frida -H 127.0.0.1:27043 -n app.exe -l hook.js` via `execute_command`

> **Security:** the host agent's `/exec` runs commands on your Windows machine. It binds to **localhost only** and is reachable only through the container relay. Run the bridge only on a machine you control, and point all tooling at **targets you are authorized to test**.

**Linux / macOS hosts:** the Windows bridge is Windows-specific. On Linux, run frida-server natively and use `rea`/`gdb`/`rizin` debugging directly; the container's upstreams are OS-agnostic.

---

## Usage examples

```text
rea.open_binary            { "path": "/host/c/Windows/System32/kernel32.dll" }
reverselab.triage_pe       { "path": "/work/malware.exe" }
hexstrike.checksec_analyze { "binary": "/host/c/Windows/System32/kernel32.dll" }
x64dbg.x64dbg_debug        { "action": { "action": "run" } }
frida.enumerate_devices    {}
execute_command            { "command": "frida-ps -H 127.0.0.1:27043 | head" }
execute_command            { "command": "afl-fuzz -i in -o out -- ./target @@" }
```

---

## Tool catalog (by upstream)

| Upstream | Port | ~Tools | Role |
|---|---|---|---|
| **rea** | 4012 | 225 | AI-assisted RE + decompile orchestration (static/dynamic/mobile/macOS/.NET/wasm/firmware/pcap) |
| **open-reverselab** | 4018 | 105 | Ghidra headless, rizin/Cutter, DiE, PE patching, adb+frida, YARA/Sigma, CTF |
| **frida** | 4017 | 41 | runtime instrumentation / hooking |
| **x64dbg** | 4016 | 23 | Windows EXE/DLL debugging (via the bridge) |
| **pycode** | 4013 | 14 | python code intelligence |
| **hexstrike** | 4050 | 43 | offline offensive + forensic subset |
| **local** | - | 3 | `re_stack_status` / `re_stack_refresh` / `re_stack_rotation` |

Tool names are **unprefixed**; rare collisions auto-rename to `<label>__<tool>`. Fully editable in `config.json`.

---

## Ports & mounts

| Port | Direction | Purpose |
|---|---|---|
| `4038` | published -> host | the single MCP endpoint |
| `4012-4050` | internal | upstream MCP servers |
| `27042-27044` | internal relays | Windows bridge -> `host.docker.internal` |

| Mount | Purpose |
|---|---|
| `./data/re-stack:/data` | aggregator config |
| `./samples:/work` | your targets |
| `./samples:/opt/open-reverselab/samples` | same files, inside the reverselab sandbox |
| `C:\:/host/c` *(optional)* | read host drives directly |

---

## Optional heavyweight tools

The base image is deliberately lean. Enable **Ghidra, JDK, rizin/Cutter and Android platform-tools**:

```bash
docker exec re-stack sh /opt/install-optional-tools.sh
docker compose restart re-stack
```

The installer resolves the **latest** release URLs from the GitHub API, so it never goes stale.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `x64dbg ... plugin did not come online` | start x64dbg on the host: `Bridge.bat start` (alive = `curl -s -o NUL -w "%{http_code}" http://127.0.0.1:27042/` -> `404`) |
| frida can't see Windows processes | frida-server must listen on `27043`; test `frida-ps -H 127.0.0.1:27043` |
| Ghidra / `ghidra_headless_analyze` fails | run `/opt/install-optional-tools.sh` |
| `rz-bin not found` | install rizin via `/opt/install-optional-tools.sh` |
| Tool list looks wrong | connector caches `tools/list` -> `docker compose restart re-stack`, reconnect |
| Only 3 tools exposed | `WEBSTACK_CONFIG` not pointing at the mounted config |

---

## Legal & authorized use

RE-Stack is for **security research, malware analysis, interoperability, and authorized testing only**. You must have explicit permission for every target you analyse or instrument.

## Credits

[rea-agents](https://www.npmjs.com/package/rea-agents) - [open-reverselab](https://github.com/LING71671/open-reverselab) - [frida](https://frida.re) - [x64dbg](https://x64dbg.com) - [HexStrike AI](https://github.com/0x4m4/hexstrike-ai) - [Ghidra](https://ghidra-sre.org) - [rizin](https://rizin.re) - [pwntools](https://pwntools.com) - [pycode-mcp](https://github.com/spkc83/pycode-mcp-server).

## License

MIT — see [LICENSE](LICENSE).
