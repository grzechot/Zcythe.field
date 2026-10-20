"""Przeglad po wydruku (TYLKO ODCZYT): stan, pobranie hes_hist.csv, mesh_log.csv, cancel_log.csv do data/, ostatnie wiersze.
Uzycie: python tools/fetch_logs.py [--n 3]"""
import argparse, os, time
import voron_api as v

ap = argparse.ArgumentParser()
ap.add_argument("--n", type=int, default=3, help="ile ostatnich wierszy pokazac")
a = ap.parse_args()

v.connect()
s = v.m("state"); j = v.m("job")
print(f"{time.strftime('%F %T')} status={s['status']} G31={v.m('sensors.probes')[0]['triggerHeight']} "
      f"siatka={v.m('move.compensation')['type']} ostatni plik={(j.get('lastFileName') or '-')} "
      f"czas ostatniego druku={j.get('lastDuration')} s")
for name in ("hes_hist.csv", "mesh_log.csv", "cancel_log.csv"):
    try:
        txt = v.download("0:/sys/" + name)
    except Exception as e:
        print(f"\n{name}: blad pobrania {e!r}"); continue
    with open(os.path.join(v.DATA, name), "w", encoding="utf-8", newline="") as f:
        f.write(txt)
    rows = txt.strip().splitlines()
    print(f"\n{name} ({len(rows) - 1} wierszy, zapisano data/{name}); naglowek: {rows[0]}")
    for line in rows[-a.n:]:
        if name == "hes_hist.csv":
            d = v.parse_hist(line)
            print(f"  {d['czas']} {d['wynik']}: G31 {d['G31Z']:.4f} zapas {d['zapas']:+.4f} tipBed {d['k1Stol']:.4f} dz {d['dzK0HE']:.4f} zBed {d['zBed']:.4f}")
        else:
            print("  " + line)
v.disconnect()
