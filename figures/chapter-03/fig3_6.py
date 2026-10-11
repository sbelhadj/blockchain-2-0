from figlib import *
F = Fig(9.6, 4.4)
X0, W = 210, 640  # 32 bytes -> 640 units, 20 units per byte
def slot(y, n, parts):
    F.text(170, y + 17, f"slot {n}", size=8.5, color=GREY)
    x = X0
    for name, size, col in parts:
        w = size * 20
        F.box(x, y, w, 34, color=col, lw=0.9, round_=2)
        if w >= 60:
            F.text(x + w / 2, y + 17, f"{name} ({size} B)", size=7.8, owner=(x, y, x + w, y + 34))
        x += w
    if x < X0 + W:
        F.box(x, y, X0 + W - x, 34, color="white", lw=0.6, round_=2)
        if X0 + W - x >= 80:
            F.text((x + X0 + W) / 2, y + 17, f"unused ({(X0 + W - x)//20} B)", size=7.6, color=GREY,
                   owner=(x, y, X0 + W, y + 34))
F.text(20, 395, "ShipmentLogWide: 4 slots", size=9.5, weight="bold", ha="left")
for i, parts in enumerate([[("weight", 32, "blue")], [("fragile", 1, "amber")], [("id", 32, "blue")],
                           [("sender", 20, "green"), ("createdAt", 8, "amber")]]):
    slot(350 - i * 40, i, parts)
F.text(20, 165, "ShipmentLogPacked: 3 slots", size=9.5, weight="bold", ha="left")
for i, parts in enumerate([[("weight", 32, "blue")], [("id", 32, "blue")],
                           [("sender", 20, "green"), ("createdAt", 8, "amber"), ("fragile", 1, "amber")]]):
    slot(120 - i * 40, i, parts)
F.text(20, 20, "Each slot is 32 bytes. A field that does not fit in the space left starts a new slot.", size=8.2,
       color=GREY, style="italic", ha="left")
F.crop(5, 410)
print(F.save("Figure_3_6.png"))
