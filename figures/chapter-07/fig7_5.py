from figlib import *
F = Fig(9.6, 4.6)
tracks = [("The Merge", "proof of stake", [("Merge", "shipped 2022", "green"), ("withdrawals", "shipped 2023", "green")]),
          ("The Surge", "rollup scaling", [("blobs", "shipped 2024", "green"), ("PeerDAS", "shipped 2025", "green"), ("more blobs", "in progress", "amber")]),
          ("The Scourge", "MEV and fairness", [("ePBS", "in testing (Glamsterdam)", "amber")]),
          ("The Verge", "stateless clients", [("new state tree", "planned", "white")]),
          ("The Purge", "less data to keep", [("history expiry", "partial", "amber")]),
          ("The Splurge", "everything else", [("EIP-7702", "shipped 2025", "green"), ("access lists", "in testing", "amber")])]
for i, (name, sub, items) in enumerate(tracks):
    y = 380 - i * 66
    F.box(15, y, 200, 54, color="grey"); F.text(115, y + 36, name, size=9, weight="bold", owner=(15, y, 215, y + 54))
    F.text(115, y + 15, sub, size=7.6, color=GREY, owner=(15, y, 215, y + 54))
    for j, (t, s, c) in enumerate(items):
        x = 240 + j * 235
        F.box(x, y, 215, 54, color=c); F.text(x + 107, y + 36, t, size=8.6, weight="bold", owner=(x, y, x + 215, y + 54))
        F.text(x + 107, y + 15, s, size=7.6, owner=(x, y, x + 215, y + 54))
F.text(480, 30, "status as of October 2026; check ethereum.org/roadmap for changes", size=8.1, color=GREY, style="italic")
F.crop(15, 445)
print(F.save("Figure_7_5.png"))
