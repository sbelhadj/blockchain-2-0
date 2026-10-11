from figlib import *
F = Fig(9, 4.9)
layers = [  # bottom to top
  ("Layer 1 network", "proof of stake consensus, EVM execution, the shared state", "Geth, Nethermind, Lighthouse, Prysm", "Ch. 2, 6", "blue"),
  ("Layer 2 rollups", "execute off the main chain, post data and proofs to Layer 1", "Arbitrum, OP Mainnet, Base", "Ch. 6", "blue"),
  ("Contracts and standards", "Solidity compiled to EVM bytecode; shared token interfaces", "OpenZeppelin, ERC-20, ERC-721, ERC-4626", "Ch. 3, 5, Labs 1, 3", "green"),
  ("Access and tooling", "build, test and deploy contracts; sign and send transactions", "Hardhat, ethers.js, RPC providers, MetaMask", "Ch. 3, 4, all labs", "amber"),
  ("Applications", "user-facing software that reads and writes contract state", "dApps, DeFi protocols, consent registries", "Ch. 4, 5, Lab 2", "amber"),
]
F.text(110, 470, "Layer", size=9, weight="bold", color=GREY)
F.text(420, 470, "What it does / examples used in this book", size=9, weight="bold", color=GREY)
F.text(800, 470, "Covered in", size=9, weight="bold", color=GREY)
H, GAP, Y0 = 72, 14, 20
for i, (name, does, ex, ch, c) in enumerate(layers):
    y = Y0 + i * (H + GAP)
    F.box(20, y, 860, H, color=c)
    own = (20, y, 880, y + H)
    F.text(110, y + H / 2, name, size=9.5, weight="bold", owner=own)
    F.line(200, y + 10, 200, y + H - 10, color=EDGE[c], lw=0.8)
    F.text(215, y + 47, does, size=8.8, ha="left", owner=own)
    F.text(215, y + 23, ex, size=8.5, ha="left", color=GREY, style="italic", owner=own)
    F.line(715, y + 10, 715, y + H - 10, color=EDGE[c], lw=0.8)
    F.text(800, y + H / 2, ch, size=8.8, owner=own)
F.crop(10, 485)
print(F.save("Figure_1_3.png"))
