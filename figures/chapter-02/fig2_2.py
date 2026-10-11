from figlib import *
F = Fig(9.6, 5.2)
# Block header
F.box(20, 330, 300, 170, color="grey")
F.text(170, 478, "Block header", size=10, weight="bold", owner=(20, 330, 320, 500))
rows = {"stateRoot": 440, "transactionsRoot": 397, "receiptsRoot": 354}
for f, y in rows.items():
    F.box(40, y - 15, 260, 30, color="white", lw=0.8, round_=3)
    F.text(170, y, f, size=8.5, owner=(40, y - 15, 300, y + 15))
# World state trie
def tri(cx, top, w, h, color, label, sub):
    F.box(cx - w / 2, top - h, w, h, color=color)
    F.text(cx, top - 25, label, size=9.5, weight="bold", owner=(cx - w / 2, top - h, cx + w / 2, top))
    F.text(cx, top - 52, sub, size=8.2, owner=(cx - w / 2, top - h, cx + w / 2, top))
tri(530, 500, 260, 75, "blue", "World state trie", "key: keccak(address)")
F.arrow(300, 440, 400, 462)
# trie nodes
F.box(470, 330, 120, 40, color="blue", lw=0.9); F.text(530, 350, "branch node", size=8.2, owner=(470,330,590,370))
F.arrow(530, 425, 530, 370)
F.box(380, 240, 120, 40, color="blue", lw=0.9); F.text(440, 260, "extension node", size=8.2, owner=(380,240,500,280))
F.box(560, 240, 120, 40, color="blue", lw=0.9); F.text(620, 260, "leaf: account", size=8.2, owner=(560,240,680,280))
F.arrow(505, 330, 455, 280); F.arrow(555, 330, 605, 280)
# account leaf detail
F.box(560, 100, 200, 110, color="white")
F.text(660, 190, "account (RLP)", size=9, weight="bold", owner=(560,100,760,210))
F.text(660, 145, "nonce, balance,\nstorageRoot, codeHash", size=8.4, owner=(560,100,760,210))
F.arrow(620, 240, 640, 210)
# storage trie
tri(860, 320, 170, 90, "green", "Storage trie", "slot to 32-byte value")
F.arrow(760, 150, 860, 230)
# tx and receipt tries
F.box(20, 230, 300, 50, color="amber"); F.text(170, 255, "Transaction trie (this block)", size=8.6, owner=(20,230,320,280))
F.box(20, 140, 300, 50, color="amber"); F.text(170, 165, "Receipt trie: status, gas, logs", size=8.6, owner=(20,140,320,190))
F.line(40, 397, 8, 397, color=LINE); F.line(8, 397, 8, 255, color=LINE); F.arrow(8, 255, 20, 255)
F.line(300, 354, 345, 354, color=LINE); F.line(345, 354, 345, 165, color=LINE); F.arrow(345, 165, 320, 165)
F.crop(90, 510)
F.ax.set_xlim(0, 960)
print(F.save("Figure_2_2.png"))
