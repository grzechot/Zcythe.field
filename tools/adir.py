"""Test kierunku dojazdu w X (Voron, sonda K0) w strefie wady 1. warstwy (tyl lewy, 19.10). Na zimno, mapa wylaczona.
W kazdym punkcie (wsp. sondy K0) trzy serie dojazdow na wysokosci hop (odjazd 20 mm i powrot), po kazdym 2 zjazdy
G38.3 K0 F80 (z 0.5 mm), srednia:
  A: 3x z tej samej strony: dojazd w kierunku +X (z lewej)
  B: 3x z drugiej strony:  dojazd w kierunku -X (z prawej)
  C: 3x naprzemiennie +X / -X (6 dojazdow)
Glowica nie zbliza sie do lewego konca X (efekt zad. 12: dysza X < 60). Wymaga: idle; --prep = najpierw G28 i G32.
Uzycie: python adir.py [--prep] [--n 3] [--opis "..."]
Wynik: data/adir_*.csv, log data/logs/adir_*.log, linia PODSUMOWANIE."""
import argparse, csv, os, statistics as st, sys, time, urllib.parse
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import voron_api as v

ap = argparse.ArgumentParser()
ap.add_argument("--prep", action="store_true")
ap.add_argument("--n", type=int, default=3)
ap.add_argument("--opis", default="")
a = ap.parse_args()

# punkty sondy: 3 w strefie wady (granica X100-Y300, X200-Y320, X300-Y350) + 1 odniesienia poza nia
PTS = [(100, 335), (200, 345), (300, 360), (200, 200)]
TS = time.strftime("%Y%m%d_%H%M")
v.set_log("adir")
v.log(f"START {a.opis!r} n={a.n} prep={a.prep} | " + v.state())
if v.status() != "idle":
    v.log("PODSUMOWANIE: status != idle - stop"); raise SystemExit(1)


def send(code, tmax=60):
    v.get("/rr_reply")
    v.get("/rr_gcode?gcode=" + urllib.parse.quote(code))
    t0 = time.time(); last = None; stable = 0
    while time.time() - t0 < tmax:
        time.sleep(0.3)
        z = v.m("move.axes")[2]["machinePosition"]
        rep = v.get("/rr_reply").strip()
        if "rror" in rep:
            v.log(f"ERROR {code}: {rep}"); raise SystemExit(1)
        stable = stable + 1 if (last is not None and abs(z - last) < 1e-4) else 0
        last = z
        if v.m("state")["status"] == "idle" and stable >= 2 and not v.http_busy():
            return z
    v.log(f"TIMEOUT {code}"); raise SystemExit(1)


if a.prep:
    for c, t in (("G28", 300), ("G32", 900)):
        ok, txt = v.run(c, t)
        v.log(f"{c} ok={ok}: {txt[:300]!r}")
        if not ok:
            v.log(f"PODSUMOWANIE: {c} nieudane - stop"); raise SystemExit(1)
if not v.homed():
    v.log("PODSUMOWANIE: osie niezbazowane - stop (uzyj --prep)"); raise SystemExit(1)

p = v.m("sensors.probes")[0]; trig = p["triggerHeight"]; ox, oy = p["offsets"][0], p["offsets"][1]
ax0 = v.m("move.axes"); acc = (ax0[0]["acceleration"], ax0[1]["acceleration"]); jerk = (ax0[0]["jerk"], ax0[1]["jerk"])
hop = max(1.5, trig + 0.8)
raw = []; t_start = time.time()


def approach(nx, ny, side):
    """side +1 = dojazd w kierunku +X (start z lewej), -1 = w kierunku -X (start z prawej)"""
    send(f"G1 Z{hop:.3f} F6000")
    send(f"G1 X{nx - side * 20:.3f} Y{ny:.3f} F12000")
    send(f"G1 X{nx:.3f} Y{ny:.3f} F12000")
    hs = []
    for i in range(2):
        if v.m("sensors.probes")[0]["value"][0] > 0:
            v.log("K0 zadzialana przed zjazdem - stop"); raise SystemExit(1)
        z = send(f"G38.3 K0 Z{trig - 2:.3f} F80")
        if v.m("sensors.probes")[0]["value"][0] == 0:
            v.log(f"brak zadzialania X{nx} Y{ny} - stop"); raise SystemExit(1)
        send(f"G1 Z{z + 0.5:.3f} F600")
        hs.append(z - trig)
    return hs


try:
    send("M201 X2000 Y2000"); send("M566 X300 Y300"); send("G29 S2")
    send(f"G1 Z{hop:.3f} F6000")
    for (px, py) in PTS:
        nx, ny = px - ox, py - oy
        seq = [("A", +1)] * a.n + [("B", -1)] * a.n + [("C", s) for _ in range(a.n) for s in (+1, -1)]
        for k, (ser, side) in enumerate(seq):
            hs = approach(nx, ny, side)
            raw.append([round(time.time() - t_start, 1), px, py, ser, "+X" if side > 0 else "-X", k + 1,
                        round(hs[0], 4), round(hs[1], 4), round(st.mean(hs), 4)])
        v.log(f"punkt X{px} Y{py} gotowy, {time.time() - t_start:.0f} s")
    send(f"G1 Z{hop:.3f} F6000")
finally:
    send("M201 X%s Y%s" % acc); send("M566 X%s Y%s" % jerk)
    v.log("END " + v.state())
    fr = os.path.join(v.DATA, f"adir_{TS}.csv")
    with open(fr, "w", newline="") as fh:
        csv.writer(fh).writerows([["t_s", "probeX", "probeY", "seria", "kier", "nr", "h1", "h2", "h"]] + raw)

summ = []
for (px, py) in PTS:
    r = [x for x in raw if (x[1], x[2]) == (px, py)]
    A = [x[8] for x in r if x[3] == "A"]; B = [x[8] for x in r if x[3] == "B"]
    Cp = [x[8] for x in r if x[3] == "C" and x[4] == "+X"]; Cm = [x[8] for x in r if x[3] == "C" and x[4] == "-X"]
    v.log(f"X{px} Y{py}: A(+X) {' '.join(f'{h:+.4f}' for h in A)} | B(-X) {' '.join(f'{h:+.4f}' for h in B)}")
    v.log(f"   C +X {' '.join(f'{h:+.4f}' for h in Cp)} | C -X {' '.join(f'{h:+.4f}' for h in Cm)}")
    dAB = st.mean(B) - st.mean(A); dC = st.mean(Cm) - st.mean(Cp)
    v.log(f"   B-A {dAB:+.4f}  C(-X)-C(+X) {dC:+.4f}  sd A {st.pstdev(A):.4f} B {st.pstdev(B):.4f}")
    summ.append(f"X{px}Y{py} B-A {dAB:+.4f} C {dC:+.4f}")
v.log("PODSUMOWANIE: " + " | ".join(summ) + f" | CSV {fr}")
