from figlib import *
F = Fig(9.6, 4.6)
lanes = {"Admin": 90, "Patient": 330, "PatientConsent": 600, "Provider": 860}
for n, x in lanes.items():
    F.box(x - 80, 420, 160, 36, color="grey"); F.text(x, 438, n, size=9, weight="bold", owner=(x - 80, 420, x + 80, 456))
    F.line(x, 420, x, 20, color="#BFBFBF", lw=1.0, ls="--")
msgs = [(90, 600, 385, "0. grantRole(PROVIDER_ROLE, provider)", INK), (330, 600, 330, "1. grantConsent(provider, LAB_RESULTS, 30, hash)", INK),
        (860, 600, 275, "hasActiveConsent: true", INK), (860, 600, 220, "2. recordAccess(patient, LAB_RESULTS, READ)", INK),
        (330, 600, 165, "3. revokeConsent(id)", INK), (860, 600, 110, "4. recordAccess: reverts NoActiveConsent", "#A33A3A")]
for x1, x2, y, label, col in msgs:
    F.arrow(x1, y, x2, y, color=col)
    F.text((x1 + x2) / 2, y + 12, label, size=7.9, color=col)
F.text(480, 45, "every step except 4 emits an event; step 4 leaves no trace on chain", size=8, color=GREY, style="italic")
F.crop(30, 465)
print(F.save("Figure_L2_2.png"))
