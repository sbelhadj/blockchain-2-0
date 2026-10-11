# Figure 2.5 is drawn from the captured output of Listing 2.4.
import re
from figlib import *
cap = open("../../captured-outputs/chapter-02/listing-2-2.txt").read()
g = lambda k: re.search(k + r"\s+([\d.]+)", cap).group(1)
gas, base, eff = int(g("gasUsed")), float(g("block baseFee")), float(g("effective price"))
tip = eff - base
F = Fig(9.6, 3.4)
X0, X1 = 60, 900
scale = (X1 - X0) / eff
F.text(X0, 300, f"Effective gas price {eff:.9f} gwei, gas used {gas:,} (Listing 2.2)", size=9.5, weight="bold", ha="left")
wb = base * scale
F.box(X0, 170, wb, 80, color="red", round_=2)
F.text(X0 + wb / 2, 225, "Base fee", size=9.5, weight="bold", owner=(X0, 170, X0 + wb, 250))
F.text(X0 + wb / 2, 192, f"{base:.9f} gwei\nburned", size=8.2, owner=(X0, 170, X0 + wb, 250))
F.box(X0 + wb, 170, tip * scale, 80, color="green", round_=2)
F.text(X0 + wb + tip * scale / 2, 225, "Priority fee", size=9.5, weight="bold", owner=(X0 + wb, 170, X1, 250))
F.text(X0 + wb + tip * scale / 2, 192, f"{tip:.9f} gwei\nto the block proposer", size=8.2, owner=(X0 + wb, 170, X1, 250))
F.text(X0, 120, f"Burned:      {gas:,} x {base:.9f} gwei = {gas*base/1e9:.18f} ETH", size=8.6, ha="left")
F.text(X0, 90, f"To proposer: {gas:,} x {tip:.9f} gwei = {gas*tip/1e9:.18f} ETH", size=8.6, ha="left")
F.text(X0, 55, "maxFeePerGas caps base fee + priority fee; anything below the cap is never charged.", size=8.2, ha="left", color=GREY, style="italic")
F.crop(35, 320)
print(F.save("Figure_2_5.png"))
