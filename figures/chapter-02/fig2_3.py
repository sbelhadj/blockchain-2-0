from figlib import *
F = Fig(9.6, 4.6)
rows = [
  ("Lives for one call", "blue", [("Calldata", "read-only input\nCALLDATALOAD 3 gas"), ("Stack", "up to 1,024 words\nof 32 bytes; ADD 3 gas"), ("Memory", "byte array; MSTORE\n3 gas + growth"), ("PC and gas counter", "gas checked before\nevery instruction")]),
  ("Lives for one transaction", "amber", [("Transient storage", "per contract, cleared at\nthe end; TLOAD 100 gas")]),
  ("Persists in the world state", "green", [("Storage", "per contract, 32-byte\nslots; SLOAD 2,100 cold"), ("Code", "fixed at deployment\n(or delegated, EIP-7702)")]),
]
H, GAP, TOP, BW = 95, 22, 430, 172
for r, (label, col, boxes) in enumerate(rows):
    y = TOP - (r + 1) * H - r * GAP
    F.text(88, y + H / 2, label, size=9, weight="bold", color=GREY)
    for i, (name, desc) in enumerate(boxes):
        x = 190 + i * (BW + 14)
        c = "white" if name.startswith("PC") else col
        F.box(x, y, BW, H, color=c)
        own = (x, y, x + BW, y + H)
        F.text(x + BW / 2, y + H - 25, name, size=9.2, weight="bold", owner=own)
        F.text(x + BW / 2, y + 33, desc, size=8.1, owner=own)
F.crop(60, 440)
print(F.save("Figure_2_3.png"))
