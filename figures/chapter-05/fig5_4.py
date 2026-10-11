# Drawn from the impermanent loss table in captured-outputs/chapter-05/amm.txt
import re, matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from math import sqrt
plt.rcParams["font.family"] = "Liberation Sans"
cap = open("../../captured-outputs/chapter-05/amm.txt").read()
pts = [(float(r), float(l)) for r, l in re.findall(r"\s([\d.]+)x\s+(-?[\d.]+)%", cap)]
rs = [0.1 + i * 0.01 for i in range(491)]
fig, ax = plt.subplots(figsize=(8.5, 4.0), dpi=200)
ax.plot(rs, [(2 * sqrt(r) / (1 + r) - 1) * 100 for r in rs], color="#2E5C8A", lw=2)
ax.plot([p[0] for p in pts], [p[1] for p in pts], "o", color="#A33A3A", label="values printed by tools/amm.py")
for r, l in pts:
    if r in (0.25, 2.0, 5.0):
        off = (-1.25, 2.0) if r == 5.0 else (0.15, -2.5)
        ax.annotate(f"{r:g}x: {l:.2f}%", (r, l), xytext=(r + off[0], l + off[1]), fontsize=8.5)
ax.axhline(0, color="#7F7F7F", lw=0.8)
ax.set_xlabel("price of WETH relative to the price at deposit"); ax.set_ylabel("loss versus holding (%)")
ax.set_xlim(0, 5.2); ax.set_ylim(-30, 2); ax.grid(alpha=0.3)
ax.legend(loc="upper right", fontsize=9, frameon=False)
for s in ("top", "right"): ax.spines[s].set_visible(False)
fig.tight_layout(); fig.savefig("Figure_5_4.png", facecolor="white"); print("[]")
