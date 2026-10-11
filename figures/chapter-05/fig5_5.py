from figlib import *
F = Fig(9.6, 3.6)
steps = [("Exchanges", "spot prices from many\ntrading venues", "grey"), ("Oracle nodes", "independent operators\nfetch and sign", "blue"),
         ("Aggregator contract", "median of reports;\nupdates on deviation\nor heartbeat", "blue"), ("Consumer contract", "checks answer > 0\nand updatedAt age", "green")]
BW, H, Y = 190, 100, 140
for i, (t, s, c) in enumerate(steps):
    x = 15 + i * (BW + 45)
    F.box(x, Y, BW, H, color=c); own = (x, Y, x + BW, Y + H)
    F.text(x + BW / 2, Y + H - 22, t, size=9.2, weight="bold", owner=own)
    F.text(x + BW / 2, Y + 34, s, size=7.9, owner=own)
    if i: F.arrow(x - 45, Y + H / 2, x, Y + H / 2)
F.text(15 + 0.5 * (BW * 2 + 45), 100, "off-chain", size=8.4, color=GREY, style="italic")
F.text(15 + 2 * (BW + 45) + (BW * 2 + 45) / 2, 100, "on-chain", size=8.4, color=GREY, style="italic")
F.text(480, 60, "a single DEX pool as the price source is the classic manipulation target", size=8.2, color=GREY, style="italic")
F.crop(40, 255)
print(F.save("Figure_5_5.png"))
