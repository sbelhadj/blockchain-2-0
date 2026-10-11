import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
plt.rcParams["font.family"] = "Liberation Sans"
x0, y0 = 100.0, 300_000.0; k = x0 * y0
xs = [40 + i * 0.5 for i in range(321)]
fig, ax = plt.subplots(figsize=(8.5, 4.4), dpi=200)
ax.plot(xs, [k / x / 1000 for x in xs], color="#2E5C8A", lw=2, label="x * y = k (k = 30,000,000)")
dx = 10 * 0.997; x1 = x0 + dx; y1 = k / x1
ax.plot([x0], [y0 / 1000], "o", color="#4E7D3A"); ax.plot([x1], [y1 / 1000], "o", color="#A33A3A")
ax.annotate("before: 100 WETH, 300,000 tUSD", (x0, y0 / 1000), xytext=(118, 345), fontsize=9,
            arrowprops=dict(arrowstyle="-", color="#7F7F7F"))
ax.annotate(f"after selling 10 WETH: {y0 - y1:,.0f} tUSD out\n(average 2,720 vs spot 3,000)", (x1, y1 / 1000),
            xytext=(150, 225), fontsize=9, arrowprops=dict(arrowstyle="-", color="#7F7F7F"))
ax.set_xlabel("WETH in the pool (x)"); ax.set_ylabel("tUSD in the pool (y), thousands")
ax.grid(alpha=0.3); ax.legend(loc="upper right", fontsize=9, frameon=False)
ax.set_xlim(40, 200); ax.set_ylim(100, 760)
for s in ("top", "right"): ax.spines[s].set_visible(False)
fig.tight_layout(); fig.savefig("Figure_5_3.png", facecolor="white"); print("[]")
