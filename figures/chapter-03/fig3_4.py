from figlib import *
F = Fig(9.6, 3.6)
def st(x, y, t, c):
    F.box(x, y, 190, 60, color=c, round_=14); F.text(x + 95, y + 30, t, size=9.4, weight="bold", owner=(x, y, x + 190, y + 60))
st(20, 170, "AwaitingPayment", "grey")
st(360, 170, "AwaitingDelivery", "blue")
st(720, 250, "Complete", "green")
st(720, 90, "Refunded", "amber")
F.arrow(210, 200, 360, 200); F.text(285, 222, "pay()  buyer, exact price", size=8.2)
F.arrow(550, 215, 720, 280); F.text(625, 275, "confirmDelivery()  agent", size=8.2)
F.arrow(550, 185, 720, 120); F.text(625, 125, "refund()  agent", size=8.2)
F.text(470, 60, "any other call in any state reverts with WrongState or OnlyRole", size=8.2, color=GREY, style="italic")
F.crop(40, 330)
print(F.save("Figure_3_4.png"))
