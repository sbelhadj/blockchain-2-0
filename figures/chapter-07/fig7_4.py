from figlib import *
F = Fig(9.6, 3.6)
steps = [("Legal wrapper", "fund or SPV owns the\nasset; prospectus", "grey"), ("Issuer and\ntransfer agent", "keeps the legal register;\nKYC of investors", "amber"),
         ("Token contract", "mints to allowlisted\naddresses; transfer rules", "green"), ("On-chain use", "transfers, collateral,\nsettlement against\nstablecoins", "blue"),
         ("Redemption", "token burned; cash paid\nby the fund off-chain", "grey")]
BW, H, Y = 165, 105, 130
for i, (t, s, c) in enumerate(steps):
    x = 15 + i * (BW + 27)
    F.box(x, Y, BW, H, color=c); own = (x, Y, x + BW, Y + H)
    F.text(x + BW / 2, Y + H - 26, t, size=8.8, weight="bold", owner=own)
    F.text(x + BW / 2, Y + 30, s, size=7.6, owner=own)
    if i: F.arrow(x - 27, Y + H / 2, x, Y + H / 2)
F.text(480, 85, "the token is only as good as the legal claim behind it and the parties who honour it", size=8.1, color=GREY, style="italic")
F.crop(65, 250)
print(F.save("Figure_7_4.png"))
