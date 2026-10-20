"""Test histerezy kierunku dojazdu (Voron, sonda K0). W kazdym punkcie (wsp. sondy) warianty dojazdu na wysokosci hop,
potem 2 zjazdy G38.3 K0 F80 (z 0.5 mm), srednia. Warianty przeplatane (round-robin) x N powtorzen -> dryf rozlozony rowno.
Mapa wylaczona. Wymaga: idle, osie zbazowane. Uzycie: python xdir.py [--n 4] [--opis "..."]"""
import argparse, csv, os, statistics as st, sys, time, urllib.parse
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import voron_api as v

ap = argparse.ArgumentParser()
ap.add_argument("--n", type=int, default=4)
ap.add_argument("--opis", default="")
a = ap.parse_args()

PTS = [(70, 246), (330, 187)]
# nazwa: (start dx, start dy, krok koncowy dx, dy po dojezdzie, postoj s)
VAR = {
    "+X20": (-20, 0, 0, 0, 0), "-X20": (20, 0, 0, 0, 0),
    "+X1": (-1, 0, 0, 0, 0), "-X1": (1, 0, 0, 0, 0),
    "-X20+G4S3": (20, 0, 0, 0, 3), "-X20+back0.5": (20, 0, 0.5, 0, 0),
    "+Y20": (0, -20, 0, 0, 0), "-Y20": (0, 20, 0, 0, 0),
}
TS = time.strftime("%Y%m%d_%H%M")
v.set_log("xdir")
v.log(f"START {a.opis!r} n={a.n} | " + v.state())
if v.status() != "idle":
    v.log("STOP: status != idle"); raise SystemExit(1)
if not v.homed():
    v.log("STOP: osie niezbazowane"); raise SystemExit(1)


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


p = v.m("sensors.probes")[0]; trig = p["triggerHeight"]; ox, oy = p["offsets"][0], p["offsets"][1]
ax0 = v.m("move.axes"); acc = (ax0[0]["acceleration"], ax0[1]["acceleration"]); jerk = (ax0[0]["jerk"], ax0[1]["jerk"])
comp0 = v.m("move.compensation")["type"]
hop = max(1.5, trig + 0.8)
raw = []; t_start = time.time()
try:
    send("M201 X2000 Y2000"); send("M566 X300 Y300"); send("G29 S2")
    send(f"G1 Z{hop:.3f} F6000")
    for n in range(1, a.n + 1):
        for (px, py) in PTS:
            nx, ny = px - ox, py - oy
            names = list(VAR) if n % 2 else list(VAR)[::-1]
            for name in names:
                sx, sy, bx, by, dw = VAR[name]
                send(f"G1 Z{hop:.3f} F6000")
                send(f"G1 X{nx + sx * 3:.3f} Y{ny + sy * 3:.3f} F24000")    # daleko, zeby ostatni ruch byl na pewno w kierunku wariantu
                send(f"G1 X{nx + sx:.3f} Y{ny + sy:.3f} F12000")
                send(f"G1 X{nx:.3f} Y{ny:.3f} F12000")
                if bx or by:
                    send(f"G1 X{nx - bx:.3f} Y{ny - by:.3f} F12000"); send(f"G1 X{nx:.3f} Y{ny:.3f} F12000")
                if dw:
                    send(f"G4 S{dw}")
                hs = []
                for i in range(2):
                    if v.m("sensors.probes")[0]["value"][0] > 0:
                        v.log("K0 zadzialana przed zjazdem - stop"); raise SystemExit(1)
                    z = send(f"G38.3 K0 Z{trig - 2:.3f} F80")
                    if v.m("sensors.probes")[0]["value"][0] == 0:
                        v.log(f"brak zadzialania X{px} Y{py} - stop"); raise SystemExit(1)
                    send(f"G1 Z{z + 0.5:.3f} F600")
                    hs.append(z - trig)
                raw.append([n, round(time.time() - t_start, 1), px, py, name, round(hs[0], 4), round(hs[1], 4), round(st.mean(hs), 4)])
        v.log(f"powtorzenie {n}/{a.n} gotowe, {time.time() - t_start:.0f} s")
    send(f"G1 Z{hop:.3f} F6000")
finally:
    send("M201 X%s Y%s" % acc); send("M566 X%s Y%s" % jerk)
    if comp0 != "none":
        send('G29 S1 P"0:/sys/heightmap_ext.csv"')
    v.log("END " + v.state())
    fr = os.path.join(v.DATA, f"xdir_{TS}.csv")
    with open(fr, "w", newline="") as fh:
        csv.writer(fh).writerows([["powt", "t_s", "probeX", "probeY", "wariant", "h1", "h2", "h"]] + raw)

summ = []
for (px, py) in PTS:
    base = st.mean(r[7] for r in raw if (r[2], r[3]) == (px, py) and r[4] == "+X20")
    v.log(f"X{px} Y{py} (wzgledem +X20 = {base:+.4f}):")
    for name in VAR:
        hs = [r[7] for r in raw if (r[2], r[3]) == (px, py) and r[4] == name]
        d = st.mean(hs) - base
        v.log(f"  {name:13s} {d:+.4f}  sd {st.pstdev(hs):.4f}")
        summ.append(f"{px}/{py} {name} {d:+.4f}")
k = lambda pt, nm: [s for s in summ if s.startswith(f"{pt[0]}/{pt[1]} {nm} ")][0].split()[-1]
v.log("PODSUMOWANIE: X70Y246 -X20 " + k(PTS[0], "-X20") + " -X1 " + k(PTS[0], "-X1") + " G4 " + k(PTS[0], "-X20+G4S3")
      + " back " + k(PTS[0], "-X20+back0.5") + " +Y " + k(PTS[0], "+Y20") + " -Y " + k(PTS[0], "-Y20")
      + " | X330Y187 -X20 " + k(PTS[1], "-X20") + f" | CSV {fr}")
