"""Sledzenie inicjalizacji wydruku Vorona na zywo (TYLKO ODCZYT) - zwiezle podsumowanie kazdego etapu danymi:
G32 (BedLevel) -> HesCal2 -> Mesh -> start warstwy 1. Kazda linia = jedno zdarzenie (do Monitor/czatu).
Porownania z wartosciami odniesienia (--ref-*), znacznik: OK = w tolerancji, UWAGA = poza (do wyjasnienia).
Uzycie: python tools/watch_init.py [--tol 0.02] [--ref-g31 0.919] [--ref-zapas 0.149] [--ref-dz 0.975] [--ref-tip 1.12]
Konczy, gdy druk ruszy (warstwa >= 1) albo drukarka wroci do idle. Pelny log: data/logs/watch_init_*.log"""
import argparse, time
import voron_api as v

ap = argparse.ArgumentParser()
ap.add_argument("--tol", type=float, default=0.02)
ap.add_argument("--ref-g31", type=float, default=0.919)
ap.add_argument("--ref-zapas", type=float, default=0.149)
ap.add_argument("--ref-dz", type=float, default=0.975)
ap.add_argument("--ref-tip", type=float, default=1.12)
ap.add_argument("--dt", type=float, default=3)
ap.add_argument("--w-trakcie", action="store_true", help="start.g juz trwa - nie czekac na idle")
a = ap.parse_args()
v.set_log("watch_init")
HM = "0:/sys/heightmap_ext.csv"


def say(s):
    v.log(s)


def flag(d, tol):
    return "OK" if abs(d) <= tol else "UWAGA"


def mesh():
    L = v.download(HM).strip().splitlines()
    if len(L) < 11:   # plik w trakcie zapisu (Mesh pisze wiersz po wierszu)
        raise ValueError("mapa niekompletna")
    return L[0], [[float(x) for x in l.split(",")] for l in L[3:10]]


def fmt_mesh(rows):
    out = ["[um]    X5   70  135  200  265  330  395"]
    for i, r in enumerate(rows):
        out.append(f"Y{10 + 59 * i}".ljust(5) + "".join(f"{round(x * 1000):5d}" for x in r))
    return "\n".join(out)


if v.status() != "idle" and not a.w_trakcie:
    say(f"status {v.status()} - czekam na koniec/anulowanie biezacego wydruku")
    while v.status() != "idle":
        time.sleep(a.dt)
    g = v.m("global") or {}
    say(f"idle; nastepny start.g: G32 {'POMINIETE' if g.get('levelDone') else 'tak'}, "
        f"HesCal {'POMINIETY' if g.get('skipCal') else 'tak'} (levelDone={g.get('levelDone')}, skipCal={g.get('skipCal')})")
t0 = time.time()
hist_n = len(v.hist_rows())
try:
    old_head, old_mesh = mesh()
except Exception:
    old_head, old_mesh = "", None
say(f"start; poprzednia siatka: {old_head[-60:]}")
last_cal = None; last = {}; seen = False; level_t = None; mesh_head = old_head
while True:
    try:
        s = v.m("state"); j = v.m("job"); cal = v.m("move.calibration"); g = v.m("global") or {}
        st = s["status"]
        if st in ("processing", "busy", "paused", "pausing"):
            seen = True
        cur = {"status": st, "msg": s.get("displayMessage"), "box": (s.get("messageBox") or {}).get("message")}
        for k, val in cur.items():
            if last.get(k) != val and val not in (None, "") and k != "status":
                say(f"{k}: {val}")
        last = cur
        # --- G32: kazda iteracja = zmiana move.calibration ---
        key = (cal["initial"]["deviation"], cal["initial"]["mean"], cal["final"]["deviation"])
        if last_cal is not None and key != last_cal:
            dev = cal["initial"]["deviation"]
            say(f"G32 iteracja: odchylka przed {dev:.3f} (srednia {cal['initial']['mean']:+.3f}) -> po {cal['final']['deviation']:.3f} "
                f"{'OK' if dev <= 0.02 else 'dociaganie'}")
            level_t = level_t or time.time()
        last_cal = key
        # --- HesCal2: nowy wiersz hes_hist ---
        rows = v.hist_rows()
        for line in rows[hist_n:]:
            d = v.parse_hist(line)
            g31 = d["G31Z"]; zap = d["zapas"]; dz = d["dzK0HE"]; tip = d["k1Stol"]
            say(f"HesCal2 {d['wynik']}: G31 {g31:.3f} (ref {a.ref_g31:.3f}, {g31 - a.ref_g31:+.3f} {flag(g31 - a.ref_g31, a.tol)}) | "
                f"zapas {zap:.3f} ({zap - a.ref_zapas:+.3f} {flag(zap - a.ref_zapas, a.tol)}) | dz {dz:.3f} ({dz - a.ref_dz:+.3f} {flag(dz - a.ref_dz, a.tol)}) | "
                f"tipBed {tip:.3f} ({tip - a.ref_tip:+.3f} {flag(tip - a.ref_tip, a.tol)})")
        hist_n = len(rows)
        # --- Mesh: nowy plik mapy ---
        if g.get("lastInitStep") in (5, 6, 0) or st == "processing":
            try:
                head, new = mesh()
            except Exception:
                head = mesh_head
            if head != mesh_head:
                mesh_head = head
                flat = [x for r in new for x in r]
                say(f"Mesh: zakres {min(flat):+.3f}..{max(flat):+.3f} (rozstep {max(flat) - min(flat):.3f})\n" + fmt_mesh(new))
                if old_mesh:
                    dd = [new[r][c] - old_mesh[r][c] for r in range(7) for c in range(7)]
                    mr = [abs(x) for x in dd]; im = mr.index(max(mr))
                    mean = sum(dd) / len(dd); dev = [abs(x - mean) for x in dd]; idv = dev.index(max(dev))
                    say(f"Mesh vs poprzednia: srednio {mean:+.3f} (przesuniecie calosci), max |roznica| {max(mr):.3f} w X{5 + 65 * (im % 7)} Y{10 + 59 * (im // 7)}; "
                        f"po odjeciu sredniej max {max(dev):.3f} w X{5 + 65 * (idv % 7)} Y{10 + 59 * (idv // 7)} {flag(max(dev), a.tol)}")
        if (j.get("layer") or 0) >= 1 and (j.get("filePosition") or 0) > 6000:
            p = v.m("sensors.probes")[0]
            say(f"druk ruszyl: warstwa {j.get('layer')}, G31 {p['triggerHeight']}, czas inicjalizacji {(time.time() - t0) / 60:.1f} min - koniec")
            break
        if seen and st == "idle":
            say("drukarka idle - start przerwany albo zakonczony"); break
    except Exception as e:
        say(f"blad odczytu: {e!r}"[:160])
    time.sleep(a.dt)
