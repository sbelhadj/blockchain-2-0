from figlib import *
F = Fig(9.6, 4.6)
cols = [
  (20, "Externally owned account", "blue", ["nonce: transactions sent", "balance: wei", "storageRoot: empty trie", "codeHash: hash of empty code"], "controlled by a private key"),
  (340, "Contract account", "green", ["nonce: contracts created", "balance: wei", "storageRoot: its storage trie", "codeHash: hash of its bytecode"], "controlled by its code; no key"),
  (660, "EOA with EIP-7702 delegation", "amber", ["nonce: transactions + authorizations", "balance: wei", "storageRoot: its own storage", "code: 0xef0100 + target address"], "key still valid; runs target's code"),
]
W, H = 280, 300
for x, title, col, fields, foot in cols:
    F.box(x, 110, W, H, color=col)
    own = (x, 110, x + W, 110 + H)
    F.text(x + W / 2, 385, title, size=10, weight="bold", owner=own)
    for i, f in enumerate(fields):
        y = 335 - i * 50
        F.box(x + 18, y - 20, W - 36, 40, color="white", lw=0.8, round_=3)
        F.text(x + W / 2, y, f, size=8.5, owner=(x + 18, y - 20, x + W - 18, y + 20))
    F.text(x + W / 2, 132, foot, size=8.5, style="italic", color=GREY, owner=own)
F.box(660, 10, 280, 60, color="green")
F.text(800, 40, "Target contract (e.g. BatchExecutor)", size=8.5, weight="bold", owner=(660, 10, 940, 70))
F.arrow(800, 110, 800, 70)
F.crop(0, 420)
print(F.save("Figure_2_1.png"))
