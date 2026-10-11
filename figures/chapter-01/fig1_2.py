from figlib import *
import itertools
X = lambda y: 60 + (y - 2013) * 62.5
AX = 280; BW, BH = 100, 40
LEVEL_UP = {1: 325, 2: 390, 3: 455}
LEVEL_DN = {1: 195, 2: 128, 3: 61}
UP = [(2015.58, "Frontier", "Jul 2015", "blue"), (2016.2, "Homestead", "Mar 2016", "blue"),
      (2017.79, "Byzantium", "Oct 2017", "blue"), (2020.92, "Beacon Chain", "Dec 2020", "blue"),
      (2021.59, "London", "Aug 2021, EIP-1559", "blue"), (2022.71, "The Merge", "Sep 2022", "blue"),
      (2023.28, "Shapella", "Apr 2023", "blue"), (2024.2, "Dencun", "Mar 2024, EIP-4844", "blue"),
      (2025.35, "Pectra", "May 2025, EIP-7702", "blue"), (2025.92, "Fusaka", "Dec 2025, PeerDAS", "blue"),
      (2026.85, "Glamsterdam", "Q4 2026, planned", "white")]
DN = [(2013.9, "Whitepaper", "late 2013", "amber"), (2014.6, "ETH crowdsale", "Jul to Sep 2014", "amber"),
      (2016.46, "DAO exploit, fork", "Jun to Jul 2016", "red"), (2017.5, "ERC-20 and ICOs", "2017", "amber"),
      (2018.84, "Uniswap v1", "Nov 2018", "amber"), (2020.5, "DeFi growth", "2020 to 2021", "amber"),
      (2022.22, "Ronin bridge hack", "Mar 2022", "red")]
XMIN, XMAX = 8, 992
def solve(events):
    placed = []
    def ok(cand):
        x, lv, xc = cand
        x0, x1 = xc - BW / 2, xc + BW / 2
        if x0 < XMIN or x1 > XMAX: return False
        if not (x0 + 6 <= x <= x1 - 6): return False
        for (px, plv, pxc) in placed:
            p0, p1 = pxc - BW / 2, pxc + BW / 2
            if plv == lv and not (x1 + 6 <= p0 or p1 + 6 <= x0): return False
            # my connector through a lower box / their connector through my lower box
            if plv < lv and p0 - 3 <= x <= p1 + 3: return False
            if lv < plv and x0 - 3 <= px <= x1 + 3: return False
        return True
    def bt(i):
        if i == len(events): return True
        x = X(events[i][0])
        for lv in (1, 2, 3):
            for off in (0, -20, 20, -35, 35, -42, 42):
                c = (x, lv, x + off)
                if ok(c):
                    placed.append(c)
                    if bt(i + 1): return True
                    placed.pop()
        return False
    assert bt(0), "no layout"
    return list(placed)
F = Fig(10, 5.6)
F.line(X(2013), AX, X(2027.3), AX, color=INK, lw=1.3)
for yr in range(2013, 2028):
    F.line(X(yr), AX - 5, X(yr), AX + 5, color=INK, lw=1.0)
    F.text(X(yr), AX - 17, str(yr), size=7.5, color=GREY)
def draw(events, layout, up):
    for (yr, name, date, color), (x, lv, xc) in zip(events, layout):
        y = LEVEL_UP[lv] if up else LEVEL_DN[lv]
        x0 = xc - BW / 2
        F.box(x0, y, BW, BH, color=color, lw=1.0, round_=4)
        F.text(xc, y + 27, name, size=7.6, weight="bold", owner=(x0, y, x0 + BW, y + BH))
        F.text(xc, y + 11, date, size=7, color=GREY, owner=(x0, y, x0 + BW, y + BH))
        F.ax.plot([x], [AX], marker="o", ms=3.2, color=EDGE[color] if color != "white" else GREY)
        if up: F.line(x, AX + 5, x, y, color=LINE, lw=0.8, ls="--" if color == "white" else "-")
        else: F.line(x, AX - 27, x, y + BH, color=LINE, lw=0.8)
draw(UP, solve(UP), True); draw(DN, solve(DN), False)
for i, (c, lab) in enumerate([("blue", "Network upgrade"), ("white", "Planned upgrade"), ("amber", "Ecosystem event"), ("red", "Incident")]):
    x = 540 + i * 112
    F.box(x, 140, 16, 12, color=c, lw=0.8, round_=2)
    F.text(x + 22, 146, lab, size=7.5, ha="left")
F.crop(115, 505)
print(F.save("Figure_1_2.png"))
