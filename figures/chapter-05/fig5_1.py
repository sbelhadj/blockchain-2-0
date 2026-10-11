from figlib import *
F = Fig(9.6, 3.8)
lanes = {"Alice (EOA)": 120, "Token contract (tUSD)": 470, "Pool contract": 800}
for name, x in lanes.items():
    F.box(x - 110, 320, 220, 40, color="grey"); F.text(x, 340, name, size=9.2, weight="bold", owner=(x - 110, 320, x + 110, 360))
    F.line(x, 320, x, 30, color="#BFBFBF", lw=1.0, ls="--")
msgs = [(120, 470, 280, "1. approve(pool, 250)  sets allowance[alice][pool] = 250"),
        (120, 800, 220, "2. deposit(100)  Alice calls the pool"),
        (800, 470, 160, "3. transferFrom(alice, pool, 100)  allowance 250 -> 150"),
        (470, 800, 100, "4. balances updated; Transfer event")]
for x1, x2, y, label in msgs:
    F.arrow(x1, y, x2, y)
    F.text((x1 + x2) / 2, y + 13, label, size=8.2)
F.text(470, 45, "two transactions from Alice; with ERC-2612 permit, step 1 becomes an off-chain signature", size=8, color=GREY, style="italic")
F.crop(25, 370)
print(F.save("Figure_5_1.png"))
