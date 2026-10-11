from figlib import *
F = Fig(9.6, 3.8)
steps = [("1 Authorize", "EOA signs (chainId,\ntarget, nonce)", "blue"), ("2 Type 4 tx", "anyone submits the\nauthorization list", "blue"),
         ("3 Code set", "EOA code becomes\n0xef0100 + target", "green"), ("4 Calls", "run the target's code\nwith the EOA's storage\nand balance", "green"),
         ("5 Clear or change", "new authorization;\nzero address clears", "amber")]
BW, H, Y = 160, 105, 150
for i, (t, s, c) in enumerate(steps):
    x = 15 + i * (BW + 32)
    F.box(x, Y, BW, H, color=c); own = (x, Y, x + BW, Y + H)
    F.text(x + BW / 2, Y + H - 22, t, size=9.2, weight="bold", owner=own)
    F.text(x + BW / 2, Y + 36, s, size=7.8, owner=own)
    if i: F.arrow(x - 32, Y + H / 2, x, Y + H / 2)
F.text(480, 100, "the private key keeps full control throughout: it can still sign transactions and replace the delegation", size=8.1, color=GREY, style="italic")
F.text(480, 70, "risk: delegating to malicious or buggy code hands that code the account's assets", size=8.1, color="#A33A3A", style="italic")
F.crop(50, 270)
print(F.save("Figure_7_2.png"))
