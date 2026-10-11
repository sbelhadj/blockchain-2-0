from figlib import *
F = Fig(9.6, 5.0)
lanes = {"Mallory (EOA)": 120, "Attacker": 420, "VulnerableVault": 760}
for name, x in lanes.items():
    F.box(x - 95, 440, 190, 40, color="grey"); F.text(x, 460, name, size=9.4, weight="bold", owner=(x - 95, 440, x + 95, 480))
    F.line(x, 440, x, 130 if x == 760 else 30, color="#BFBFBF", lw=1.0, ls="--")
msgs = [(120, 420, 405, "attack() with 1 ETH"), (420, 760, 370, "deposit() 1 ETH"), (420, 760, 335, "withdraw()"),
        (760, 420, 300, "send 1 ETH (balance still 1)"), (420, 760, 265, "receive() calls withdraw() again"),
        (760, 420, 230, "send 1 ETH (balance still 1)"), (420, 760, 195, "withdraw() again ... 10 re-entries"),
        (760, 420, 160, "send until vault holds less than 1 ETH")]
for x1, x2, y, label in msgs:
    F.arrow(x1, y, x2, y, color=INK if x1 < x2 else "#A33A3A")
    F.text((x1 + x2) / 2, y + 11, label, size=8, color=INK)
F.box(600, 75, 320, 50, color="red", lw=1.0)
F.text(760, 100, "only now: balances[attacker] = 0", size=8.6, weight="bold", owner=(600, 75, 920, 125))
F.text(270, 60, "captured test result: vault 0 ETH,\nattacker 11 ETH, 10 re-entries", size=8.4, color=GREY, style="italic")
F.crop(20, 490)
print(F.save("Figure_3_2.png"))
