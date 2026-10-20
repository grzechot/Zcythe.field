"""Mapa stabilnosci stolu (Voron, sonda K0). Siatka Mesh 7x7 (wspolrzedne sondy), mapa wylaczona,
N przebiegow (serpentyna, co drugi przebieg w odwrotnej kolejnosci), w kazdym punkcie D zjazdow G38.3 K0 F80 z 0.5 mm.
Na poczatku i koncu kazdego przebiegu punkt odniesienia X200 Y187 -> dryf calosci odejmowany liniowo w czasie.
Wynik na punkt: srednia, sd w punkcie (powtarzalnosc), rozstep miedzy przebiegami po odjeciu dryfu (stabilnosc).
Klasy: S <= 0.010, M <= 0.020, U > 0.020. Wymaga: idle, osie zbazowane (G28 + G32 robi --prep).
Uzycie: python bedstab.py [--n 4] [--d 3] [--prep] [--opis "..."]"""
import argparse, csv, os, statistics as st, sys, time, urllib.parse
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import voron_api as v

ap = argparse.ArgumentParser()
ap.add_argument("--n", type=int, default=4, help="liczba przebiegow")
ap.add_argument("--d", type=int, default=3, help="zjazdow w punkcie")
ap.add_argument("--prep", action="store_true", help="najpierw G28 i G32")
ap.add_argument("--opis", default="")
a = ap.parse_args()

XS = [5 + 65 * i for i in range(7)]
YS = [10 + 59 * j for j in range(7)]
REF = (200, 187)
TS = time.strftime("%Y%m%d_%H%M")
v.set_log("bedstab")
v.log(f"START {a.opis!r} n={a.n} d={a.d} | " + v.state())
if v.status() != "idle":
    v.log("STOP: status != idle"); raise SystemExit(1)


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
    for c, t in (("G28", 300), ("G32", 600)):
        ok, txt = v.run(c, t)
        if not ok:
            v.log(f"STOP: {c} nieudane"); raise SystemExit(1)
if not v.homed():
    v.log("STOP: osie niezbazowane (uzyj --prep)"); raise SystemExit(1)

p = v.m("sensors.probes")[0]; trig = p["triggerHeight"]; ox, oy = p["offsets"][0], p["offsets"][1]
ax0 = v.m("move.axes"); acc = (ax0[0]["acceleration"], ax0[1]["acceleration"]); jerk = (ax0[0]["jerk"], ax0[1]["jerk"])
comp0 = v.m("move.compensation")["type"]
hop = max(1.5, trig + 0.8)
raw = []   # przebieg, kolejnosc, czas, px, py, nr zjazdu, h
t_start = time.time()


def probe(px, py, npass, k):
    send(f"G1 Z{hop:.3f} F6000")
    send(f"G1 X{px - ox:.3f} Y{py - oy:.3f} F24000")
    hs = []
    for i in range(a.d):
        if v.m("sensors.probes")[0]["value"][0] > 0:
            v.log("K0 zadzialana przed zjazdem - stop"); raise SystemExit(1)
        z = send(f"G38.3 K0 Z{trig - 2:.3f} F80")
        if v.m("sensors.probes")[0]["value"][0] == 0:
            v.log(f"brak zadzialania X{px} Y{py} - stop"); raise SystemExit(1)
        send(f"G1 Z{z + 0.5:.3f} F600")
        h = z - trig; hs.append(h)
        raw.append([npass, k, round(time.time() - t_start, 1), px, py, i + 1, round(h, 4)])
    return hs


try:
    send("M201 X2000 Y2000"); send("M566 X300 Y300"); send("G29 S2")
    send(f"G1 Z{hop:.3f} F6000")
    order = [(x, y) for j, y in enumerate(YS) for x in (XS if j % 2 == 0 else XS[::-1])]
    for n in range(1, a.n + 1):
        h = v.m("heat.heaters")
        v.log(f"przebieg {n}/{a.n}: stol {h[0]['current']:.1f} C, dysza {h[1]['current']:.1f} C")
        seq = order if n % 2 == 1 else order[::-1]
        r0 = st.mean(probe(*REF, n, 0))
        for k, (px, py) in enumerate(seq, 1):
            hs = probe(px, py, n, k)
        r1 = st.mean(probe(*REF, n, len(seq) + 1))
        v.log(f"  przebieg {n}: odniesienie {r0:+.4f} -> {r1:+.4f} (dryf {r1 - r0:+.4f}), {time.time() - t_start:.0f} s")
    send(f"G1 Z{hop:.3f} F6000")
finally:
    send("M201 X%s Y%s" % acc); send("M566 X%s Y%s" % jerk)
    if comp0 != "none":
        send('G29 S1 P"0:/sys/heightmap_ext.csv"')
    v.log("END " + v.state())
    fr = os.path.join(v.DATA, f"bedstab_{TS}_raw.csv")
    with open(fr, "w", newline="") as fh:
        csv.writer(fh).writerows([["przebieg", "kolejnosc", "t_s", "probeX", "probeY", "zjazd", "h"]] + raw)

# dryf: odniesienie (kolejnosc 0 i ostatnia) w funkcji czasu -> interpolacja liniowa po calym tescie
refs = sorted((r[2], r[6]) for r in raw if (r[3], r[4]) == REF and r[1] in (0, len(XS) * len(YS) + 1))
def drift(t):
    if len(refs) < 2:
        return 0.0
    for (t0, h0), (t1, h1) in zip(refs, refs[1:]):
        if t <= t1:
            return h0 + (h1 - h0) * max(0.0, t - t0) / max(t1 - t0, 1e-6) - refs[0][1]
    return refs[-1][1] - refs[0][1]

rows = []; grid = {}
for y in YS:
    for x in XS:
        pts = [r for r in raw if (r[3], r[4]) == (x, y) and 1 <= r[1] <= len(XS) * len(YS)]
        per = {}
        for r in pts:
            per.setdefault(r[0], []).append(r[6] - drift(r[2]))
        means = [st.mean(vs) for vs in per.values()]
        sd_in = st.mean([st.pstdev(vs) for vs in per.values()])
        rng = max(means) - min(means)
        cls = "S" if rng <= 0.010 else ("M" if rng <= 0.020 else "U")
        grid[(x, y)] = (rng, cls)
        rows.append([x, y, x - ox, y - oy, round(st.mean(means), 4), round(sd_in, 4), round(rng, 4), cls,
                     " ".join(f"{m:+.4f}" for m in means)])
fs = os.path.join(v.DATA, f"bedstab_{TS}.csv")
with open(fs, "w", newline="") as fh:
    csv.writer(fh).writerows([["probeX", "probeY", "nozzleX", "nozzleY", "mean", "sd_w_punkcie", "rozstep_przebiegi",
                               "klasa", "srednie_przebiegow"]] + rows)
v.log("rozstep miedzy przebiegami [mm] / klasa (wiersze od tylu, Y364 u gory; kolumny X5..X395, wsp. sondy):")
for y in YS[::-1]:
    v.log(f"  Y{y:3d} " + " ".join(f"{grid[(x, y)][0]:.3f}{grid[(x, y)][1]}" for x in XS))
cnt = {c: sum(1 for r in rows if r[7] == c) for c in "SMU"}
worst = max(rows, key=lambda r: r[6])
v.log(f"PODSUMOWANIE: S {cnt['S']} / M {cnt['M']} / U {cnt['U']} z {len(rows)}; najgorszy X{worst[0]} Y{worst[1]} "
      f"{worst[6]:.4f}; dryf odniesienia {refs[-1][1] - refs[0][1]:+.4f}; sd w punkcie sr. "
      f"{st.mean(r[5] for r in rows):.4f} | CSV {fs}")
