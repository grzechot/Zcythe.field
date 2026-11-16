"""acc_z.py - analiza nagran LIS3DH (os Z, czujnik na ramie stolu przy PP) z ztest_acc.g / ztest12.g Q1 (pliki_66, 261115).
Tylko odczyt z drukarki. Pobiera CSV z 0:/sys/accelerometer/<folder> do rrf\\data\\acc\\<folder>_<data>\\ i liczy dla kazdego
ruchu (os Z czujnika, grawitacja odjeta = mediana konca nagrania):
  peak_g   - najwieksze |a| [g] (szarpniecie na starcie / hamowaniu)
  p2p_g    - rozpietosc a [g]
  rms_g    - RMS calego nagrania [g]
  settle_ms- czas od startu do ostatniej probki z |a| > 0.05 g (wygaszanie drgan)
Grupy: zj -> jerk x kierunek (srednia z powtorzen); zt -> wysokosc x kierunek (trend w tescie).
Uzycie: python acc_z.py zj | zt [--local KATALOG]   (--local = bez pobierania, analiza plikow juz na dysku)
Wynik: tabela + linia PODSUMOWANIE, CSV acc_summary.csv w katalogu danych."""
import csv, json, os, re, statistics as st, sys, time, urllib.parse
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import voron_api as v

TH = 0.05  # [g] prog wygaszania
if "--th" in sys.argv:   # 261116: pojedynczy z-hop + cisza (zh) -> np. --th 0.02 (tlo statyczne rms 0.008 g)
    TH = float(sys.argv[sys.argv.index("--th") + 1])
SKIP = 4   # [probki] pomijane na poczatku nagrania (artefakt startu M956, 261116)
folder = sys.argv[1] if len(sys.argv) > 1 else "zj"
if "--local" in sys.argv:
    out = sys.argv[sys.argv.index("--local") + 1]
else:
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data", "acc", f"{folder}_{time.strftime('%y%m%d_%H%M')}")
    os.makedirs(out, exist_ok=True)
    names, first = [], 0
    while True:
        r = json.loads(v.get(f"/rr_filelist?dir=0:/sys/accelerometer/{folder}&first={first}", timeout=30))
        names += [f["name"] for f in r.get("files", []) if f["type"] == "f" and f["name"].endswith(".csv")]
        if not r.get("next"):
            break
        first = r["next"]
    for n in names:
        p = os.path.join(out, n)
        if not os.path.exists(p):
            d = v.get("/rr_download?name=" + urllib.parse.quote(f"0:/sys/accelerometer/{folder}/{n}"), timeout=30)
            open(p, "w", newline="").write(d)
    print(f"pobrano {len(names)} plikow -> {os.path.abspath(out)}")


def analyse(path):
    rate, z = 1344.0, []
    for line in open(path):
        m = re.search(r"Rate:?\s*([\d.]+)", line)
        if m:
            rate = float(m.group(1))
            continue
        parts = line.strip().split(",")
        if len(parts) >= 4 and parts[0].isdigit():
            z.append(float(parts[3]))
    # 261116: 1. probka kazdego nagrania M956 w ruchu odstaje o 0.2-0.4 g (artefakt startu, statyczne bez tego) - pomijamy
    z = z[SKIP:]
    if len(z) < 20:
        return None
    g0 = st.median(z[int(len(z) * 0.75):])
    a = [x - g0 for x in z]
    absa = [abs(x) for x in a]
    last = max((i for i, x in enumerate(absa) if x > TH), default=0)
    return dict(n=len(a), peak_g=max(absa), p2p_g=max(a) - min(a), rms_g=(sum(x * x for x in a) / len(a)) ** 0.5,
                settle_ms=1000.0 * last / rate)


rows = []
for n in sorted(os.listdir(out)):
    if not n.endswith(".csv") or n == "acc_summary.csv":
        continue
    r = analyse(os.path.join(out, n))
    if not r:
        continue
    d = "up" if n.endswith("_up.csv") else "dn"
    m = re.match(r"j(\d+)_a(\d+)_r(\d+)", n) if folder == "zj" else re.match(r"p(\d+)_z(\d+)_h(\d+)", n)
    key = (f"j{m.group(1)} a{m.group(2)}" if folder == "zj" else f"p{m.group(1)} z{int(m.group(2)):03d}") if m else n
    rows.append(dict(file=n, group=key, dir=d, **r))

with open(os.path.join(out, "acc_summary.csv"), "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=["file", "group", "dir", "n", "peak_g", "p2p_g", "rms_g", "settle_ms"])
    w.writeheader()
    w.writerows(rows)

groups = {}
for r in rows:
    groups.setdefault((r["group"], r["dir"]), []).append(r)
print(f"{'grupa':<12}{'kier':<5}{'n':>3}{'peak g':>9}{'p2p g':>8}{'rms g':>8}{'settle ms':>11}")
best = {}
for (g, d), rs in sorted(groups.items(), key=lambda kv: (int(re.search(r"\d+", kv[0][0]).group()), kv[0][0], kv[0][1])):
    pk = st.mean(r["peak_g"] for r in rs)
    print(f"{g:<12}{d:<5}{len(rs):>3}{pk:>9.3f}{st.mean(r['p2p_g'] for r in rs):>8.3f}"
          f"{st.mean(r['rms_g'] for r in rs):>8.4f}{st.mean(r['settle_ms'] for r in rs):>11.0f}")
    best.setdefault(d, []).append((pk, g))
s = ", ".join(f"{d}: najmniejszy peak {min(b)[1]} ({min(b)[0]:.3f} g), najwiekszy {max(b)[1]} ({max(b)[0]:.3f} g)"
              for d, b in sorted(best.items()))
print(f"PODSUMOWANIE acc_z {folder}: {len(rows)} nagran, {len(groups)} grup; {s}; dane {os.path.abspath(out)}")
