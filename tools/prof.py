"""Gesty profil K0 wzdluz Y z tylu stolu vs interpolacja swiezej siatki Mesh 7x7 (Voron, 19.10, wada 1. warstwy Y300+).
1) M98 Mesh (siatka 7x7 w wsp. sondy: X 5..395 co 65, Y 10..364 co 59 -> 0:/sys/heightmap_ext.csv),
2) mapa wylaczona, profil w kolumnach siatki (X70, X135, X200) od Y246 do Y364 co 59/6 mm (wiersze siatki Y246/305/364
   tez mierzone - kontrola zgodnosci z Mesh); dojazd zawsze od strony -X (ruch +X), 2 zjazdy G38.3 K0 F80, srednia,
3) roznica profil - interpolacja liniowa siatki miedzy wierszami (w kolumnie siatki bez interpolacji w X).
Na zimno. Wymaga: idle, osie zbazowane, G32 zrobione. Uzycie: python prof.py [--bez-mesh] [--opis "..."]
Wynik: data/prof_*.csv, log data/logs/prof_*.log, linia PODSUMOWANIE."""
import argparse, csv, os, statistics as st, sys, time, urllib.parse
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import voron_api as v

ap = argparse.ArgumentParser()
ap.add_argument("--bez-mesh", action="store_true")
ap.add_argument("--opis", default="")
a = ap.parse_args()

COLS = [70, 135, 200]
YS = [round(246 + i * 59 / 6, 2) for i in range(13)]   # 246 ... 305 ... 364
X0, DX, Y0, DY = 5, 65, 10, 59
TS = time.strftime("%Y%m%d_%H%M")
v.set_log("prof")
v.log(f"START {a.opis!r} | " + v.state())
if v.status() != "idle" or not v.homed():
    v.log("PODSUMOWANIE: nie idle albo niezbazowane - stop"); raise SystemExit(1)


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


if not a.bez_mesh:
    ok, txt = v.run('M98 P"0:/macros/Mesh"', 900)
    v.log(f"Mesh ok={ok}: {txt[:300]!r}")
    if not ok:
        v.log("PODSUMOWANIE: Mesh nieudany - stop"); raise SystemExit(1)
hm = v.download("0:/sys/heightmap_ext.csv")
open(os.path.join(v.DATA, f"heightmap_ext_{TS}.csv"), "w", encoding="utf-8").write(hm)
rows = [[float(x) for x in l.split(",")] for l in hm.strip().splitlines()[3:]]   # rows[r][c], r = Y index


def mapval(px, py):
    c = round((px - X0) / DX); fr = (py - Y0) / DY; r = int(fr); t = fr - r
    if r >= len(rows) - 1:
        return rows[-1][c]
    return rows[r][c] * (1 - t) + rows[r + 1][c] * t


p = v.m("sensors.probes")[0]; trig = p["triggerHeight"]; ox, oy = p["offsets"][0], p["offsets"][1]
ax0 = v.m("move.axes"); acc = (ax0[0]["acceleration"], ax0[1]["acceleration"]); jerk = (ax0[0]["jerk"], ax0[1]["jerk"])
hop = max(1.5, trig + 0.8)
raw = []
try:
    send("M201 X2000 Y2000"); send("M566 X300 Y300"); send("G29 S2")
    send(f"G1 Z{hop:.3f} F6000")
    for px in COLS:
        for py in YS:
            nx, ny = px - ox, py - oy
            send(f"G1 Z{hop:.3f} F6000")
            send(f"G1 X{nx - 20:.3f} Y{ny:.3f} F12000")
            send(f"G1 X{nx:.3f} Y{ny:.3f} F12000")
            hs = []
            for i in range(2):
                if v.m("sensors.probes")[0]["value"][0] > 0:
                    v.log("K0 zadzialana przed zjazdem - stop"); raise SystemExit(1)
                z = send(f"G38.3 K0 Z{trig - 2:.3f} F80")
                if v.m("sensors.probes")[0]["value"][0] == 0:
                    v.log(f"brak zadzialania X{px} Y{py} - stop"); raise SystemExit(1)
                send(f"G1 Z{z + 0.5:.3f} F600")
                hs.append(z - trig)
            h = st.mean(hs); mv = mapval(px, py)
            raw.append([px, py, round(hs[0], 4), round(hs[1], 4), round(h, 4), round(mv, 4), round(h - mv, 4)])
        v.log(f"kolumna X{px} gotowa")
    send(f"G1 Z{hop:.3f} F6000")
finally:
    send("M201 X%s Y%s" % acc); send("M566 X%s Y%s" % jerk)
    send('G29 S1 P"0:/sys/heightmap_ext.csv"')
    v.log("END " + v.state())
    fr = os.path.join(v.DATA, f"prof_{TS}.csv")
    with open(fr, "w", newline="") as fh:
        csv.writer(fh).writerows([["probeX", "probeY", "h1", "h2", "h", "mapa", "h-mapa"]] + raw)

summ = []
for px in COLS:
    r = [x for x in raw if x[0] == px]
    grid = [x[6] for x in r if abs((x[1] - Y0) / DY - round((x[1] - Y0) / DY)) < 1e-6]   # wiersze siatki
    off = st.mean(grid)   # przesuniecie profil vs Mesh w punktach siatki (dryf miedzy pomiarami)
    v.log(f"X{px}: punkty siatki h-mapa {' '.join(f'{g:+.3f}' for g in grid)} (przesuniecie {off:+.3f})")
    v.log("   Y    " + " ".join(f"{x[1]:7.1f}" for x in r))
    v.log("   h-m  " + " ".join(f"{x[6] - off:+7.3f}" for x in r))
    worst = min(r, key=lambda x: x[6] - off)
    summ.append(f"X{px} min {worst[6] - off:+.3f} @Y{worst[1]:.0f}")
v.log("PODSUMOWANIE (profil - interpolacja siatki, po odjeciu przesuniecia w punktach siatki; ujemne = stol nizej niz mapa = "
      "dysza za daleko): " + " | ".join(summ) + f" | CSV {fr}")
