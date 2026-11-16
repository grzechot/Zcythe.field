"""zres_an.py - analiza nagran etapu res (zhop4_sweep.py --etap res, 261116): czas z-hopu vs rezonans stolu ~17 Hz.
Kazde nagranie: 3 z-hopy z przerwa (--dwell). Dla kazdego z-hopu (start = |a| > 0.1 g, kolejny >= 500 ms pozniej):
  pk_g    - szczyt |a| w 0..150 ms od startu
  res_g   - RMS drgan resztkowych 150..450 ms od startu (po wyladowaniu) - glowna miara
  f17_g   - amplituda skladowej 15-19 Hz w tym oknie
Uzycie: python zres_an.py [--local KATALOG]  (bez --local pobiera 0:/sys/accelerometer/zr - tylko odczyt)
Wynik: tabela (srednia z z-hopow) + PODSUMOWANIE, CSV zres_summary.csv w katalogu danych."""
import csv, json, os, re, statistics as st, sys, time, urllib.parse
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import voron_api as v

RATE = 1344.0
if "--local" in sys.argv:
    out = sys.argv[sys.argv.index("--local") + 1]
else:
    out = os.path.join(v.DATA, "acc", f"zr_{time.strftime('%y%m%d_%H%M')}")
    os.makedirs(out, exist_ok=True)
    names, first = [], 0
    while True:
        r = json.loads(v.get(f"/rr_filelist?dir=0:/sys/accelerometer/zr&first={first}", timeout=30))
        names += [f["name"] for f in r.get("files", []) if f["type"] == "f" and f["name"].endswith(".csv")]
        if not r.get("next"):
            break
        first = r["next"]
    for n in names:
        p = os.path.join(out, n)
        if not os.path.exists(p):
            open(p, "w", newline="").write(v.get("/rr_download?name=" + urllib.parse.quote(f"0:/sys/accelerometer/zr/{n}"), timeout=30))
    print(f"pobrano {len(names)} plikow -> {os.path.abspath(out)}")


def load(p):
    z = [float(l.split(",")[3]) for l in open(p) if l[:1].isdigit() and l.count(",") >= 3]
    z = np.array(z[4:])
    return z - np.median(z[len(z) // 2:]) if len(z) > 500 else None


def hops(a):
    # z-hopy co T + dwell >= ~640 ms; po wykryciu startu pomijamy 500 ms (okno resztkowe 150-450 ms)
    i, res = 0, []
    while i < len(a):
        if abs(a[i]) > 0.1:
            res.append(i)
            i += int(0.5 * RATE)
            continue
        i += 1
    return res


rows = []
for n in sorted(os.listdir(out)):
    if not n.endswith(".csv") or n.startswith("zres_"):
        continue
    a = load(os.path.join(out, n))
    if a is None:
        print(f"{n}: puste/krotkie"); continue
    bg = float(np.sqrt(np.mean(a[-int(0.1 * RATE):] ** 2)))
    for k, s0 in enumerate(hops(a)):
        w = a[s0 + int(0.15 * RATE): s0 + int(0.45 * RATE)]
        if len(w) < int(0.25 * RATE):
            continue
        S = np.abs(np.fft.rfft(w * np.hanning(len(w)))) * 4 / len(w)
        fr = np.fft.rfftfreq(len(w), 1 / RATE)
        m = re.match(r"\d+_\d+_(\d+)_(.*)\.csv", n)
        rows.append(dict(file=n, tag=m.group(2) if m else n, hop=k + 1, pk_g=float(np.max(np.abs(a[s0:s0 + int(0.15 * RATE)]))),
                         res_g=float(np.sqrt(np.mean(w ** 2))), f17_g=float(S[(fr >= 15) & (fr <= 19)].max()), bg_g=bg))

with open(os.path.join(out, "zres_summary.csv"), "w", newline="") as f:
    wr = csv.DictWriter(f, fieldnames=["file", "tag", "hop", "pk_g", "res_g", "f17_g", "bg_g"])
    wr.writeheader(); wr.writerows(rows)
g = {}
for r in rows:
    g.setdefault(r["tag"], []).append(r)
print(f"{'punkt':<14}{'n':>3}{'pk g':>8}{'res g':>8}{'f17 g':>8}{'tlo g':>8}")
for t, rs in g.items():
    print(f"{t:<14}{len(rs):>3}" + "".join(f"{st.mean(r[k] for r in rs):>8.3f}" for k in ("pk_g", "res_g", "f17_g", "bg_g")))
best = min(g.items(), key=lambda kv: st.mean(r["res_g"] for r in kv[1])) if g else None
print(f"PODSUMOWANIE zres: {len(rows)} z-hopow w {len(g)} punktach; najmniejsze drgania resztkowe: "
      f"{best[0] if best else '-'} ({st.mean(r['res_g'] for r in best[1]) if best else 0:.3f} g); dane {os.path.abspath(out)}")
