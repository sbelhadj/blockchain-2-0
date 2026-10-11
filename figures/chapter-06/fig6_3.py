from figlib import *
F = Fig(9.6, 4.6)
def b(x, y, w, h, col, t, s=""):
    F.box(x, y, w, h, color=col); own = (x, y, x + w, y + h)
    F.text(x + w / 2, y + h - 20 if s else y + h / 2, t, size=8.8, weight="bold", owner=own)
    if s: F.text(x + w / 2, y + 20, s, size=7.7, owner=own)
for row, (title, y, steps) in enumerate([
    ("Optimistic rollup", 300, [("Sequencer", "orders L2 transactions", "grey"), ("Batch + state root", "data in blobs, root posted", "blue"),
                                ("Challenge window", "about 7 days; anyone can\nsubmit a fraud proof", "amber"), ("Final on L1", "withdrawals released", "green")]),
    ("ZK rollup", 90, [("Sequencer", "orders L2 transactions", "grey"), ("Prover", "builds a validity proof", "blue"),
                       ("Verifier contract", "checks the proof on L1", "amber"), ("Final on L1", "once the proof is verified", "green")])]):
    F.text(20, y + 120, title, size=10, weight="bold", ha="left")
    for i, (t, s, c) in enumerate(steps):
        x = 20 + i * 235
        b(x, y, 200, 95, c, t, s)
        if i: F.arrow(x - 35, y + 47, x, y + 47)
F.text(480, 40, "both post their data to Ethereum; they differ in how L1 learns that the new state is correct", size=8.1, color=GREY, style="italic")
F.crop(25, 435)
print(F.save("Figure_6_3.png"))
