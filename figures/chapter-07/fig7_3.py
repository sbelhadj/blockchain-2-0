from figlib import *
F = Fig(9.6, 4.2)
def b(x, y, w, h, col, t, s):
    F.box(x, y, w, h, color=col); own = (x, y, x + w, y + h)
    F.text(x + w / 2, y + h - 22, t, size=9, weight="bold", owner=own)
    F.text(x + w / 2, y + 26, s, size=7.8, owner=own)
b(15, 220, 230, 110, "blue", "Source chain", "lock contract holds\nthe original tokens")
b(345, 220, 250, 110, "amber", "Verifiers", "multisig, validators, light\nclient or optimistic watchers")
b(695, 220, 245, 110, "blue", "Destination chain", "mints wrapped tokens\nagainst verified messages")
F.arrow(245, 275, 345, 275); F.arrow(595, 275, 695, 275)
for x, t, s in [(15, "Key compromise", "Ronin, March 2022:\nvalidator keys stolen"),
                (345, "Verification bug", "Wormhole, February 2022:\nsignature check bypassed"),
                (695, "Message validation bug", "Nomad, August 2022:\nany message accepted")]:
    F.box(x + (0 if x == 15 else 0), 40, 245 if x != 345 else 250, 100, color="red")
    w = 245 if x != 345 else 250
    F.text(x + w / 2, 115, t, size=8.8, weight="bold", owner=(x, 40, x + w, 140))
    F.text(x + w / 2, 70, s, size=7.8, owner=(x, 40, x + w, 140))
F.line(130, 140, 130, 220, ls="--", color="#A33A3A"); F.line(470, 140, 470, 220, ls="--", color="#A33A3A")
F.line(817, 140, 817, 220, ls="--", color="#A33A3A")
F.crop(30, 340)
print(F.save("Figure_7_3.png"))
