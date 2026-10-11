from figlib import *
F = Fig(9.6, 3.8)
rows = ["Where it lives", "Visible to the EVM", "Kept by nodes", "Priced by", "Typical use"]
cols = [("Calldata", "blue", ["inside the transaction, in\nevery block forever", "yes", "permanently (as history)", "regular gas, 16 per\nnon-zero byte", "inputs to contracts"]),
        ("Blobs (EIP-4844)", "green", ["sidecar of about 128 KB,\ncommitted in the block", "no: only a commitment\n(BLOBHASH)", "about 18 days", "separate blob base fee", "rollup batch data"])]
F.text(120, 340, "", size=8)
for i, r in enumerate(rows):
    y = 270 - i * 55
    F.box(20, y, 190, 48, color="grey", lw=0.8); F.text(115, y + 24, r, size=8.6, weight="bold", owner=(20, y, 210, y + 48))
for j, (name, col, vals) in enumerate(cols):
    x = 230 + j * 350
    F.box(x, 325, 330, 40, color=col); F.text(x + 165, 345, name, size=9.6, weight="bold", owner=(x, 325, x + 330, 365))
    for i, v in enumerate(vals):
        y = 270 - i * 55
        F.box(x, y, 330, 48, color="white", lw=0.8); F.text(x + 165, y + 24, v, size=8.1, owner=(x, y, x + 330, y + 48))
F.crop(45, 375)
print(F.save("Figure_6_4.png"))
