from figlib import *
F = Fig(9.6, 3.8)
def col(x, title, order, colors, note):
    F.text(x + 160, 335, title, size=10, weight="bold")
    for i, (t, c) in enumerate(zip(order, colors)):
        y = 250 - i * 75
        F.box(x, y, 320, 55, color=c); F.text(x + 160, y + 27, t, size=8.8, owner=(x, y, x + 320, y + 55))
        if i: F.arrow(x + 160, y + 75, x + 160, y + 55)
    F.text(x + 160, 75, note, size=8.2, color=GREY, style="italic")
col(30, "VulnerableVault.withdraw", ["Check: amount > 0", "Interaction: send ether to caller", "Effect: balances[caller] = 0"],
    ["blue", "red", "amber"], "the caller runs code before the balance changes")
col(500, "SecureVault.withdraw", ["Check: amount > 0", "Effect: balances[caller] = 0", "Interaction: send ether to caller"],
    ["blue", "amber", "green"], "a re-entry sees a zero balance (and hits nonReentrant)")
F.crop(60, 355)
print(F.save("Figure_3_3.png"))
