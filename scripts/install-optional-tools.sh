#!/bin/sh
# Optional heavyweight tools: Ghidra + JDK + rizin/Cutter + Android platform-tools.
#   docker exec re-stack sh /opt/install-optional-tools.sh
# Resolves the latest release URLs from the GitHub API (never goes stale).
set -e
TOOLS_COMMON=/opt/open-reverselab/tools/common
CUTTER_ROOT=/opt/open-reverselab/tools/windows/Cutter/Cutter-linux
mkdir -p "$TOOLS_COMMON" "$CUTTER_ROOT" /opt/jdk /opt/android-sdk

echo "[1/4] Temurin JDK ..."
curl -fsSL -o /tmp/jdk.tar.gz \
  "https://api.adoptium.net/v3/binary/latest/21/ga/linux/x64/jdk/hotspot/normal/eclipse" \
  && tar -xzf /tmp/jdk.tar.gz -C /opt/jdk --strip-components=1 \
  && /opt/jdk/bin/java -version || echo "  JDK install skipped"

echo "[2/4] Ghidra ..."
GHIDRA_URL=$(curl -fsSL https://api.github.com/repos/NationalSecurityAgency/ghidra/releases/latest \
  | grep -o 'https://[^"]*_PUBLIC_[0-9]*\.zip' | head -1)
if [ -n "$GHIDRA_URL" ]; then
  curl -fsSL -o /tmp/ghidra.zip "$GHIDRA_URL"
  unzip -q /tmp/ghidra.zip -d "$TOOLS_COMMON"
  GH_DIR=$(ls -d "$TOOLS_COMMON"/ghidra_* 2>/dev/null | head -1)
  ln -sfn "$GH_DIR" "$TOOLS_COMMON/ghidra" 2>/dev/null || true
  echo "  Ghidra -> $GH_DIR"
else
  echo "  Ghidra URL not resolved; skipped"
fi

echo "[3/4] rizin ..."
RZ_URL=$(curl -fsSL https://api.github.com/repos/rizinorg/rizin/releases/latest \
  | grep -o 'https://[^"]*linux-x86_64[^"]*\.tar\.xz' | head -1)
if [ -n "$RZ_URL" ]; then
  curl -fsSL -o /tmp/rizin.tar.xz "$RZ_URL"
  tar -xJf /tmp/rizin.tar.xz -C "$CUTTER_ROOT" || tar -xf /tmp/rizin.tar.xz -C "$CUTTER_ROOT"
  echo "  rizin -> $CUTTER_ROOT"
else
  echo "  rizin URL not resolved; skipped"
fi

echo "[4/4] Android platform-tools (adb) ..."
curl -fsSL -o /tmp/pt.zip https://dl.google.com/android/repository/platform-tools-latest-linux.zip \
  && unzip -q /tmp/pt.zip -d /opt/android-sdk \
  && ln -sfn /opt/android-sdk/platform-tools/adb /usr/local/bin/adb || echo "  adb install skipped"

echo "done. restart:  docker compose restart re-stack"
