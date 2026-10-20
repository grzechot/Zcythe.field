"""Przekos bramy po wylaczeniu silnikow Z (zad. 07). G28 (gdy osie niezbazowane) -> G32 -> G32 (poziom wyjsciowy)
-> M18 Z (silniki Z bez pradu) -> postoj --off s -> G28 Z -> G32. Miara: 1. korekta ostatniego G32 (wzgl. sredniej
i bezwzgledna). Uzycie: python zdrop.py [--off 300] [--opis "..."]"""
import argparse, os, re, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import voron_api as v

ap = argparse.ArgumentParser()
ap.add_argument("--off", type=int, default=300)
ap.add_argument("--opis", default="")
a = ap.parse_args()
v.set_log("zdrop")
v.log(f"START {a.opis!r} off={a.off} | " + v.state())
if v.status() != "idle":
    v.log("STOP: status != idle"); raise SystemExit(1)

RX = re.compile(r"Leadscrew adjustments made:\s*([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)\s+([-\d.]+).*?before \(([-\d.]+), ([-\d.]+)\)")


def g32(label):
    ok, txt = v.run("G32", 900)
    passes = RX.findall(txt)
    if not ok or not passes:
        v.log(f"STOP: G32 ({label}) nieudane: {txt[:300]!r}"); raise SystemExit(1)
    adj = [float(x) for x in passes[0][:4]]; mean = sum(adj) / 4
    devs = " / ".join(p[5] for p in passes)
    v.log(f"G32 {label}: 1. korekta LP {adj[0]:+.3f} LT {adj[1]:+.3f} PT {adj[2]:+.3f} PP {adj[3]:+.3f} "
          f"(srednia {mean:+.3f}; wzgl. sredniej {' '.join(f'{x - mean:+.3f}' for x in adj)}); przebiegi {len(passes)}, dev {devs}")
    return adj, len(passes)


if not v.homed():
    ok, txt = v.run("G28", 600)
    v.log(f"G28: {txt[-300:]!r}")
    if not ok or not v.homed():
        v.log("STOP: G28 nieudane"); raise SystemExit(1)
g32("1")
g32("2 (poziom wyjsciowy)")
v.run("G90\nG1 Z10 F600", 60)
v.run("M18 Z", 30)
v.log(f"M18 Z - silniki Z bez pradu, postoj {a.off} s")
time.sleep(a.off)
ok, txt = v.run("G28 Z", 300)
v.log(f"G28 Z: {txt[-300:]!r}")
if not ok:
    v.log("STOP: G28 Z nieudane"); raise SystemExit(1)
adj, n = g32("po wylaczeniu")
mean = sum(adj) / 4
v.log(f"PODSUMOWANIE: przekos po {a.off} s bez pradu: max |korekta - srednia| {max(abs(x - mean) for x in adj):.3f} "
      f"(LP/LT/PT/PP {' '.join(f'{x - mean:+.3f}' for x in adj)}), G32 {n} przebiegow; cel <= 0.5")
