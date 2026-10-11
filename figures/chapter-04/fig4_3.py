from figlib import *
F = Fig(9.6, 3.4)
steps = [("Contract emits", "ConsentGranted with\nindexed patient", "green"), ("Receipt logs", "stored by nodes;\nBloom filter per block", "grey"),
         ("History", "eth_getLogs in pages\n(queryPaged)", "blue"), ("Live", "contract.on(filter):\npolling or subscription", "blue"),
         ("UI state", "re-read consents(id)\nfor current truth", "amber")]
BW, H = 160, 90
pos = [(15, 120), (205, 120), (395, 200), (395, 40), (585 + 190, 120)]
for (t, s, c), (x, y) in zip(steps, pos):
    F.box(x, y, BW, H, color=c); own = (x, y, x + BW, y + H)
    F.text(x + BW / 2, y + H - 22, t, size=9.2, weight="bold", owner=own)
    F.text(x + BW / 2, y + 28, s, size=7.8, owner=own)
F.arrow(175, 165, 205, 165)
F.arrow(365, 180, 395, 230); F.arrow(365, 150, 395, 100)
F.arrow(555, 245, 775, 185); F.arrow(555, 85, 775, 145)
F.crop(30, 300)
print(F.save("Figure_4_3.png"))
