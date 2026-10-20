"""Pomiar zapasu K1 nad K0 po regulacji sruby (WIEDZA cz. C pkt 27). RUCH - tylko po zgodzie, uzytkownik obserwuje.
N x HesCal2 z zablokowanym zapisem G31 (lastGoodG31 = 99); na koncu lastGoodG31 i dynamika przywrocone.
Uzycie: python tools/k1meas.py [--n 4] [--wipe-each | --bez-wipe] [--kthr 1.029] [--ref-zapas 0.2125] [--cel 0.18] [--mm-obr 0.47] [--obrot "1/2"]
  --kthr/--ref-zapas: kThr w HesCal2 i zapas, przy ktorym je wyznaczono (13.10: 1.029 przy 0.2125)
  --mm-obr: zmiana zapasu na 1 obrot sruby (13.10: ~0.47; odkrecanie PODNOSI K1)
Wynik: data/k1meas_*.csv, log data/logs/k1meas_*.log, na koncu tabela i PODSUMOWANIE."""
import argparse, csv, os, sys, time
import voron_api as v

ap = argparse.ArgumentParser()
ap.add_argument("--n", type=int, default=4)
ap.add_argument("--wipe-each", action="store_true", help="wipe przed kazdym przebiegiem (wtedy kazdy jest 'pierwszy po wipe')")
ap.add_argument("--bez-wipe", action="store_true", help="bez wipe (zadanie 02: czy dz wraca do ~0.98)")
ap.add_argument("--kthr", type=float, default=1.029)
ap.add_argument("--ref-zapas", type=float, default=0.2125)
ap.add_argument("--cel", type=float, default=0.18)
ap.add_argument("--mm-obr", type=float, default=0.47)
ap.add_argument("--obrot", default="", help="opis regulacji przed pomiarem, np. 'odkrecone 1/2'")
a = ap.parse_args()

v.set_log("k1meas")
out = os.path.join(v.DATA, f"k1meas_{time.strftime('%Y%m%d_%H%M')}.csv")
v.connect()
v.log("STAN: " + v.state())
if v.status() != "idle" or not v.homed():
    v.log("PODSUMOWANIE: drukarka nie idle albo niezbazowana - przerywam"); sys.exit(1)
keep = v.m("global")["lastGoodG31"]
v.log(f"zapamietane lastGoodG31 = {keep}  (regulacja: {a.obrot or '-'})")
res = []
try:
    for code, mx in [("set global.lastGoodG31 = 99", 10),
                     ("set global.hopZ = max(1.5, sensors.probes[0].triggerHeight + 0.8)", 10),
                     ("M201 X2000 Y2000", 10), ("M566 X300 Y300", 10)]:
        ok, _ = v.run(code, mx)
        if not ok:
            raise RuntimeError(code)
    for i in range(a.n):
        first = (a.wipe_each or i == 0) and not a.bez_wipe
        if first:
            ok, _ = v.run('M98 P"0:/macros/wipe"', 300)
            if not ok:
                raise RuntimeError("wipe")
        n0 = len(v.hist_rows())
        ok, txt = v.run('M98 P"0:/macros/HesCal2"', 300)
        rows = v.hist_rows()
        if len(rows) > n0:
            d = v.parse_hist(rows[-1]); d["nr"] = i + 1; d["poWipe"] = first
            res.append(d)
            v.log(f"  PRZEBIEG {i+1}{' (1. po wipe)' if first else ''}: zapas {d['zapas']:+.4f} tipBed {d['k1Stol']:.4f} "
                  f"dz {d['dzK0HE']:.4f} G31(stare kThr) {d['G31Z']:.4f} {d['wynik']}")
        else:
            v.log("  brak nowego wiersza w hes_hist.csv")
        if not ok:
            raise RuntimeError("HesCal2")
except Exception as e:
    v.log(f"BLAD: {e!r} - przerywam")
finally:
    for code in (f"set global.lastGoodG31 = {keep}", "M201 X{global.dynAx} Y{global.dynAy}", "M566 X{global.dynJx} Y{global.dynJy}"):
        v.run(code, 10)
    v.log("PRZYWROCONO: " + v.state())
    v.disconnect()

if res:
    with open(out, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["nr", "poWipe", "regulacja", "zapas"] + v.HIST_COLS)
        for d in res:
            w.writerow([d["nr"], d["poWipe"], a.obrot, f"{d['zapas']:.4f}"] + [d.get(k) for k in v.HIST_COLS])
    print("\n| nr | po wipe | zapas | tipBed | dz | G31 (stare kThr) | wynik |\n|---|---|---|---|---|---|---|")
    for d in res:
        print(f"| {d['nr']} | {'tak' if d['poWipe'] else ''} | {d['zapas']:+.4f} | {d['k1Stol']:.4f} | {d['dzK0HE']:.4f} | {d['G31Z']:.4f} | {d['wynik']} |")
    fw = [d["zapas"] for d in res if d["poWipe"]] or [res[0]["zapas"]]   # bez wipe: 1. przebieg
    zf = sum(fw) / len(fw)
    zs = sorted(d["zapas"] for d in res)
    brak = a.cel - zf
    kier = "odkrec (podnosi K1)" if brak > 0 else "dokrec (obniza K1)"
    ob = v.frac(brak / a.mm_obr)
    dz = [d["dzK0HE"] for d in res]
    v.log(f"PODSUMOWANIE: zapas {'1. przebieg (bez wipe)' if a.bez_wipe else '1. po wipe'} {zf:+.4f} (n={len(fw)}), wszystkie {zs[0]:+.4f}..{zs[-1]:+.4f}; dz {min(dz):.4f}..{max(dz):.4f}; "
          f"cel {a.cel} -> {'w tolerancji (+-0.05)' if abs(brak) <= 0.05 else f'{kier} ok. {ob} obr. ({brak:+.3f} mm przy {a.mm_obr} mm/obr)'}; "
          f"nowe kThr = {a.kthr} + ({zf:.4f} - {a.ref_zapas}) = {a.kthr + zf - a.ref_zapas:.4f} (dopiero gdy zapas w celu); CSV: {out}")
else:
    v.log("PODSUMOWANIE: brak przebiegow")
