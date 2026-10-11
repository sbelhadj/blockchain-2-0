import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch
plt.rcParams["font.family"] = "Liberation Sans"

INK = "#1A1A1A"; GREY = "#666666"; LINE = "#7F7F7F"
FILL = {"blue": "#DCE6F2", "green": "#E2F0D9", "amber": "#FCE9C8", "grey": "#EFEFEF", "red": "#F8DCDC", "white": "#FFFFFF"}
EDGE = {"blue": "#2E5C8A", "green": "#4E7D3A", "amber": "#A66A00", "grey": "#7F7F7F", "red": "#A33A3A", "white": "#7F7F7F"}

class Fig:
    def __init__(self, w, h):
        self.fig = plt.figure(figsize=(w, h), dpi=200, facecolor="white")
        self.ax = self.fig.add_axes([0, 0, 1, 1]); self.ax.set_xlim(0, w * 100); self.ax.set_ylim(0, h * 100)
        self.ax.axis("off"); self.texts = []; self.boxes = []; self.lines = []
    def box(self, x, y, w, h, color="blue", lw=1.2, round_=6):
        p = FancyBboxPatch((x, y), w, h, boxstyle=f"round,pad=0,rounding_size={round_}",
                           fc=FILL[color], ec=EDGE[color], lw=lw)
        self.ax.add_patch(p); self.boxes.append((x, y, x + w, y + h)); return p
    def text(self, x, y, s, size=9, weight="normal", color=INK, ha="center", va="center", style="normal", owner=None):
        t = self.ax.text(x, y, s, fontsize=size, fontweight=weight, color=color, ha=ha, va=va, style=style, linespacing=1.25)
        self.texts.append((t, owner)); return t
    def arrow(self, x1, y1, x2, y2, color=LINE, lw=1.1):
        self.ax.annotate("", xy=(x2, y2), xytext=(x1, y1), arrowprops=dict(arrowstyle="-|>", color=color, lw=lw, mutation_scale=10))
        self.lines.append((x1, y1, x2, y2))
    def line(self, x1, y1, x2, y2, color=LINE, lw=1.0, ls="-"):
        self.ax.plot([x1, x2], [y1, y2], color=color, lw=lw, ls=ls); self.lines.append((x1, y1, x2, y2))
    def crop(self, y0, y1):
        w = self.fig.get_figwidth(); self.ax.set_ylim(y0, y1); self.fig.set_figheight((y1 - y0) / 100)
    def check(self):
        r = self.fig.canvas.get_renderer(); inv = self.ax.transData.inverted(); errs = []
        bbs = []
        for t, owner in self.texts:
            bb = t.get_window_extent(renderer=r); (x0, y0), (x1, y1) = inv.transform([[bb.x0, bb.y0], [bb.x1, bb.y1]])
            bbs.append(((x0, y0, x1, y1), t.get_text()[:30], owner))
        for i in range(len(bbs)):
            for j in range(i + 1, len(bbs)):
                a, b = bbs[i][0], bbs[j][0]
                if a[0] < b[2] - 1 and b[0] < a[2] - 1 and a[1] < b[3] - 1 and b[1] < a[3] - 1:
                    errs.append(f"text overlap: {bbs[i][1]!r} / {bbs[j][1]!r}")
        for (bb, s, owner) in bbs:
            if owner is not None:
                X0, Y0, X1, Y1 = owner
                if bb[0] < X0 + 2 or bb[2] > X1 - 2 or bb[1] < Y0 + 2 or bb[3] > Y1 - 2:
                    errs.append(f"text overflows its box: {s!r}")
            (XL, XH), (YL, YH) = self.ax.get_xlim(), self.ax.get_ylim()
            if bb[0] < XL or bb[2] > XH or bb[1] < YL or bb[3] > YH:
                errs.append(f"text outside canvas: {s!r}")
        for (x1, y1, x2, y2) in self.lines:
            for k in range(1, 20):
                f = k / 20; px, py = x1 + (x2 - x1) * f, y1 + (y2 - y1) * f
                for (X0, Y0, X1, Y1) in self.boxes:
                    inside = X0 + 1 < px < X1 - 1 and Y0 + 1 < py < Y1 - 1
                    ends = any(X0 - 1 <= ex <= X1 + 1 and Y0 - 1 <= ey <= Y1 + 1 for ex, ey in [(x1, y1), (x2, y2)])
                    if inside and not ends:
                        errs.append(f"line through box at ({px:.0f},{py:.0f})"); break
        return errs
    def save(self, path):
        errs = self.check()
        self.fig.savefig(path, dpi=200, facecolor="white", bbox_inches="tight", pad_inches=0.12); plt.close(self.fig)
        return errs
