"""acc_spec.py - widmo amplitudy drgan Z (LIS3DH) z nagran pojedynczych z-hopow (261116).
Uzycie: python acc_spec.py KATALOG [--out plik.png]   (tylko pliki na dysku, bez drukarki)
Okno 'po z-hopie' = 0.10-0.70 s od poczatku nagrania, 'tlo' = ostatnie 0.6 s. Srednia amplitud z wszystkich nagran."""
import glob, os, sys
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

RATE = 1344.0
d = sys.argv[1]
out = sys.argv[sys.argv.index("--out") + 1] if "--out" in sys.argv else os.path.join(d, "widmo_z.png")


def load(p):
    z = [float(l.split(",")[3]) for l in open(p) if l[:1].isdigit() and l.count(",") >= 3]
    z = np.array(z[4:])
    return z - np.median(z[len(z) // 2:]) if len(z) > 2000 else None


def spec(seg):
    w = np.hanning(len(seg))
    return np.fft.rfftfreq(len(seg), 1 / RATE), np.abs(np.fft.rfft(seg * w)) * 2 / w.sum()


n0, n1 = int(0.10 * RATE), int(0.70 * RATE)
S_hop, S_bg = [], []
for p in sorted(glob.glob(os.path.join(d, "*.csv"))):
    a = load(p)
    if a is None:
        continue
    f, s = spec(a[n0:n1]); S_hop.append(s)
    fb, sb = spec(a[-(n1 - n0):]); S_bg.append(sb)
NREC = len(S_hop)
S_hop, S_bg = np.mean(S_hop, axis=0), np.mean(S_bg, axis=0)

fig, ax = plt.subplots(figsize=(10, 5), dpi=120)
m = f <= 200
ax.plot(f[m], S_hop[m] * 1000, color="#1f5fbf", lw=1.8, label=f"po z-hopie (0.1-0.7 s), srednia z {NREC} nagran")
ax.plot(fb[m], S_bg[m] * 1000, color="#999999", lw=1.2, label="tlo (koniec nagrania, stol stoi)")
pk = np.argmax(np.where((f > 5) & (f < 200), S_hop, 0))
ax.annotate(f"{f[pk]:.1f} Hz", (f[pk], S_hop[pk] * 1000), xytext=(f[pk] + 12, S_hop[pk] * 1000 * 0.95),
            arrowprops=dict(arrowstyle="-", color="#444"), fontsize=10)
ax.set_xlabel("czestotliwosc [Hz]  (rozdzielczosc ok. 1.7 Hz)")
ax.set_ylabel("amplituda [mg]")
ax.set_title("Voron - drgania stolu w osi Z po pojedynczym z-hopie 0.4 mm (LIS3DH na ramie stolu przy PP), 261116")
ax.grid(alpha=0.3); ax.legend(frameon=False)
ax.set_xlim(0, 200); ax.set_ylim(bottom=0)
fig.tight_layout(); fig.savefig(out)
top = sorted(((S_hop[i], f[i]) for i in range(1, len(f) - 1) if f[i] < 200 and S_hop[i] > S_hop[i - 1] and S_hop[i] > S_hop[i + 1]), reverse=True)[:5]
print("PODSUMOWANIE acc_spec: szczyty " + ", ".join(f"{fr:.1f} Hz {a * 1000:.1f} mg" for a, fr in top) + f"; wykres {os.path.abspath(out)}")
