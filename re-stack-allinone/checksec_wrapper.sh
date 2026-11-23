#!/bin/sh
# checksec wrapper for RE-Stack.
#  - PE   -> a pefile-based protection report (checksec is ELF-only)
#  - ELF  -> pwntools `pwn checksec` (fast, accurate); the ancient bash checksec
#            (slimm609 v2.7.1) hangs on some binaries, so it is only a fallback.
bin=""
prev=""
for a in "$@"; do
  [ "$prev" = "--file" ] && bin="$a"
  case "$a" in --file=*) bin="${a#--file=}" ;; esac
  prev="$a"
done
[ -z "$bin" ] && bin="$1"

if [ -n "$bin" ] && [ -f "$bin" ]; then
  if file -b "$bin" 2>/dev/null | grep -qi 'PE32'; then
    exec python3 /usr/local/bin/pe_checksec.py "$bin"
  fi
  TERM=dumb exec pwn checksec "$bin"
fi
exec /opt/checksec/checksec.bash "$@"
