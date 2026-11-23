#!/usr/bin/env python3
"""PE protection report for the checksec wrapper (checksec is ELF-only)."""
import sys
try:
    import pefile
except Exception as e:
    print("pe_checksec: pefile not available:", e)
    sys.exit(0)

path = sys.argv[1]
pe = pefile.PE(path, fast_load=True)
dc = pe.OPTIONAL_HEADER.DllCharacteristics
mach = {0x8664: "x86-64", 0x14c: "i386", 0xaa64: "arm64"}.get(pe.FILE_HEADER.Machine, hex(pe.FILE_HEADER.Machine))
kind = "DLL" if pe.FILE_HEADER.Characteristics & 0x2000 else "EXE"
def f(mask): return "Enabled" if dc & mask else "Disabled"

print(f"[*] '{path}'  (PE32+ {kind}, {mach})")
print(f"    DllCharacteristics:  0x{dc:04x}")
print(f"    ASLR  (DYNAMIC_BASE): {f(0x0040)}")
print(f"    NX/DEP (NX_COMPAT):   {f(0x0100)}")
print(f"    SEH   (NO_SEH):       {'Disabled (no SEH)' if dc & 0x0400 else 'Present'}")
print(f"    CFG   (GUARD_CF):     {f(0x4000)}")
print(f"    Force Integrity:      {f(0x0080)}")
print(f"    High Entropy VA:      {f(0x0020)}")
print(f"    CET   (CET_COMPAT):   {f(0x8000)}")
print(f"    Isolation (AppCont):  {f(0x1000)}")
secs = []
for s in pe.sections:
    try: name = s.Name.rstrip(b"\x00").decode()
    except Exception: name = "?"
    secs.append(f"{name}({s.Characteristics:08x})")
print(f"    Sections:             {', '.join(secs)}")
