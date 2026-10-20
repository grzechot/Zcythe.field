"""Logger PC (TYLKO ODCZYT): co --dt s stan Vorona do CSV; konczy po wydruku (idle po druku) albo po --h godzinach.
Uzycie: python tools/pclog.py [--dt 30] [--h 3] [--out data/pclog_RRRRMMDD_HHMM.csv]"""
import argparse, csv, os, time
import voron_api as v

ap = argparse.ArgumentParser()
ap.add_argument("--dt", type=int, default=30)
ap.add_argument("--h", type=float, default=3)
ap.add_argument("--out", default=os.path.join(v.DATA, f"pclog_{time.strftime('%Y%m%d_%H%M')}.csv"))
a = ap.parse_args()

seen_print = False
t_end = time.time() + a.h * 3600
with open(a.out, "a", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow(["czas_pc", "status", "plik_poz", "komunikat", "stol", "dysza", "X", "Y", "Z", "siatka", "G31", "wentylator0"])
    while time.time() < t_end:
        try:
            s = v.m("state"); j = v.m("job"); h = v.m("heat.heaters"); ax = v.m("move.axes")
            w.writerow([time.strftime("%F %T"), s["status"], j.get("filePosition"), s.get("displayMessage"),
                        h[0]["current"], h[1]["current"], ax[0]["userPosition"], ax[1]["userPosition"], ax[2]["userPosition"],
                        v.m("move.compensation")["type"], v.m("sensors.probes")[0]["triggerHeight"],
                        (v.m("fans")[0] or {}).get("actualValue")])
            f.flush()
            if s["status"] in ("processing", "paused", "pausing", "resuming", "busy"):
                seen_print = True
            elif seen_print and s["status"] == "idle":
                print(time.strftime("%F %T"), "koniec wydruku - logger konczy"); break
        except Exception as e:
            w.writerow([time.strftime("%F %T"), "blad odczytu", repr(e)[:120]]); f.flush()
        time.sleep(a.dt)
print("logger: koniec", time.strftime("%F %T"), "->", a.out)
