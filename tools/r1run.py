"""Sekwencja R1 dla Vorona (WIEDZA cz. C pkt 26). Kazdy tryb uruchamiac osobno, po zgodzie uzytkownika.
Uzycie: python tools/r1run.py S|A|B
  S = sam stan (odczyt, bez ruchu)
  A = dysza do 165 C, deployprobe0 (uzytkownik otwiera igle K0), k0offset, G32          (RUCH)
  B = hopZ + dynamika jak start.g, wipe, HesCal2 R1, przywrocenie dynamiki              (RUCH, zapis R1)
Log: data/logs/r1run_*.log. Na koncu linia PODSUMOWANIE."""
import sys
import voron_api as v


def main():
    part = (sys.argv[1:] or ["S"])[0].upper()
    v.set_log(f"r1run_{part}")
    v.connect()
    v.log("STAN: " + v.state())
    if part in ("A", "B"):
        if v.status() != "idle":
            v.log("PODSUMOWANIE: drukarka nie jest idle - przerywam"); return 1
        if not v.homed():
            v.log("PODSUMOWANIE: osie niezbazowane - przerywam (G28 tylko po zgodzie uzytkownika)"); return 1
    if part == "A":
        steps = [
            ('M568 P0 R165 S165 A2', 30),
            ('M116 P0', 600),
            ('M98 P"0:/sys/deployprobe0.g"', 600),
            ('M98 P"0:/sys/k0offset.g"', 30),
            ('set global.skipCal = false', 10),
            ('G32', 600),
        ]
    elif part == "B":
        steps = [
            ('set global.hopZ = max(1.5, sensors.probes[0].triggerHeight + 0.8)', 10),
            ('M201 X2000 Y2000', 10),
            ('M566 X300 Y300', 10),
            ('M98 P"0:/macros/wipe"', 300),
            ('M98 P"0:/macros/HesCal2" R1', 600),
        ]
    else:
        steps = []
    n0 = len(v.hist_rows()) if part == "B" else 0
    ok_all = True
    try:
        for code, mx in steps:
            ok, txt = v.run(code, mx)
            v.log("STAN: " + v.state())
            if not ok:
                ok_all = False
                v.log("BLAD - przerywam sekwencje"); break
    finally:
        if part == "B":
            v.run('M201 X{global.dynAx} Y{global.dynAy}', 10)
            v.run('M566 X{global.dynJx} Y{global.dynJy}', 10)
    if part == "A":
        v.log(f"PODSUMOWANIE A: {'OK' if ok_all else 'BLAD'}; " + v.state())
    elif part == "B":
        rows = v.hist_rows()
        if len(rows) > n0:
            d = v.parse_hist(rows[-1])
            g = v.m("global")
            v.log(f"PODSUMOWANIE B: {'OK' if ok_all else 'BLAD'}; wiersz {d['czas']} wynik {d['wynik']} "
                  f"zapas {d['zapas']:+.4f} tipBed {d['k1Stol']:.4f} dz {d['dzK0HE']:.4f} G31 {d['G31Z']:.4f} | "
                  f"refG31Z {g.get('refG31Z')} lastGoodG31 {g.get('lastGoodG31')} G31 runtime {v.m('sensors.probes')[0]['triggerHeight']}")
        else:
            v.log(f"PODSUMOWANIE B: {'OK' if ok_all else 'BLAD'}; brak nowego wiersza w hes_hist.csv")
    v.disconnect()
    return 0 if ok_all else 1


if __name__ == "__main__":
    sys.exit(main())
