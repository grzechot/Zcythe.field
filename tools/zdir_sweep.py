"""zdir_sweep.py - granice napedu Z OSOBNO dla ruchu w gore i w dol (pliki_67, 261115, Gregor).
RUCH MASZYNY - tylko po zgodzie Gregora i gdy patrzy. Wymaga: idle, G28, K0 otwarta, na karcie 0:/sys/zdir_step.g,
ztest_chk.g, ztest_lvl.g. Stol z balastem 1 kg. XY na czas testu jak bed mesh: M201 X2000 Y2000, M566 X300 Y300 (otwarta K0 jest lekka).

Cel: najszybszy bezpieczny zestaw JerkUp/JerkDown, AccelUp/AccelDown, SpeedUp/SpeedDown dla tej mechaniki
(to, ze RRF ma jeden zestaw dla Z, jest tu bez znaczenia). zdir_step.g planuje ruch w gore z zestawem "gora", w dol
z zestawem "dol"; nawrot dol->gora ogranicza jerk gory, gora->dol jerk dolu.

Wersja 2 (261115 17:2x, Gregor wariant 1): przebieg 14:47 pokazal, ze PT/PP opadaja powoli proporcjonalnie do drogi Z
(ok. -0.008 / -0.014 mm na 1 m), niezaleznie od ustawien - prog 0.02 lapal ten dryf. Teraz: zmiana rogu jest korygowana
o --drift x droga serii, prog --thr 0.03 (utkniecie = 0.04, szum K0 ok. 0.007), serie krotsze (--n 20), a gdy
skumulowany przekos od ostatniego poziomowania > --relev, poziomowanie bez liczenia bledu.
Pomiar zgubionych krokow: ztest_chk.g (K0 w 4 punktach srub, jeden zjazd, bez korekty) przed i po stopniu.
Stopien zaliczony, gdy zaden rog nie zmienil sie o wiecej niz --thr (0.02 mm; utkniecie gubi paczke 4 pelnych
krokow = 0.04 mm, powtarzalnosc K0 ok. 0.007). Kazdy stopien: najpierw --pre cykli + kontrola (maly przekos przy
utknieciu), potem --n cykli + kontrola. Po bledzie: ztest_lvl.g (poziomowanie G30 S4) i nowa baza, dalej nastepna
drabinka. Brak odczytu K0 / nieudane poziomowanie = STOP (operator: G28 + G32).

Drabinki (Gregor 261115): rosnaco do 1. bledu, potem 2 kroki polowienia miedzy ostatnim dobrym a zlym, potwierdzenie
ostatniego dobrego --conf x dluzsza seria. Limit roboczy = 50 % limitu (jerk, przyspieszenie), 70 % (predkosc).
Kolejnosc: jerk gora, jerk dol, przysp. gora, przysp. dol, predkosc gora, predkosc dol, final (caly zestaw).
  jerk  : badany kierunek V = max(Vb, J/120 + 1) mm/s (nawrot = +-J/2), A = Ab; skok V^2/A + 1 mm
  acc   : badany kierunek V = Vb, J = roboczy; skok max(1, V^2/A + 1) mm
  speed : badany kierunek A, J robocze; skok min(--smax, V^2/A + 3) mm; po stopniu M122 (hiccups = limit Duet, nie mechaniki)
  final : wszystkie robocze: 300 skokow 0.4 mm + 30 ruchow 20 mm
Drugi kierunek zawsze na wartosciach roboczych (jesli juz znalezione) albo bazowych Vb/Ab/Jb.
Stop w trakcie: utworzyc plik rrf\\data\\zdir_STOP (konczy po biezacym stopniu, przywraca config).
Wynik: data/zdir_YYMMdd_HHMM.csv, log data/logs/zdir_*.log, linia PODSUMOWANIE (limity i robocze, 6 wartosci).
Uzycie: python zdir_sweep.py [--etap all|jerk|acc|speed|final] [--dir up,down] [--b 30] [--acc]
        [--Ju .. --Jd .. --Au .. --Ad .. --Vu .. --Vd ..  (robocze z poprzednich etapow)]"""
import argparse, csv, os, re, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import voron_api as v

LAD = {"J": [20, 40, 60, 90, 120, 180, 240, 360, 480, 720, 960, 1440],      # mm/min
       "A": [100, 200, 400, 700, 1000, 1500, 2000, 3000, 4000],              # mm/s^2
       "V": [5, 10, 15, 20, 25, 30, 35, 40]}                                 # mm/s
SAFE = {"J": 0.5, "A": 0.5, "V": 0.7}
NAME = {"J": "jerk", "A": "acc", "V": "speed"}

ap = argparse.ArgumentParser()
ap.add_argument("--etap", default="all", choices=["all", "jerk", "acc", "speed", "final"])
ap.add_argument("--dir", default="up,down")
ap.add_argument("--b", type=float, default=30, help="dolna wysokosc ruchow [mm]")
ap.add_argument("--n", type=int, default=20, help="cykli na stopien")
ap.add_argument("--pre", type=int, default=3, help="cykli proby przed pelna seria (0 = bez)")
ap.add_argument("--conf", type=int, default=3, help="potwierdzenie = conf x n cykli")
ap.add_argument("--thr", type=float, default=0.03, help="prog zmiany rogu po korekcie dryfu [mm]")
ap.add_argument("--drift", default="-0.0026,-0.0021,-0.0084,-0.0139", help="dryf LP,LT,PT,PP [mm na 1 m drogi Z] (przebieg 261115 14:47)")
ap.add_argument("--relev", type=float, default=0.03, help="poziomowanie, gdy przekos od ostatniego poziomowania > [mm]")
ap.add_argument("--smax", type=float, default=30)
ap.add_argument("--vb", type=float, default=10); ap.add_argument("--ab", type=float, default=400)
ap.add_argument("--jb", type=float, default=20)
# 261116 (Gregor: duze przyspieszenie przy malym jerku): tryb acc z jednym jerkiem dla obu kierunkow,
# wlasna drabinka, predkosc i stale skoki (z-hop), np. --etap acc --ja 60 --va 13.2 --alad 200,400,700,1000,1500,2000 --askok 0.4:100,2:20
ap.add_argument("--ja", type=float, help="etap acc: jerk obu kierunkow [mm/min] (zamiast roboczych)")
ap.add_argument("--va", type=float, help="etap acc: predkosc badanego kierunku [mm/s] (domyslnie --vb)")
ap.add_argument("--alad", help="etap acc: drabinka przyspieszen, np. 200,400,700,1000")
ap.add_argument("--askok", help="etap acc: stale skoki skok:cykle, np. 0.4:100,2:20 (stopien ok, gdy wszystkie ok)")
for k in ("Ju", "Jd", "Au", "Ad", "Vu", "Vd"):
    ap.add_argument("--" + k, type=float)
ap.add_argument("--g28", action="store_true", help="na starcie G28 + safe_off (np. po przekosie z poprzedniego przebiegu)")
ap.add_argument("--acc", action="store_true", help="LIS3DH nagrywa pierwsze ~2 s kazdej pelnej serii (0:/sys/accelerometer/zd/)")
ap.add_argument("--opis", default="")
a = ap.parse_args()
DRIFT = [float(x) for x in a.drift.split(",")]
if a.alad:
    LAD["A"] = [float(x) for x in a.alad.split(",")]
ASKOK = [(float(p.split(":")[0]), int(p.split(":")[1])) for p in a.askok.split(",")] if a.askok else None
DIRS = [d.strip() for d in a.dir.split(",") if d.strip()]

_get0 = v.get


def _get(p, timeout=10):
    if p.startswith("/rr_gcode"):
        return _get0(p, timeout)
    for i in range(5):
        try:
            return _get0(p, timeout)
        except OSError as e:
            if i == 4:
                raise
            print(f"  siec: {e!r} - ponawiam", flush=True); time.sleep(2 + 2 * i)


v.get = _get
v.set_log("zdir")
STAMP = time.strftime('%y%m%d_%H%M')
CSV = os.path.join(v.DATA, f"zdir_{STAMP}.csv")
STOPF = os.path.join(v.DATA, "zdir_STOP")
COLS = ["czas", "etap", "kier", "wartosc", "proba", "Vu", "Au", "Ju", "Vd", "Ad", "Jd", "skok", "cykle",
        "dLP", "dLT", "dPT", "dPP", "max", "wynik", "hiccups", "s", "droga_m", "max_surowy"]
rows = []
W = {("J", "up"): a.Ju, ("J", "down"): a.Jd, ("A", "up"): a.Au, ("A", "down"): a.Ad, ("V", "up"): a.Vu, ("V", "down"): a.Vd}
LIM = {}
base = None
lvl0 = None
nstep = 0
nrec = 0


class Stop(Exception):
    pass


class NoRead(Exception):
    """Stol nie doszedl do K0 - utkniecie z duzym przekosem. Gregor 261115: wypoziomowac i kontynuowac."""
    pass


def recover(label):
    """Po utknieciu z przekosem: G28 (homez K0 w srodku), dynamika XY jak mesh, poziomowanie, nowa baza."""
    global nrec
    nrec += 1
    if nrec > 6:
        raise Stop("ponad 6 odzyskan po utknieciu")
    v.log(f"ODZYSK {nrec} ({label}): G28 + poziomowanie")
    ok, txt = v.run("G28", 600)
    if not ok or not v.homed():
        raise Stop(f"G28 po utknieciu nieudane: {txt[-300:]!r}")
    v.run('M98 P"0:/sys/safe_off.g"', 60)
    v.run("M201 X2000 Y2000\nM566 X300 Y300", 20)
    global lvl0
    level(f"odzysk {nrec}")
    lvl0 = chk(f"baza po odzysku {nrec}")
    return lvl0


TBL = {"up": "bedDn", "down": "bedUp", "both": "both"}   # kierunek stolu (skrypt: up = Z+ = stol w dol)


def pd(text):
    """261116 (Gregor): postep testu na PanelDue (msg.g S -> PanelDue + DWC), zeby DWC moglo byc zamkniete.
    Po angielsku, <= 40 znakow, bez cudzyslowow. Nigdy w trakcie nagrania LIS3DH (wolane po pomiarze K0)."""
    t = text.replace('"', "'")[:40]
    try:
        v.run(f'M98 P"0:/sys/msg.g" S"{t}"', 20)
    except OSError as e:
        v.log(f"  PanelDue: {e!r}")


def save():
    with open(CSV, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f); w.writerow(COLS); w.writerows(rows)


def restore():
    v.run(f"M203 Z{Z0['speed']}\nM201 Z{Z0['acceleration']}\nM566 Z{Z0['jerk']}", 20)
    v.run(f"M201 X{XY0[0]} Y{XY0[1]}\nM566 X{XY0[2]} Y{XY0[3]}", 20)


def chk(label):
    ok, txt = v.run('M98 P"0:/sys/ztest_chk.g"', 600)
    c = v.m("global.ztChk")
    if c == 2:
        raise NoRead(f"ztest_chk ({label}): brak odczytu K0 {txt[:200]!r}")
    if not ok or c != 0:
        raise Stop(f"ztest_chk ({label}): {'K0 zamknieta' if c == 1 else 'brak odczytu K0 (stol nie doszedl - utkniecie?)'} {txt[:200]!r}")
    return [float(x) for x in v.m("global.ztH")]


def level(label):
    ok, txt = v.run('M98 P"0:/sys/ztest_lvl.g"', 1200)
    dev = v.m("global.ztLvl")
    if not ok or dev is None or dev < 0:
        raise Stop(f"poziomowanie ({label}) nieudane: {txt[:200]!r}")
    v.log(f"poziomowanie ({label}): odchylka {dev:.4f}")


def wset(p, d):
    """Wartosc robocza parametru p kierunku d (albo bazowa)."""
    x = W[(p, d)]
    return x if x is not None else {"J": a.jb, "A": a.ab, "V": a.vb}[p]


def cycles(etap, d, val, tag, up, dn, s, n, rec):
    """Jedna seria zdir_step.g + kontrola; zwraca (dobry, max)."""
    global base, nstep, lvl0
    if os.path.exists(STOPF):
        raise Stop("plik zdir_STOP")
    nstep += 1
    t0 = time.time()
    f = f' R1 F"zd/{STAMP}_{nstep:03d}_{etap}_{d}_{val:g}.csv"' if (rec and a.acc) else ""
    cmd = (f'M98 P"0:/sys/zdir_step.g" U{up[0]:g} A{up[1]:g} J{up[2]:g} D{dn[0]:g} C{dn[1]:g} K{dn[2]:g}'
           f' S{s:g} N{n} B{a.b:g}{f}')
    ok, txt = v.run(cmd, 3600, wait0=5.0 if f else 1.0)   # przy nagraniu (~2 s) bez zapytan HTTP
    if not ok or "zdir_step done" not in txt:
        # 261116 10:22: pusta odpowiedz po 21 s (ruch skonczony, Z na B) - odpowiedz zgubiona; o wyniku decyduje pomiar K0
        if txt == "" and v.status() == "idle" and abs(v.m("move.axes")[2]["userPosition"] - a.b) < 0.01:
            v.log(f"  UWAGA: pusta odpowiedz zdir_step.g, status idle, Z = B - pomiar decyduje")
        else:
            raise Stop(f"zdir_step.g: {txt[:300]!r}")
    hic = ""
    if etap == "V":
        ok2, t2 = v.run("M122", 30)
        m = re.search(r"[Hh]iccups:?\s*(\d+)", t2)
        hic = m.group(1) if m else "?"
    try:
        h = chk(f"{etap} {d} {val:g} {tag}")
        dr = n * 2 * s / 1000
        raw = [h[i] - base[i] for i in range(4)]
        dd = [raw[i] - DRIFT[i] * dr for i in range(4)]
        mx = max(abs(x) for x in dd)
        mraw = max(abs(x) for x in raw)
    except NoRead as e:
        v.log(str(e))
        rows.append([time.strftime("%y%m%d %H:%M:%S"), NAME[etap], d, f"{val:g}", tag, *[f"{x:g}" for x in up], *[f"{x:g}" for x in dn],
                     f"{s:g}", n, "", "", "", "", "", "UTKNIECIE (brak K0)", hic, f"{time.time() - t0:.0f}", f"{n * 2 * s / 1000:.3f}", ""])
        save()
        v.log(f"  {NAME[etap]} {d} {val:g} {tag}: UTKNIECIE z przekosem - odzysk")
        pd(f"Z {TBL[d]} {etap}{val:g} STALL - rehome")
        base = recover(f"{NAME[etap]} {d} {val:g}")
        return False
    good = mx <= a.thr
    rows.append([time.strftime("%y%m%d %H:%M:%S"), NAME[etap], d, f"{val:g}", tag, *[f"{x:g}" for x in up], *[f"{x:g}" for x in dn],
                 f"{s:g}", n, *[f"{x:+.4f}" for x in dd], f"{mx:.4f}", "ok" if good else "BLAD", hic, f"{time.time() - t0:.0f}", f"{dr:.3f}", f"{mraw:.4f}"])
    save()
    v.log(f"  {NAME[etap]} {d} {val:g} {tag}: up V{up[0]:g} A{up[1]:g} J{up[2]:g} | down V{dn[0]:g} A{dn[1]:g} J{dn[2]:g} | "
          f"skok {s:g} x{n} -> {'ok' if good else 'BLAD'} (LP {dd[0]:+.3f} LT {dd[1]:+.3f} PT {dd[2]:+.3f} PP {dd[3]:+.3f})"
          + f" [korekta dryfu {dr:.2f} m, surowo max {mraw:.3f}]" + (f" hiccups {hic}" if hic else ""))
    if not good or not tag.startswith("proba"):   # PanelDue ma 12 wierszy - krotkie proby tylko przy bledzie
        pd(f"Z {TBL[d]} {etap}{val:g} {s:g}x{n} {'OK' if good else 'FAIL'} {mx:.3f}mm")
    if good:
        base = h
        tilt = max(abs(h[i] - lvl0[i]) for i in range(4))
        if tilt > a.relev:
            level(f"dryf {tilt:.3f} od ostatniego poziomowania")
            base = lvl0 = chk("nowa baza")
    else:
        level(f"po bledzie {NAME[etap]} {d} {val:g}")
        base = lvl0 = chk("nowa baza")
    return good


def point(etap, d, val, n):
    """Ustawienia stopnia; proba --pre, potem pelna seria."""
    sets = {dd: [wset("V", dd), wset("A", dd), wset("J", dd)] for dd in ("up", "down")}
    if etap == "J":
        sets[d] = [max(a.vb, val / 120 + 1), a.ab, val]
    elif etap == "A":
        sets[d] = [a.va if a.va else a.vb, val, wset("J", d)]
        if a.ja is not None:
            for dd in ("up", "down"):
                sets[dd][2] = a.ja
    else:
        sets[d] = [val, wset("A", d), wset("J", d)]
    V, A = sets[d][0], sets[d][1]
    if etap == "A" and ASKOK:
        # stale skoki; mnoznik n / a.n (potwierdzenie = conf x cykle)
        k = n / a.n
        for s, c in ASKOK:
            if a.pre and not cycles(etap, d, val, f"proba s{s:g}", sets["up"], sets["down"], s, a.pre, False):
                return False
            if not cycles(etap, d, val, f"seria{round(c * k)} s{s:g}", sets["up"], sets["down"], s, round(c * k), True):
                return False
        return True
    if etap == "V":
        s = min(a.smax, round(V * V / A + 3, 1))
    else:
        s = max(1.0, round(V * V / A + 1, 2))
    if a.pre and not cycles(etap, d, val, "proba", sets["up"], sets["down"], s, a.pre, False):
        return False
    return cycles(etap, d, val, f"seria{n}", sets["up"], sets["down"], s, n, True)


def ladder(p, d):
    if W[(p, d)] is not None:
        LIM[(p, d)] = f"podana robocza {W[(p, d)]:g}"
        v.log(f"{NAME[p]} {d}: pominieta, robocza z parametru {W[(p, d)]:g}")
        return
    lo, hi = None, None
    for val in LAD[p]:
        if point(p, d, val, a.n):
            lo = val
        else:
            hi = val
            break
    if lo is None:
        LIM[(p, d)] = f"< {LAD[p][0]:g}"
        W[(p, d)] = LAD[p][0] * SAFE[p]
        v.log(f"{NAME[p]} {d}: BLAD juz przy {LAD[p][0]:g} - robocza {W[(p, d)]:g} (niesprawdzona)")
        pd(f"Z {TBL[d]} {p} FAIL at first {LAD[p][0]:g}")
        return
    if hi is not None:
        for _ in range(2):
            mid = round((lo + hi) / 2, 1)
            if mid <= lo or mid >= hi:
                break
            if point(p, d, mid, a.n):
                lo = mid
            else:
                hi = mid
        if not point(p, d, lo, a.n * a.conf):
            prev = [x for x in LAD[p] if x < lo]
            lo2 = prev[-1] if prev else lo / 2
            LIM[(p, d)] = f"{lo2:g} (potwierdzenie {lo:g} nieudane)"
            lo = lo2
        else:
            LIM[(p, d)] = f"{lo:g} (blad przy {hi:g})"
    else:
        LIM[(p, d)] = f">= {lo:g} (bez bledu do konca drabinki)"
    W[(p, d)] = round(lo * SAFE[p], 1)
    v.log(f"{NAME[p]} {d}: limit {LIM[(p, d)]}, robocza {W[(p, d)]:g}")
    pd(f"Z {TBL[d]} {p} limit {'>=' if hi is None else ''}{lo:g} work {W[(p, d)]:g}")


def summary():
    def f(p, d):
        return f"{W[(p, d)]:g}" if W[(p, d)] is not None else "-"
    lim = "; ".join(f"{NAME[p]} {d} {LIM[(p, d)]}" for (p, d) in LIM)
    v.log(f"PODSUMOWANIE zdir: robocze gora V{f('V', 'up')} mm/s A{f('A', 'up')} J{f('J', 'up')} | dol V{f('V', 'down')} "
          f"A{f('A', 'down')} J{f('J', 'down')} (mm/s, mm/s2, mm/min) | limity: {lim or '-'} | {nstep} serii | {CSV}")


v.connect()
v.log(f"START {a.opis!r} etap={a.etap} dir={DIRS} b={a.b} | " + v.state())
if v.status() != "idle":
    v.log("STOP: status != idle"); raise SystemExit(1)
if not v.homed() and not a.g28:
    v.log("STOP: osie niezbazowane (G28)"); raise SystemExit(1)
pr = v.m("sensors.probes[0]")
if pr["value"][0] >= pr["threshold"]:
    v.log("STOP: K0 zamknieta - otworzyc sonde"); raise SystemExit(1)
ax = v.m("move.axes")[2]
Z0 = {k: ax[k] for k in ("speed", "acceleration", "jerk")}
axs = v.m("move.axes")
XY0 = [axs[0]["acceleration"], axs[1]["acceleration"], axs[0]["jerk"], axs[1]["jerk"]]
v.log(f"Z: {ax['stepsPerMm']} krokow/mm, M203 Z{Z0['speed']}, M201 Z{Z0['acceleration']}, M566 Z{Z0['jerk']}, max {ax['max']}")
if abs(ax["stepsPerMm"] - 1600) > 1:
    v.log("STOP: M92 Z != 1600"); raise SystemExit(1)
if a.acc and not v.m("boards[0].accelerometer"):
    # 261116: zdir_step.g bez akcelerometru po cichu nie nagrywa - po kazdym wlaczeniu M955 z konsoli
    v.log('STOP: --acc, a LIS3DH nieskonfigurowany (M955 P0 C"spi.cs4+spi.cs3" I50)'); raise SystemExit(1)
if os.path.exists(STOPF):
    os.remove(STOPF)
why = "koniec"
try:
    # Gregor 261115: otwarta K0 zamyka sie od szarpniecia XY - dynamika XY jak bed mesh (mesh.g) na caly test
    v.run("M201 X2000 Y2000\nM566 X300 Y300", 20)
    v.log(f"XY na czas testu: M201 X2000 Y2000, M566 X300 Y300 (config {XY0})")
    if a.g28:
        ok, txt = v.run("G28", 600)
        if not ok or not v.homed():
            raise Stop(f"G28 na starcie nieudane: {txt[-300:]!r}")
        v.run('M98 P"0:/sys/safe_off.g"', 60)
        v.run("M201 X2000 Y2000\nM566 X300 Y300", 20)
        v.log("G28 na starcie OK")
    pd(f"Z test start {a.etap}" + (f" J{a.ja:g}" if a.ja is not None else "") + (" +LIS3DH" if a.acc else ""))
    level("start")
    b1 = chk("baza 1"); base = lvl0 = chk("baza 2")
    rep = max(abs(base[i] - b1[i]) for i in range(4))
    v.log(f"powtarzalnosc K0 bez ruchu: {rep:.4f} mm")
    v.log(f"kryterium: prog {a.thr} po korekcie dryfu {DRIFT} mm/m, seria {a.n}, poziomowanie przy przekosie > {a.relev}")
    if rep > a.thr / 2:
        pd(f"Z test: K0 repeat {rep:.3f}mm > {a.thr / 2:g}")
        raise Stop(f"K0 niepowtarzalna bez ruchu ({rep:.4f} > {a.thr / 2}) - najpierw to wyjasnic")
    for p in ("J", "A", "V"):
        if a.etap in ("all", NAME[p]):
            for d in DIRS:
                ladder(p, d)
    if a.etap in ("all", "final"):
        if any(W[(p, d)] is None for p in "JAV" for d in ("up", "down")):
            raise Stop("final: brak wszystkich wartosci roboczych (--Ju --Jd --Au --Ad --Vu --Vd)")
        up = [W[("V", "up")], W[("A", "up")], W[("J", "up")]]
        dn = [W[("V", "down")], W[("A", "down")], W[("J", "down")]]
        g1 = cycles("V", "both", 0.4, "final skoki", up, dn, 0.4, 300, True)
        g2 = cycles("V", "both", 20, "final 20mm", up, dn, 20, 30, True)
        v.log(f"final: skoki 0.4 {'ok' if g1 else 'BLAD'}, 20 mm {'ok' if g2 else 'BLAD'}")
except (Stop, NoRead) as e:
    why = "STOP: " + str(e)
    v.log(why)
finally:
    restore()
    pd("Z test END" if why == "koniec" else "Z test STOP - see log on PC")
    v.log("END " + v.state())
summary()
v.disconnect()
