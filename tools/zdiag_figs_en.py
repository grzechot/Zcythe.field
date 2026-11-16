"""zdiag_figs_en.py - English figures for the GitHub doc 'Z drive diagnostics' (261116). Files only, no printer.
python zdiag_figs_en.py OUTDIR"""
import csv, glob, math, os, re, statistics as st, sys
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

T = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(T, "..", "data")
OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
RATE = 1344.0


def load(p):
    z = [float(l.split(",")[3]) for l in open(p) if l[:1].isdigit() and l.count(",") >= 3]
    z = np.array(z[4:])
    return z - np.median(z[len(z) // 2:]) if len(z) > 1000 else None


def starts(a):
    i, r = 0, []
    while i < len(a):
        if abs(a[i]) > 0.1:
            r.append(i); i += int(0.5 * RATE); continue
        i += 1
    return r


def spec(seg):
    w = np.hanning(len(seg))
    return np.fft.rfftfreq(len(seg), 1 / RATE), np.abs(np.fft.rfft(seg * w)) * 2 / w.sum()


# 1. spectrum after a single z-hop
zh = os.path.join(DATA, "acc", "zh_261116_1415")
SH, SB = [], []
for p in sorted(glob.glob(os.path.join(zh, "261116_*.csv"))):
    a = load(p)
    if a is None:
        continue
    f, s = spec(a[int(.1 * RATE):int(.7 * RATE)]); SH.append(s)
    _, b = spec(a[-int(.6 * RATE):]); SB.append(b)
SH, SB = np.mean(SH, 0) * 1000, np.mean(SB, 0) * 1000
fig, ax = plt.subplots(figsize=(10, 4.6), dpi=120)
m = f <= 200
ax.plot(f[m], SH[m], color="#1f5fbf", lw=1.8, label=f"0.1-0.7 s after a 0.4 mm z-hop (mean of {len(SB)} recordings)")
ax.plot(f[m], SB[m], color="#999", lw=1.2, label="background, bed at rest")
for fr, txt in ((16.7, "16.7 Hz bed mode"), (30, "30"), (36.7, "36.7"), (96.7, "97 Hz fan / idle motors\n(also at rest)")):
    i = np.argmin(abs(f - fr)); ax.annotate(txt, (f[i], SH[i]), xytext=(f[i] + 4, SH[i] + 1.5), fontsize=9)
ax.set_xlabel("frequency [Hz]"); ax.set_ylabel("amplitude [mg]"); ax.set_xlim(0, 200); ax.set_ylim(bottom=0)
ax.set_title("Bed vibration in Z after a single z-hop (LIS3DH on the bed frame)")
ax.grid(alpha=.3); ax.legend(frameon=False)
fig.tight_layout(); fig.savefig(os.path.join(OUT, "z_spectrum.png")); plt.close(fig)

# 2. 16.7 Hz residual vs z-hop duration (measured + model)
zr = os.path.join(DATA, "acc", "zr_261116_1441", "zres_pasma.csv")
R = list(csv.DictReader(open(zr)))
g = {}
for r in R:
    g.setdefault(r["tag"], []).append(r)
pts = sorted((float(rs[0]["T"]), st.mean(float(x["f16.7"]) for x in rs) * 1000, st.mean(float(x["f30"]) for x in rs) * 1000,
              st.mean(float(x["f36.7"]) for x in rs) * 1000) for t, rs in g.items() if t.startswith("t1"))
fig, ax = plt.subplots(figsize=(10, 4.8), dpi=120)
ax.plot([p[0] for p in pts], [p[1] for p in pts], "o-", color="#1f5fbf", lw=2, label="16.7 Hz, measured")
ax.plot([p[0] for p in pts], [p[2] for p in pts], "o-", color="#d0731f", lw=1.2, ms=4, label="30 Hz, measured")
ax.plot([p[0] for p in pts], [p[3] for p in pts], "o-", color="#3a8f3a", lw=1.2, ms=4, label="36.7 Hz, measured")
w = 2 * math.pi * 16.7; tt = np.linspace(20, 52, 300) / 1000; u = w * tt / 2
mod = np.abs(np.sin(u) ** 3 * np.cos(u)) / (w * tt) ** 2
mod = mod / mod[np.argmin(abs(tt - 0.022))] * pts[0][1]
ax.plot(tt * 4000, mod, color="#999", lw=1.2, ls="--", label="model, single 16.7 Hz mode")
for tag, mk, lab in (("ref_A1000", "s", "A1000 V13.2 (87 ms)"), ("ref_A2000", "^", "A2000 V13.2 (74 ms)")):
    rs = g[tag]; ax.plot(float(rs[0]["T"]), st.mean(float(x["f16.7"]) for x in rs) * 1000, mk, color="#b23030", ms=9, mfc="none", label=f"16.7 Hz, old profile {lab}")
ax.set_xlabel("z-hop duration, 0.4 mm up + down [ms]  (triangular profile, one acceleration, jerk 20 mm/min)")
ax.set_ylabel("residual after landing [mg]")
ax.set_title("Ringing after landing vs z-hop duration: minimum at 2 periods of the bed mode")
ax.grid(alpha=.3); ax.legend(frameon=False, fontsize=9); ax.set_ylim(bottom=0)
fig.tight_layout(); fig.savefig(os.path.join(OUT, "z_residual_vs_hop.png")); plt.close(fig)

# 3. time traces
rec = {}
for p in glob.glob(os.path.join(DATA, "acc", "zr_261116_1441", "261116_1428_*.csv")):
    m_ = re.match(r"\d+_\d+_\d+_(.*)\.csv", os.path.basename(p)); rec[m_.group(1)] = load(p)
fig, axs = plt.subplots(2, 1, figsize=(10, 5.6), dpi=120, sharex=True, sharey=True)
for ax, t, c, lab in zip(axs, ["ref_A1000", "t1_29.4"], ["#d0731f", "#1f5fbf"],
                         ["old profile: A1000, V13.2 mm/s - z-hop 87 ms", "matched profile: A463 - z-hop 118 ms"]):
    a = rec[t]; s0 = starts(a)[0]; x = (np.arange(len(a)) - s0) / RATE * 1000
    ax.plot(x, a * 1000, color=c, lw=.8); ax.set_title(lab, fontsize=10, loc="left"); ax.grid(alpha=.3)
axs[1].set_xlabel("time from the first z-hop [ms]  (3 z-hops 0.4 mm, 550 ms apart)")
for ax in axs:
    ax.set_ylabel("accel. Z [mg]")
axs[0].set_xlim(-100, 1900); axs[0].set_ylim(-450, 450)
fig.suptitle("Bed acceleration during z-hops")
fig.tight_layout(); fig.savefig(os.path.join(OUT, "z_traces.png")); plt.close(fig)

# 4. K0 control after each 50-hop series
Z = [r for r in csv.DictReader(open(os.path.join(DATA, "zhop4_261116_1428.csv"), encoding="utf-8")) if r["etap"] == "7"]
fig, ax = plt.subplots(figsize=(10, 4), dpi=120)
x = np.arange(len(Z))
for k, c, lab in zip(("dLP", "dLT", "dPT", "dPP"), ("#bbb", "#8a5cc2", "#3a8f3a", "#b23030"), ("front-left", "rear-left", "rear-right", "front-right")):
    ax.plot(x, [float(r[k]) for r in Z], "o-", color=c, ms=4, lw=1, label=lab)
ax.axhspan(-0.03, 0.03, color="#eee", zorder=0)
ax.set_xticks(x); ax.set_xticklabels([r["proba"].replace("t1 ", "t1=").replace("ref ", "") for r in Z], rotation=40, fontsize=8)
ax.set_ylabel("corner height change [mm]"); ax.set_title("Zcythe (K0) at the 4 leadscrews after every 50 z-hops - step loss threshold 0.03 mm (grey)")
ax.grid(alpha=.3); ax.legend(frameon=False, ncol=4, fontsize=8)
fig.tight_layout(); fig.savefig(os.path.join(OUT, "z_k0_check.png")); plt.close(fig)
print("PODSUMOWANIE zdiag_figs_en: 4 PNG -> " + os.path.abspath(OUT))
