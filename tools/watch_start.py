"""Sledzenie procedury startowej Vorona (TYLKO ODCZYT): status, okna na panelu, HesCal2 (hes_h/hes_hist), G31, siatka.
Konczy, gdy druk ruszy (warstwa >= 1) albo drukarka wroci do idle.
Uzycie: python tools/watch_start.py [--kthr 1.029]   (kThr jak w HesCal2 - do wyliczenia G31 "od stolu")"""
import argparse, time
import voron_api as v

ap = argparse.ArgumentParser()
ap.add_argument("--kthr", type=float, default=1.029)
a = ap.parse_args()


def say(s):
    print(time.strftime("%T"), s, flush=True)


hh_pos = len(v.download("0:/sys/hes_h.csv").encode())
hist_n = len(v.hist_rows())
last = {}
seen_print = False
say("start sledzenia")
while True:
    try:
        s = v.m("state"); j = v.m("job"); p = v.m("sensors.probes")[0]; c = v.m("move.compensation")
        cur = {"status": s["status"], "msg": s.get("displayMessage"), "G31": p["triggerHeight"],
               "siatka": f"{c['type']} {c.get('file')}", "box": (s.get("messageBox") or {}).get("message")}
        for k, val in cur.items():
            if last.get(k) != val and val not in (None, "") and not (k == "msg" and "jeszcze" in str(val)):
                say(f"{k}: {val}")
        last = cur
        if s["status"] in ("processing", "busy", "paused", "pausing"):
            seen_print = True
        raw = v.download("0:/sys/hes_h.csv").encode()
        if len(raw) > hh_pos:
            for line in raw[hh_pos:].decode("utf-8", "replace").splitlines():
                f = line.split(",")
                if len(f) >= 8 and f[1] == "K1":
                    say(f"dysza na K1: start {f[4]} limit {f[5]} -> z {f[6]} stan {f[7]}")
            hh_pos = len(raw)
        rows = v.hist_rows()
        for line in rows[hist_n:]:
            d = v.parse_hist(line)
            bed = d["zBed"] - d["zHEv"] + a.kthr
            say(f"HesCal2 wynik: G31(od czubka) {d['G31Z']} {d['wynik']} | od stolu {bed:.4f} | tipBed {d['k1Stol']} dz {d['dzK0HE']} zapas {d['zapas']:.4f}")
        hist_n = len(rows)
        if (j.get("layer") or 0) >= 1 and (j.get("filePosition") or 0) > 6000:
            say(f"druk ruszyl: warstwa {j.get('layer')}, G31 {p['triggerHeight']}, siatka {c['type']} {c.get('file')} - koniec sledzenia startu")
            break
        if seen_print and s["status"] == "idle":
            say("drukarka idle - start przerwany albo zakonczony"); break
    except Exception as e:
        say(f"blad odczytu: {e!r}"[:160])
    time.sleep(15)
