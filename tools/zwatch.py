"""Czuwanie Z (Voron): wykrywa opadanie ramy stolu / chwilowy zanik sterownikow Z (A4988) przy stojacej maszynie.
Start: G32 (bed.g z 15 mm, ustawia tez Z0). Potem co --every s pomiar K0 w 4 punktach G32 BEZ korekty silnikow
(G30 P0..P3, ostatni S-1 = tylko raport) i porownanie z pomiarem bazowym. Zmiana > --alarm mm w dowolnym punkcie = ALARM.
Miedzy pomiarami glowica stoi (Z5). RUCH - tylko po zgodzie, uzytkownik w poblizu. Przerwanie: Ctrl+C / TaskStop.
Uzycie: python zwatch.py [--every 120] [--minutes 60] [--alarm 0.05] [--bez-g32]
Wynik: data/zwatch_*.csv, log data/logs/zwatch_*.log, linia PODSUMOWANIE."""
import argparse, csv, os, re, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import voron_api as v

ap = argparse.ArgumentParser()
ap.add_argument("--every", type=int, default=120)
ap.add_argument("--minutes", type=float, default=60)
ap.add_argument("--alarm", type=float, default=0.05)
ap.add_argument("--bez-g32", action="store_true")
a = ap.parse_args()

NAMES = ["LP", "LT", "PT", "PP"]
PTS = ['N0 X10 Y5', 'N1 X10 Y360', 'N2 X380 Y360', 'N3 X380 Y5 S-1']
v.set_log("zwatch")
out = os.path.join(v.DATA, f"zwatch_{time.strftime('%Y%m%d_%H%M')}.csv")
v.log(f"START every={a.every}s minutes={a.minutes} alarm={a.alarm} | " + v.state())
if v.status() != "idle" or not v.homed():
    v.log("PODSUMOWANIE: nie idle albo niezbazowane - stop"); sys.exit(1)


def measure():
    v.run('M558 K0 H5:3 F120:80 A5 S0.01 T21000', 10)
    txt = ""
    for p in PTS:
        ok, t = v.run(f'M98 P"0:/sys/k0g30.g" {p}', 300)
        txt += t
        if not ok:
            v.log(f"  blad pomiaru {p}: {t[:200]!r}")
            break
    v.run('M558 K0 H5:3 F120:80 T18000 A5 S0.01 R0.3', 10)
    v.run('G1 Z5 F600', 30)
    m = re.search(r"heights?:?\s*([-\d.]+)[ ,]+([-\d.]+)[ ,]+([-\d.]+)[ ,]+([-\d.]+)", txt, re.I)
    return [float(x) for x in m.groups()] if m else None


if not a.bez_g32:
    ok, t = v.run("G32", 900)
    v.log(f"G32 ok={ok}: {t[:300]!r}")
    if not ok:
        v.log("PODSUMOWANIE: G32 nieudane - stop"); sys.exit(1)
v.run("G29 S2", 10)
base = measure()
if not base:
    v.log("PODSUMOWANIE: brak pomiaru bazowego - stop"); sys.exit(1)
v.log("BAZA: " + "  ".join(f"{n} {z:+.3f}" for n, z in zip(NAMES, base)))
alarms = 0; worst = 0.0; n = 0
with open(out, "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f); w.writerow(["czas"] + NAMES + [f"d{x}" for x in NAMES] + ["dmax"])
    w.writerow([time.strftime("%F %T")] + base + [0, 0, 0, 0, 0])
    t_end = time.time() + a.minutes * 60
    try:
        while time.time() < t_end:
            time.sleep(a.every)
            if v.status() != "idle":
                v.log("  status != idle - pomijam pomiar"); continue
            z = measure(); n += 1
            if not z:
                v.log("  brak wyniku pomiaru"); continue
            d = [zz - bb for zz, bb in zip(z, base)]; dm = max(d, key=abs)
            worst = max(worst, abs(dm))
            w.writerow([time.strftime("%F %T")] + z + [round(x, 4) for x in d] + [round(dm, 4)]); f.flush()
            tag = "ALARM" if abs(dm) > a.alarm else "ok"
            if tag == "ALARM":
                alarms += 1
            v.log(f"  {tag}: zmiana od bazy " + "  ".join(f"{nn} {x:+.3f}" for nn, x in zip(NAMES, d)))
    except KeyboardInterrupt:
        v.log("  przerwane")
v.log(f"PODSUMOWANIE: pomiarow {n}, alarmow (> {a.alarm}) {alarms}, najwieksza zmiana {worst:.3f} mm; CSV {out}")
