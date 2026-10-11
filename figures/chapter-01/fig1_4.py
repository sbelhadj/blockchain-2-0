from figlib import *
F = Fig(9, 4.4)
rows = [
  ("Finance and banking", "tokenized bonds, escrowed\npayments, lending pools", "Ch. 3 escrow, Ch. 5 lending\npool, Lab 3 token"),
  ("Healthcare", "patient consent with\nexpiry and revocation", "Ch. 4 consent dApp,\nLab 2"),
  ("Logistics and transport", "shipment state machine,\nsettlement token", "Ch. 3 state machine,\nLab 3 extension"),
  ("Industrial operations", "equipment and certification\nregistry", "Lab 1 AssetRegistry,\nCh. 2 event logs"),
]
F.text(120, 420, "Sector", size=9, weight="bold", color=GREY)
F.text(450, 420, "Contract pattern", size=9, weight="bold", color=GREY)
F.text(770, 420, "Where you build it", size=9, weight="bold", color=GREY)
H, GAP = 76, 20
for i, (sec, pat, where) in enumerate(rows):
    y = 300 - i * (H + GAP)
    F.box(20, y, 200, H, color="blue"); F.text(120, y + H / 2, sec, size=9.5, weight="bold", owner=(20, y, 220, y + H))
    F.box(330, y, 240, H, color="green"); F.text(450, y + H / 2, pat, size=8.8, owner=(330, y, 570, y + H))
    F.box(670, y, 200, H, color="amber"); F.text(770, y + H / 2, where, size=8.8, owner=(670, y, 870, y + H))
    F.arrow(220, y + H / 2, 330, y + H / 2); F.arrow(570, y + H / 2, 670, y + H / 2)
F.crop(5, 435)
print(F.save("Figure_1_4.png"))
