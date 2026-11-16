"""zhop4_sweep.py - z-hop w 4 etapach, kazdy z wlasnym przyspieszeniem (pliki_69, 261116, Gregor).
RUCH MASZYNY - tylko po zgodzie Gregora (261116: "drukarka dzis przeznaczona do testow").
Wymaga: idle, XYZ zbazowane (albo --g28), K0 otwarta, na karcie 0:/sys/zhop4_step.g, ztest_chk.g, ztest_lvl.g, msg.g.
Trident: Z+ = stol w DOL. Etapy: 1 stol w dol rozpedzanie (A1), 2 stol w dol hamowanie (A2),
3 stol w gore rozpedzanie (A3), 4 stol w gore hamowanie = ladowanie (A4). Jeden jerk J.

Przebieg:
  1. kontrola laczenia odcinkow: czas serii vs model "polaczone" (szczyt na granicy) i "zatrzymanie na granicy"
     - logowane przy kazdej serii (t_cyklu, t_pol, t_stop); --etap junction = tylko to
  2. drabinki etapow po kolei (--kolej 3,4,1,2): badany etap rosnaco, pozostale na wartosciach bazowych
     (--a1..--a4); kazdy stopien: proba --pre + seria --n x skok 0.4, do tego --nrec pojedynczych z-hopow
     z nagraniem LIS3DH (--acc; ~2 s, jeden z-hop + cisza = drgania i czas uspokojenia), potem pomiar K0
     (zmiana rogu minus dryf x droga > --thr = BLAD, jak zdir_sweep v2). Do 1. bledu, polowienie 1x, potwierdzenie
     --conf x n. Robocza = --safe x limit. Kolejny etap korzysta z roboczej poprzedniego.
  3. final: robocze A1..A4: 300 x 0.4 + 30 x 2 mm.
Stop: plik rrf\\data\\zdir_STOP. Postep na PanelDue (msg.g). Wynik: data/zhop4_YYMMdd_HHMM.csv, linia PODSUMOWANIE.
Nagrania: 0:/sys/accelerometer/zh/ -> analiza: python acc_z.py zh (settle_ms przy progu 0.02 g)."""
import argparse, csv, math, os, re, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import voron_api as v

ap = argparse.ArgumentParser()
ap.add_argument("--etap", default="all", choices=["all", "junction", "ladder", "final", "res"])
# 261116 etap res: czas z-hopu vs rezonans stolu ~17 Hz. Profil trojkatny, ta sama A we wszystkich etapach,
# t1 = czas jednego impulsu przyspieszenia (z-hop = 4 x t1), A = s/t1^2, V = szczyt s/t1 (+0.3 zapasu).
# Model (1 postac, 17 Hz): resztkowe drgania ~ 0 przy t1 = pol okresu (29.4 ms, z-hop 118 ms).
ap.add_argument("--t1", default="22,24,26,28,29.4,31,34,37,40,50", help="etap res: czasy impulsu [ms]")
ap.add_argument("--ref", default="1000:13.2,2000:13.2", help="etap res: punkty odniesienia A:V (profil obecny)")
ap.add_argument("--nres", type=int, default=50, help="etap res: z-hopy w serii kontrolnej (K0)")
ap.add_argument("--dwell", type=int, default=550, help="etap res: przerwa miedzy z-hopami w nagraniu [ms]")
ap.add_argument("--vmax", type=float, default=18.5, help="etap res: gorna granica V [mm/s]")
ap.add_argument("--kolej", default="3,4,1,2", help="kolejnosc drabinek etapow")
ap.add_argument("--j", type=float, default=20, help="jerk Z [mm/min]")
ap.add_argument("--vd", type=float, default=13.2, help="predkosc stol w dol [mm/s]")
ap.add_argument("--vu", type=float, default=13.2, help="predkosc stol w gore [mm/s]")
ap.add_argument("--a1", type=float, default=1000); ap.add_argument("--a2", type=float, default=1000)
ap.add_argument("--a3", type=float, default=460); ap.add_argument("--a4", type=float, default=460)
ap.add_argument("--lad", default="400,700,1000,1500,2000", help="drabinka przyspieszen [mm/s2]")
ap.add_argument("--lad3", help="osobna drabinka dla etapu 3 (domyslnie --lad)")
ap.add_argument("--safe", type=float, default=0.5, help="robocza = safe x limit")
ap.add_argument("--b", type=float, default=30)
ap.add_argument("--s", type=float, default=0.4, help="skok z-hopu [mm]")
ap.add_argument("--n", type=int, default=100)
ap.add_argument("--pre", type=int, default=3)
ap.add_argument("--conf", type=int, default=3)
ap.add_argument("--nrec", type=int, default=2, help="pojedyncze z-hopy z nagraniem na stopien (z --acc)")
ap.add_argument("--thr", type=float, default=0.03)
ap.add_argument("--drift", default="-0.0026,-0.0021,-0.0084,-0.0139")
ap.add_argument("--relev", type=float, default=0.03)
ap.add_argument("--g28", action="store_true")
ap.add_argument("--acc", action="store_true")
ap.add_argument("--opis", default="")
a = ap.parse_args()
DRIFT = [float(x) for x in a.drift.split(",")]
LAD = [float(x) for x in a.lad.split(",")]
LAD3 = [float(x) for x in a.lad3.split(",")] if a.lad3 else LAD
KOLEJ = [int(x) for x in a.kolej.split(",")]
W = {1: a.a1, 2: a.a2, 3: a.a3, 4: a.a4}
LIM = {}

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
v.set_log("zhop4")
STAMP = time.strftime('%y%m%d_%H%M')
CSV = os.path.join(v.DATA, f"zhop4_{STAMP}.csv")
STOPF = os.path.join(v.DATA, "zdir_STOP")
COLS = ["czas", "etap", "wartosc", "proba", "A1", "A2", "A3", "A4", "J", "skok", "cykle",
        "dLP", "dLT", "dPT", "dPP", "max", "wynik", "t_cyklu_ms", "t_pol_ms", "t_stop_ms", "droga_m", "max_surowy"]
rows = []
base = lvl0 = None
nstep = nrec = 0


class Stop(Exception):
    pass


class NoRead(Exception):
    pass


def pd(text):
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
        raise Stop(f"ztest_chk ({label}): {'K0 zamknieta' if c == 1 else 'brak odczytu K0'} {txt[:200]!r}")
    return [float(x) for x in v.m("global.ztH")]


def level(label):
    ok, txt = v.run('M98 P"0:/sys/ztest_lvl.g"', 1200)
    dev = v.m("global.ztLvl")
    if not ok or dev is None or dev < 0:
        raise Stop(f"poziomowanie ({label}) nieudane: {txt[:200]!r}")
    v.log(f"poziomowanie ({label}): odchylka {dev:.4f}")


def recover(label):
    global nrec, lvl0
    nrec += 1
    if nrec > 4:
        raise Stop("ponad 4 odzyskania po utknieciu")
    v.log(f"ODZYSK {nrec} ({label}): G28 + poziomowanie")
    pd(f"Z hop4 STALL {label} - rehome"[:40])
    ok, txt = v.run("G28", 600)
    if not ok or not v.homed():
        raise Stop(f"G28 po utknieciu nieudane: {txt[-300:]!r}")
    v.run('M98 P"0:/sys/safe_off.g"', 60)
    v.run("M201 X2000 Y2000\nM566 X300 Y300", 20)
    level(f"odzysk {nrec}")
    lvl0 = chk(f"baza po odzysku {nrec}")
    return lvl0


def t_dir(aa, ab, s, vmax):
    """czas jednego kierunku [s]: polaczone (szczyt na granicy) i z zatrzymaniem na granicy odcinkow"""
    vp = math.sqrt(2 * aa * ab * s / (aa + ab))
    if vp <= vmax:
        tj = vp / aa + vp / ab
    else:
        tj = vmax / aa + vmax / ab + (s - vmax ** 2 / (2 * aa) - vmax ** 2 / (2 * ab)) / vmax
    ts = 0.0
    for si, ai in ((s * ab / (aa + ab), aa), (s * aa / (aa + ab), ab)):
        vpi = math.sqrt(si * ai)
        ts += 2 * vpi / ai if vpi <= vmax else 2 * vmax / ai + (si - vmax ** 2 / ai) / vmax
    return tj, ts


def model_ms(A, s):
    j1, s1 = t_dir(A[1], A[2], s, a.vd)
    j2, s2 = t_dir(A[3], A[4], s, a.vu)
    return 1000 * (j1 + j2), 1000 * (s1 + s2)


def step(A, s, n, rec, f="", w=0):
    cmd = (f'M98 P"0:/sys/zhop4_step.g" A{A[1]:g} C{A[2]:g} D{A[3]:g} H{A[4]:g} J{a.j:g} V{a.vd:g} U{a.vu:g}'
           f' S{s:g} N{n} B{a.b:g}' + (f' W{w}' if w else "") + (f' R1 F"{f}"' if rec else ""))
    ok, txt = v.run(cmd, 3600, wait0=5.0 if rec else 1.0)
    if not ok or "zhop4_step done" not in txt:
        if txt == "" and v.status() == "idle" and abs(v.m("move.axes")[2]["userPosition"] - a.b) < 0.01:
            v.log("  UWAGA: pusta odpowiedz zhop4_step.g, status idle, Z = B - pomiar decyduje")
            return None
        raise Stop(f"zhop4_step.g: {txt[:300]!r}")
    m = re.search(r"ms (-?[\d.]+)", txt)
    return float(m.group(1)) / n if m else None


def series(ph, val, tag, A, s, n, rec):
    """Seria + (opcjonalnie) nagrania + pomiar K0; zwraca dobry."""
    global base, lvl0, nstep
    if os.path.exists(STOPF):
        raise Stop("plik zdir_STOP")
    nstep += 1
    tc = step(A, s, n, False)
    if rec and a.acc and ph == 7:   # etap res: 1 nagranie = 3 z-hopy z przerwa --dwell (mniej nagran = mniej ryzyka WiFi)
        step(A, s, 3, True, f"zr/{STAMP}_{nstep:03d}_{tag.replace(' ', '_')}.csv", a.dwell)
    elif rec and a.acc:
        for k in range(a.nrec):
            step(A, s, 1, True, f"zh/{STAMP}_{nstep:03d}_P{ph}_{val:g}_{k + 1}.csv")
    tj, ts = model_ms(A, s)
    try:
        h = chk(f"etap {ph} {val:g} {tag}")
    except NoRead as e:
        v.log(str(e))
        rows.append([time.strftime("%y%m%d %H:%M:%S"), ph, f"{val:g}", tag, *[f"{A[i]:g}" for i in (1, 2, 3, 4)], f"{a.j:g}",
                     f"{s:g}", n, "", "", "", "", "", "UTKNIECIE", f"{tc or 0:.1f}", f"{tj:.1f}", f"{ts:.1f}", "", ""])
        save()
        base = recover(f"P{ph} A{val:g}")
        return False
    dr = (n + ((3 if ph == 7 else a.nrec) if rec and a.acc else 0)) * 2 * s / 1000
    raw = [h[i] - base[i] for i in range(4)]
    dd = [raw[i] - DRIFT[i] * dr for i in range(4)]
    mx = max(abs(x) for x in dd)
    good = mx <= a.thr
    rows.append([time.strftime("%y%m%d %H:%M:%S"), ph, f"{val:g}", tag, *[f"{A[i]:g}" for i in (1, 2, 3, 4)], f"{a.j:g}",
                 f"{s:g}", n, *[f"{x:+.4f}" for x in dd], f"{mx:.4f}", "ok" if good else "BLAD",
                 f"{tc or 0:.1f}", f"{tj:.1f}", f"{ts:.1f}", f"{dr:.3f}", f"{max(abs(x) for x in raw):.4f}"])
    save()
    tinfo = f"cykl {tc:.1f} ms (model polaczone {tj:.1f} / stop {ts:.1f})" if tc else "cykl ?"
    v.log(f"  P{ph} {val:g} {tag}: A {A[1]:g}/{A[2]:g}/{A[3]:g}/{A[4]:g} J{a.j:g} | skok {s:g} x{n} -> "
          f"{'ok' if good else 'BLAD'} (LP {dd[0]:+.3f} LT {dd[1]:+.3f} PT {dd[2]:+.3f} PP {dd[3]:+.3f}) | {tinfo}")
    if not good or not tag.startswith("proba"):
        pd(f"Z hop P{ph} A{val:g} {s:g}x{n} {'OK' if good else 'FAIL'} {mx:.3f}")
    if good:
        base = h
        if max(abs(h[i] - lvl0[i]) for i in range(4)) > a.relev:
            level("dryf od ostatniego poziomowania")
            base = lvl0 = chk("nowa baza")
    else:
        level(f"po bledzie P{ph} {val:g}")
        base = lvl0 = chk("nowa baza")
    return good


def point(ph, val, n):
    A = dict(W); A[ph] = val
    if a.pre and not series(ph, val, "proba", A, a.s, a.pre, False):
        return False
    return series(ph, val, f"seria{n}", A, a.s, n, True)


def ladder(ph):
    lad = LAD3 if ph == 3 else LAD
    lo = hi = None
    for val in lad:
        if point(ph, val, a.n):
            lo = val
        else:
            hi = val
            break
    if lo is None:
        LIM[ph] = f"< {lad[0]:g}"
        v.log(f"etap {ph}: BLAD juz przy {lad[0]:g} - zostaje {W[ph]:g}")
        pd(f"Z hop P{ph} FAIL at first {lad[0]:g}")
        return
    if hi is not None:
        mid = round((lo + hi) / 2, -1)
        if lo < mid < hi:
            if point(ph, mid, a.n):
                lo = mid
            else:
                hi = mid
        if point(ph, lo, a.n * a.conf):
            LIM[ph] = f"{lo:g} (blad przy {hi:g})"
        else:
            prev = [x for x in lad if x < lo]
            lo = prev[-1] if prev else lo / 2
            LIM[ph] = f"{lo:g} (potwierdzenie wyzszego nieudane)"
    else:
        LIM[ph] = f">= {lo:g} (bez bledu do konca drabinki)"
    W[ph] = round(lo * a.safe, -1)
    v.log(f"etap {ph}: limit {LIM[ph]}, robocza {W[ph]:g}")
    pd(f"Z hop P{ph} limit {'>=' if hi is None else ''}{lo:g} work {W[ph]:g}")


def summary():
    lim = "; ".join(f"P{p} {LIM[p]}" for p in sorted(LIM)) or "-"
    v.log(f"PODSUMOWANIE zhop4: robocze A1 {W[1]:g} A2 {W[2]:g} A3 {W[3]:g} A4 {W[4]:g} mm/s2, J{a.j:g}, "
          f"V {a.vd:g}/{a.vu:g} | limity: {lim} | {nstep} serii | {CSV}")


v.connect()
v.log(f"START {a.opis!r} etap={a.etap} kolej={KOLEJ} J{a.j:g} baza A {W} | " + v.state())
if v.status() != "idle":
    v.log("STOP: status != idle"); raise SystemExit(1)
if not v.homed() and not a.g28:
    v.log("STOP: osie niezbazowane (G28)"); raise SystemExit(1)
pr = v.m("sensors.probes[0]")
if pr["value"][0] >= pr["threshold"]:
    v.log("STOP: K0 zamknieta - otworzyc sonde"); raise SystemExit(1)
if a.acc and not v.m("boards[0].accelerometer"):
    v.log('STOP: --acc, a LIS3DH nieskonfigurowany (M955 P0 C"spi.cs4+spi.cs3" I50)'); raise SystemExit(1)
ax = v.m("move.axes")[2]
Z0 = {k: ax[k] for k in ("speed", "acceleration", "jerk")}
axs = v.m("move.axes")
XY0 = [axs[0]["acceleration"], axs[1]["acceleration"], axs[0]["jerk"], axs[1]["jerk"]]
if abs(ax["stepsPerMm"] - 1600) > 1:
    v.log("STOP: M92 Z != 1600"); raise SystemExit(1)
if os.path.exists(STOPF):
    os.remove(STOPF)
why = "koniec"
try:
    v.run("M201 X2000 Y2000\nM566 X300 Y300", 20)
    if a.g28:
        ok, txt = v.run("G28", 600)
        if not ok or not v.homed():
            raise Stop(f"G28 na starcie nieudane: {txt[-300:]!r}")
        v.run('M98 P"0:/sys/safe_off.g"', 60)
        v.run("M201 X2000 Y2000\nM566 X300 Y300", 20)
    pd(f"Z hop4 start {a.etap} J{a.j:g}" + (" +LIS3DH" if a.acc else ""))
    level("start")
    b1 = chk("baza 1"); base = lvl0 = chk("baza 2")
    rep = max(abs(base[i] - b1[i]) for i in range(4))
    v.log(f"powtarzalnosc K0 bez ruchu: {rep:.4f} mm")
    if rep > a.thr / 2:
        pd(f"Z hop4: K0 repeat {rep:.3f}mm > {a.thr / 2:g}")
        raise Stop(f"K0 niepowtarzalna bez ruchu ({rep:.4f})")
    if a.etap in ("all", "junction"):
        # symetrycznie (wszystkie = A3) i rozdzielone (baza) - czas cyklu vs model
        sym = {i: W[3] for i in (1, 2, 3, 4)}
        series(0, W[3], "junction sym", sym, a.s, 50, True)
        series(0, W[1], "junction split", dict(W), a.s, 50, True)
    if a.etap == "res":
        pts = [(float(x.split(":")[0]), float(x.split(":")[1]), f"ref A{x.split(':')[0]}") for x in a.ref.split(",") if x]
        for t1 in [float(x) for x in a.t1.split(",") if x]:
            A_ = round(a.s / (t1 / 1000) ** 2)
            pts.append((A_, min(a.vmax, round(a.s / (t1 / 1000) + 0.3, 1)), f"t1 {t1:g}"))
        res_ok = []
        for A_, V_, tag in pts:
            a.vd = a.vu = V_
            g = series(7, A_, tag, {i: A_ for i in (1, 2, 3, 4)}, a.s, a.nres, True)
            res_ok.append(f"{tag} {'ok' if g else 'BLAD'}")
        v.log("res: " + ", ".join(res_ok))
    if a.etap in ("all", "ladder"):
        for ph in KOLEJ:
            ladder(ph)
    if a.etap in ("all", "final"):
        g1 = series(9, 0.4, "final skoki", dict(W), 0.4, 300, True)
        g2 = series(9, 2, "final 2mm", dict(W), 2.0, 30, True)
        v.log(f"final: 300 x 0.4 {'ok' if g1 else 'BLAD'}, 30 x 2 mm {'ok' if g2 else 'BLAD'}")
except (Stop, NoRead) as e:
    why = "STOP: " + str(e)
    v.log(why)
finally:
    restore()
    pd("Z hop4 END" if why == "koniec" else "Z hop4 STOP - see log on PC")
    v.log("END " + v.state())
summary()
v.disconnect()
