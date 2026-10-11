from figlib import *
F = Fig(9.6, 3.9)
steps = [("1 Build", "wallet sets nonce,\ngas limit, fees"), ("2 Sign", "secp256k1 key\nsigns the payload"),
         ("3 Broadcast", "RPC node checks it\nand gossips it"), ("4 Include", "proposer picks it\nfor a 12 s slot"),
         ("5 Execute", "every node runs it;\nreceipt and logs"), ("6 Finalize", "two epochs later,\nabout 12.8 minutes")]
BW, H, Y = 140, 95, 190
cols = ["blue", "blue", "amber", "amber", "green", "green"]
for i, ((t, s), c) in enumerate(zip(steps, cols)):
    x = 15 + i * (BW + 18)
    F.box(x, Y, BW, H, color=c); own = (x, Y, x + BW, Y + H)
    F.text(x + BW / 2, Y + H - 24, t, size=9.4, weight="bold", owner=own)
    F.text(x + BW / 2, Y + 30, s, size=8, owner=own)
    if i: F.arrow(x - 18, Y + H / 2, x, Y + H / 2)
F.text(15 + (BW*2+18)/2, 160, "your machine", size=8.4, color=GREY, style="italic")
F.text(15 + 2*(BW+18) + (BW*2+18)/2, 160, "network and mempool", size=8.4, color=GREY, style="italic")
F.text(15 + 4*(BW+18) + (BW*2+18)/2, 160, "chain", size=8.4, color=GREY, style="italic")
for i in range(3):
    x0 = 15 + 2 * i * (BW + 18); F.line(x0, 172, x0 + 2 * BW + 18, 172, color=LINE, lw=0.8)
F.crop(140, 300)
print(F.save("Figure_2_6.png"))
