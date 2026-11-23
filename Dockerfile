# =============================================================================
#  RE-Stack — Reverse-Engineering MCP. One container, one endpoint.
#  Builds entirely from public sources (no private base image required).
#
#    docker compose up -d --build     ->   http://127.0.0.1:4038/mcp
# =============================================================================
FROM node:24-bookworm-slim
ENV DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8

RUN apt-get update && apt-get install -y --no-install-recommends \
      python3 python3-pip python3-venv python3-dev \
      git curl wget xz-utils unzip ca-certificates supervisor socat \
      gdb file xxd vim-common ruby ruby-dev build-essential pkg-config \
      libffi-dev libssl-dev libzstd-dev libimage-exiftool-perl \
      binwalk foremost steghide upx-ucl radare2 \
 && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir --break-system-packages \
      frida frida-tools ropgadget ropper pwntools volatility3 \
      flask requests psutil "fastmcp>=0.2.0,<1.0.0" beautifulsoup4 aiohttp lxml \
      selenium webdriver-manager mitmproxy bcrypt

RUN npm install -g --prefix /opt/rea rea-agents@latest

RUN git clone --depth 1 https://github.com/LING71671/open-reverselab.git /opt/open-reverselab \
 && python3 -m venv /opt/reverselab-venv \
 && /opt/reverselab-venv/bin/pip install --no-cache-dir -e /opt/open-reverselab/tools/skills/mcp/ReverseLabToolsMCP

RUN git clone --depth 1 https://github.com/spkc83/pycode-mcp-server.git /app/pycode-mcp \
 && python3 -m venv /opt/pycode-venv \
 && /opt/pycode-venv/bin/pip install --no-cache-dir -r /app/pycode-mcp/requirements.txt

RUN git clone --depth 1 https://github.com/0x4m4/hexstrike-ai.git /opt/hexstrike-ai

RUN ( gem install one_gadget --no-document || echo "skip one_gadget" )
RUN ( curl -fsSL https://github.com/io12/pwninit/releases/latest/download/pwninit -o /usr/local/bin/pwninit && chmod +x /usr/local/bin/pwninit || echo "skip pwninit" )
RUN ( git clone --depth 1 https://github.com/slimm609/checksec.sh.git /opt/checksec || echo "skip checksec" )
RUN ( git clone --depth 1 https://github.com/niklasb/libc-database.git /opt/libc-database || echo "skip libc-database" )
COPY re-stack-allinone/checksec_wrapper.sh /usr/local/bin/checksec
COPY re-stack-allinone/pe_checksec.py /usr/local/bin/pe_checksec.py
COPY scripts/install-optional-tools.sh /opt/install-optional-tools.sh
RUN chmod +x /usr/local/bin/checksec /usr/local/bin/pe_checksec.py /opt/install-optional-tools.sh

COPY app/mcp_http_bridge.js /app/mcp_http_bridge.js
COPY app/web_stack_mcp.js /app/web_stack_mcp.js
COPY re-stack-allinone/supervisord.conf /etc/supervisor/supervisord.conf
COPY re-stack-allinone/wait_re_stack.py /opt/wait_re_stack.py
RUN mkdir -p /data /work /opt/jdk

EXPOSE 4038
CMD ["supervisord", "-c", "/etc/supervisor/supervisord.conf"]
