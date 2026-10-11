from figlib import *
F = Fig(9.6, 3.6)
steps = [("Write", "Solidity in VS Code\nor Remix", "grey"), ("Compile", "solc 0.8.34 via\nHardhat 3", "grey"),
         ("Test", "Mocha and Solidity\ntests, coverage", "blue"), ("Analyze", "Slither, review,\naudit", "blue"),
         ("Deploy", "Ignition to a\ntestnet first", "green"), ("Verify", "source published\non Etherscan", "green")]
BW, H, Y = 135, 90, 170
for i, (t, s, col) in enumerate(steps):
    x = 15 + i * (BW + 25)
    F.box(x, Y, BW, H, color=col); own = (x, Y, x + BW, Y + H)
    F.text(x + BW / 2, Y + H - 24, t, size=9.6, weight="bold", owner=own)
    F.text(x + BW / 2, Y + 30, s, size=8.2, owner=own)
    if i: F.arrow(x - 25, Y + H / 2, x, Y + H / 2)
# feedback loop from Test/Analyze back to Write
F.line(15 + 3 * (BW + 25) + BW / 2, Y, 15 + 3 * (BW + 25) + BW / 2, 120)
F.line(15 + 3 * (BW + 25) + BW / 2, 120, 15 + BW / 2, 120)
F.arrow(15 + BW / 2, 120, 15 + BW / 2, Y)
F.line(15 + 2 * (BW + 25) + BW / 2, Y, 15 + 2 * (BW + 25) + BW / 2, 120)
F.text(330, 100, "a failing test or a finding sends you back to the code", size=8.2, color=GREY, style="italic")
F.text(800, 125, "after deployment, the\ncode cannot be patched", size=8.2, color=GREY, style="italic")
F.crop(80, 270)
print(F.save("Figure_3_1.png"))
