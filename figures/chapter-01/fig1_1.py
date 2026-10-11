from figlib import *
F = Fig(9, 4.8)
W = 900
# Panel titles
F.text(220, 455, "Bitcoin: a script locks one output", size=11, weight="bold")
F.text(680, 455, "Ethereum: a contract keeps code and state", size=11, weight="bold")
F.line(450, 20, 450, 470, color="#BFBFBF", lw=0.8, ls="--")

# Left panel
b = (40, 330, 180, 90); F.box(*b, color="blue")
F.text(130, 390, "Transaction A", size=9.5, weight="bold", owner=(40,330,220,420))
F.text(130, 358, "output: 0.5 BTC\nlocking script", size=8.5, owner=(40,330,220,420))
b2 = (240, 330, 180, 90); F.box(*b2, color="blue")
F.text(330, 390, "Transaction B", size=9.5, weight="bold", owner=(240,330,420,420))
F.text(330, 358, "input spends A's output\nunlocking script", size=8.5, owner=(240,330,420,420))
F.arrow(220, 375, 240, 375)
b3 = (110, 190, 240, 90); F.box(*b3, color="amber")
F.text(230, 250, "Script evaluated once", size=9.5, weight="bold", owner=(110,190,350,280))
F.text(230, 215, "no loops, no stored state\nresult: valid or invalid", size=8.5, owner=(110,190,350,280))
F.arrow(330, 330, 300, 280)
b4 = (110, 55, 240, 80); F.box(*b4, color="grey")
F.text(230, 105, "Output removed from UTXO set", size=9.5, weight="bold", owner=(110,55,350,135))
F.text(230, 75, "nothing carries over to the next spend", size=8.5, owner=(110,55,350,135))
F.arrow(230, 190, 230, 135)

# Right panel
for i, (y, label) in enumerate([(360, "Transaction 1"), (250, "Transaction 2"), (140, "Transaction 3")]):
    F.box(490, y, 130, 60, color="blue")
    F.text(555, y + 38, label, size=9.5, weight="bold", owner=(490, y, 620, y + 60))
    F.text(555, y + 16, "calls a function", size=8.5, owner=(490, y, 620, y + 60))
cb = (680, 170, 180, 230); F.box(*cb, color="green")
F.text(770, 375, "Contract account", size=10, weight="bold", owner=(680,170,860,400))
F.box(700, 290, 140, 60, color="white"); F.text(770, 320, "code\n(fixed at deploy)", size=8.5, owner=(700,290,840,350))
F.box(700, 195, 140, 75, color="white"); F.text(770, 232, "storage\n(persists between\ncalls)", size=8.5, owner=(700,195,840,270))
F.arrow(620, 390, 680, 360); F.arrow(620, 280, 680, 280); F.arrow(620, 170, 680, 200)
tb = (680, 40, 180, 70); F.box(*tb, color="grey")
F.text(770, 87, "Token contract", size=9.5, weight="bold", owner=(680,40,860,110))
F.text(770, 60, "called by the contract", size=8.5, owner=(680,40,860,110))
F.arrow(770, 170, 770, 110)
print(F.save("Figure_1_1.png"))
