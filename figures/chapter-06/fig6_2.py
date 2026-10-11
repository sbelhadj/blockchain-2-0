from figlib import *
F = Fig(9.6, 3.4)
X0, W = 40, 880
for e in range(3):
    x = X0 + e * W / 3
    F.box(x + 4, 150, W / 3 - 8, 60, color=["green", "blue", "grey"][e])
    F.text(x + W / 6, 195, f"epoch N{'+' + str(e) if e else ''}", size=9.2, weight="bold", owner=(x + 4, 150, x + W / 3 - 4, 210))
    F.text(x + W / 6, 167, "32 slots x 12 s = 6.4 min", size=7.9, owner=(x + 4, 150, x + W / 3 - 4, 210))
    for s in range(32):
        sx = x + 10 + s * (W / 3 - 20) / 32
        F.line(sx, 120, sx, 138, color="#9F9F9F", lw=0.7)
F.text(X0 + 4, 100, "each slot: one proposer, a committee of attesters", size=8, color=GREY, ha="left", style="italic")
for e, (lab, col) in enumerate([("finalized", "green"), ("justified", "blue"), ("current", "grey")]):
    x = X0 + e * W / 3 + 4
    F.ax.plot([x], [235], marker="v", ms=9, color=EDGE[col])
    F.text(x + 6, 250, f"checkpoint: {lab}", size=8.2, ha="left")
F.text(480, 50, "a checkpoint is justified by votes from 2/3 of staked ETH, finalized when the next one is justified", size=8.1, color=GREY, style="italic")
F.crop(35, 270)
print(F.save("Figure_6_2.png"))
