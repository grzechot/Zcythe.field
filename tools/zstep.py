"""Test gubienia krokow Z (Voron, 4 silniki Z, M671 1 LP, 2 LT, 3 PT, 4 PP).
G32 jako pomiar: korekta 1. przebiegu kazdego G32 = rozjazd silnikow od poprzedniego G32 (po odjeciu sredniej).
Sekwencja: G32 (baza) -> postoj --wait s bez ruchu (kontrola) -> G32 -> N cykli Z (gora/dol --amp mm z max predkoscia Z,
bez XY) -> G32 -> ponownie N cykli -> G32. Wymaga: idle, osie zbazowane.
Uzycie: python zstep.py [--cycles 300] [--amp 1.5] [--wait 180] [--opis "..."]"""
import argparse, os, re, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import voron_api as v

ap = argparse.ArgumentParser()
ap.add_argument("--cycles", type=int, default=300)
ap.add_argument("--amp", type=float, default=1.5)
ap.add_argument("--wait", type=int, default=180)
ap.add_argument("--opis", default="")
a = ap.parse_args()

v.set_log("zstep")
v.log(f"START {a.opis!r} cycles={a.cycles} amp={a.amp} wait={a.wait} | " + v.state())
if v.status() != "idle":
    v.log("STOP: status != idle"); raise SystemExit(1)
if not v.homed():
    v.log("STOP: osie niezbazowane"); raise SystemExit(1)
zmax = v.m("move.axes")[2]["speed"]   # mm/s
v.log(f"Z: max {zmax * 60:.0f} mm/min, acc {v.m('move.axes')[2]['acceleration']}, jerk {v.m('move.axes')[2]['jerk']}")

RX = re.compile(r"Leadscrew adjustments made:\s*([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)\s+([-\d.]+).*?before \(([-\d.]+), ([-\d.]+)\)")
res = []


def g32(label):
    ok, txt = v.run("G32", 900)
    m = RX.search(txt)
    if not ok or not m:
        v.log(f"STOP: G32 ({label}) nieudane: {txt[:300]!r}"); raise SystemExit(1)
    adj = [float(m.group(i)) for i in range(1, 5)]; mean = sum(adj) / 4
    rel = [x - mean for x in adj]
    passes = txt.count("Leadscrew adjustments made")
    res.append((label, rel, float(m.group(6)), passes))
    v.log(f"G32 {label}: 1. korekta wzgl. sredniej LP {rel[0]:+.3f} LT {rel[1]:+.3f} PT {rel[2]:+.3f} PP {rel[3]:+.3f} "
          f"(dev {m.group(6)}, przebiegi {passes})")


def hops(n):
    z0, z1 = 5.0, 5.0 - a.amp
    v.run(f"G90\nG1 Z{z0} F{zmax * 60:.0f}", 60)
    per = 12
    t0 = time.time()
    for k in range(0, n, per):
        blk = "\n".join(f"G1 Z{z1}\nG1 Z{z0}" for _ in range(min(per, n - k))) + "\nM400"
        ok, txt = v.run(blk, 120)
        if not ok:
            v.log(f"STOP: blad w cyklach Z: {txt[:200]!r}"); raise SystemExit(1)
    v.log(f"  {n} cykli Z {z0}<->{z1} w {time.time() - t0:.0f} s")


g32("baza")
v.log(f"postoj {a.wait} s bez ruchu"); time.sleep(a.wait)
g32("po postoju")
hops(a.cycles)
g32("po cyklach 1")
hops(a.cycles)
g32("po cyklach 2")
v.log("END " + v.state())
s = " | ".join(f"{l}: " + " ".join(f"{x:+.3f}" for x in r) + f" dev {d:.3f}" for l, r, d, p in res[1:])
v.log("PODSUMOWANIE (LP LT PT PP wzgl. sredniej): " + s)
