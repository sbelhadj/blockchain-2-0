from figlib import *
F = Fig(9.6, 3.8)
chain = [("Stablecoin", "depegs", "red"), ("Lending pool", "collateral worth\nless than assumed", "amber"),
         ("Liquidations", "large sales of\ncollateral", "amber"), ("DEX pools", "prices pushed\nfurther down", "amber"),
         ("Vaults and LPs", "losses for users\nwho never touched\nthe stablecoin", "red")]
BW, H, Y = 160, 100, 160
for i, (t, s, c) in enumerate(chain):
    x = 15 + i * (BW + 32)
    F.box(x, Y, BW, H, color=c); own = (x, Y, x + BW, Y + H)
    F.text(x + BW / 2, Y + H - 22, t, size=9.2, weight="bold", owner=own)
    F.text(x + BW / 2, Y + 34, s, size=7.9, owner=own)
    if i: F.arrow(x - 32, Y + H / 2, x, Y + H / 2)
F.line(15 + 3 * (BW + 32) + BW / 2, Y, 15 + 3 * (BW + 32) + BW / 2, 110)
F.line(15 + 3 * (BW + 32) + BW / 2, 110, 15 + 1 * (BW + 32) + BW / 2, 110)
F.arrow(15 + 1 * (BW + 32) + BW / 2, 110, 15 + 1 * (BW + 32) + BW / 2, Y)
F.text(15 + 2 * (BW + 32) + BW / 2, 92, "lower DEX prices feed back into the oracle and trigger more liquidations", size=8, color=GREY, style="italic")
F.crop(75, 275)
print(F.save("Figure_5_6.png"))
