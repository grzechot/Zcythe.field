"""zres_plots.py - szczegolowa analiza nagran etapu res (261116): przebiegi, pasma, szczyty, powtarzalnosc.
Uzycie: python zres_plots.py KATALOG_zr [CSV_zhop4]   (tylko pliki z dysku)
Wynik: PNG w KATALOG_zr (zres_1_przebiegi, zres_2_pasma, zres_3_szczyt, zres_4_cykl), tabele na stdout, zres_pasma.csv."""
import csv, glob, math, os, re, sys
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

RATE = 1344.0
D = sys.argv[1]
ZCSV = sys.argv[2] if len(sys.argv) > 2 else None
BANDS = {"11.7": (10, 13.5), "16.7": (15, 19), "30": (27.5, 32.5), "36.7": (34, 39.5), "45": (42, 48), "97 (tlo)": (93, 100)}


def load(p):
    z = [float(l.split(",")[3]) for l in open(p) if l[:1].isdigit() and l.count(",") >= 3]
    z = np.array(z[4:])
    return z - np.median(z[len(z) // 2:])


def starts(a):
    i, r = 0, []
    while i < len(a):
        if abs(a[i]) > 0.1:
            r.append(i); i += int(0.5 * RATE); continue
        i += 1
    return r


def band(w, lo, hi):
    S = np.abs(np.fft.rfft(w * np.hanning(len(w)))) * 4 / len(w)
    f = np.fft.rfftfreq(len(w), 1 / RATE)
    return float(S[(f >= lo) & (f <= hi)].max())


def tinfo(tag):
    if tag.startswith("ref"):
        A = float(tag[5:]); v = 13.2; s = 0.4
        # trapez: 2 kierunki x (s/v + v/A)
        return A, 2 * 1000 * (s / v + v / A)
    t1 = float(tag[3:]); return 0.4 / (t1 / 1000) ** 2, 4 * t1


rec = {}
for p in sorted(glob.glob(os.path.join(D, "*.csv"))):
    m = re.match(r"\d+_\d+_\d+_(.*)\.csv", os.path.basename(p))
    if not m or os.path.basename(p).startswith("zres"):
        continue
    rec[m.group(1)] = load(p)
tags = sorted(rec, key=lambda t: tinfo(t)[1])

# --- 1. przebiegi
fig, axs = plt.subplots(3, 1, figsize=(11, 8), dpi=110, sharex=True, sharey=True)
for ax, t, c in zip(axs, ["ref_A1000", "t1_29.4", "t1_37"], ["#d0731f", "#1f5fbf", "#3a8f3a"]):
    a = rec[t]; s0 = starts(a)[0]; x = (np.arange(len(a)) - s0) / RATE * 1000
    ax.plot(x, a * 1000, color=c, lw=0.8)
    A, T = tinfo(t)
    ax.set_title(f"{t.replace('_', ' ')}: A{A:.0f}, z-hop {T:.0f} ms", fontsize=10, loc="left")
    ax.axhspan(-20, 20, color="#eee", zorder=0)
    ax.grid(alpha=.3)
axs[1].set_ylabel("przyspieszenie Z [mg] (grawitacja odjeta)")
axs[-1].set_xlabel("czas od startu 1. z-hopu [ms]  (3 z-hopy, przerwa 550 ms; szare pasmo = +-20 mg ~ tlo)")
axs[0].set_xlim(-100, 2000); axs[0].set_ylim(-450, 450)
fig.suptitle("Voron - przebieg drgan stolu: obecny profil vs minimum (t1 29.4) vs t1 37, 261116 14:29")
fig.tight_layout(); fig.savefig(os.path.join(D, "zres_1_przebiegi.png"))

# --- 2. pasma (srednia z z-hopow, okno 150-450 ms po starcie) + szczyt + powtarzalnosc
rows = []
for t in tags:
    a = rec[t]
    for k, s0 in enumerate(starts(a)):
        w = a[s0 + int(.15 * RATE): s0 + int(.45 * RATE)]
        if len(w) < int(.25 * RATE):
            continue
        A, T = tinfo(t)
        r = dict(tag=t, hop=k + 1, A=round(A), T=round(T, 1), pk=float(np.abs(a[s0:s0 + int(.15 * RATE)]).max()),
                 rms=float(np.sqrt(np.mean(w ** 2))))
        r.update({f"f{b}": band(w, *BANDS[b]) for b in BANDS})
        rows.append(r)
with open(os.path.join(D, "zres_pasma.csv"), "w", newline="") as f:
    wr = csv.DictWriter(f, fieldnames=list(rows[0])); wr.writeheader(); wr.writerows(rows)

agg = {}
for r in rows:
    agg.setdefault(r["tag"], []).append(r)
print("TABELA 2: amplituda pasm [mg] po ladowaniu (150-450 ms), srednia z z-hopow")
print(f"{'punkt':<11}{'A':>6}{'T ms':>7}{'n':>3}" + "".join(f"{b:>10}" for b in BANDS) + f"{'rms':>7}")
for t in tags:
    rs = agg.get(t, [])
    if not rs:
        continue
    print(f"{t:<11}{rs[0]['A']:>6}{rs[0]['T']:>7.0f}{len(rs):>3}" + "".join(f"{1000 * np.mean([r['f' + b] for r in rs]):>10.1f}" for b in BANDS)
          + f"{1000 * np.mean([r['rms'] for r in rs]):>7.1f}")

fig, ax = plt.subplots(figsize=(11, 5.5), dpi=110)
cols = {"11.7": "#bbbbbb", "16.7": "#1f5fbf", "30": "#d0731f", "36.7": "#3a8f3a", "45": "#8a5cc2", "97 (tlo)": "#b23030"}
tt = [t for t in tags if t.startswith("t1")]
for b in BANDS:
    ax.plot([agg[t][0]["T"] for t in tt], [1000 * np.mean([r["f" + b] for r in agg[t]]) for t in tt], "o-",
            color=cols[b], lw=1.6 if b in ("16.7", "30", "36.7") else 1.0, ms=4, label=f"{b} Hz",
            ls="--" if "tlo" in b else "-")
    for t, mk in (("ref_A1000", "s"), ("ref_A2000", "^")):
        ax.plot(agg[t][0]["T"], 1000 * np.mean([r["f" + b] for r in agg[t]]), mk, color=cols[b], ms=8, mfc="none")
for f0, c in ((16.7, "#1f5fbf"), (30, "#d0731f"), (36.7, "#3a8f3a")):
    for k in (1, 2, 3):
        T = 2000 * k / f0          # zero modelu: t1 = k * pol okresu -> z-hop = 4 t1
        if 80 <= T <= 210:
            ax.axvline(T, color=c, alpha=.35, lw=1, ls=":")
ax.set_xlabel("czas z-hopu 0.4 mm [ms]   (kolka = profil trojkatny t1; kwadrat/trojkat = obecny A1000/A2000 V13.2)\n"
              "pionowe kropkowane = zera modelu dla danej czestotliwosci (t1 = k x pol okresu)")
ax.set_ylabel("amplituda pasma po ladowaniu [mg]")
ax.set_title("Voron - skladowe drgan po ladowaniu vs czas z-hopu, 261116 14:29")
ax.grid(alpha=.3); ax.legend(frameon=False, ncol=3, fontsize=9); ax.set_ylim(bottom=0)
fig.tight_layout(); fig.savefig(os.path.join(D, "zres_2_pasma.png"))

# --- 3. szczyt w trakcie z-hopu + powtarzalnosc (kazdy z-hop osobno)
fig, ax = plt.subplots(figsize=(11, 5), dpi=110)
for t in tags:
    for r in agg.get(t, []):
        c = "#d0731f" if t.startswith("ref") else "#1f5fbf"
        ax.plot(r["T"], 1000 * r["pk"], "o", color=c, mfc="none" if r["hop"] > 1 else c, ms=6)
        ax.plot(r["T"], 1000 * r["f16.7"], "s", color="#3a8f3a", mfc="none" if r["hop"] > 1 else "#3a8f3a", ms=5)
ax.plot([], [], "o", color="#1f5fbf", label="szczyt |a| w trakcie z-hopu (0-150 ms), profil t1")
ax.plot([], [], "o", color="#d0731f", label="szczyt, obecny profil A1000/A2000")
ax.plot([], [], "s", color="#3a8f3a", label="17 Hz po ladowaniu")
ax.plot([], [], "o", color="#777", mfc="none", label="pusty znak = 2. i 3. z-hop w nagraniu (pelny = 1.)")
ax.set_xlabel("czas z-hopu 0.4 mm [ms]"); ax.set_ylabel("[mg]")
ax.set_title("Voron - szczyt w trakcie z-hopu i rozrzut miedzy z-hopami, 261116 14:29")
ax.grid(alpha=.3); ax.legend(frameon=False, fontsize=9); ax.set_ylim(bottom=0)
fig.tight_layout(); fig.savefig(os.path.join(D, "zres_3_szczyt.png"))
print("\nTABELA 3: kazdy z-hop osobno [mg]: szczyt / 17 Hz")
for t in tags:
    print(f"{t:<11}" + "  ".join(f"#{r['hop']} {1000 * r['pk']:5.0f}/{1000 * r['f16.7']:4.1f}" for r in agg.get(t, [])))

# --- 4. czas cyklu vs model + K0
if ZCSV:
    Z = [r for r in csv.DictReader(open(ZCSV, encoding="utf-8")) if r["etap"] == "7"]
    print("\nTABELA 4: seria 50 z-hopow - czas cyklu i pomiar K0 (zmiana rogu po korekcie dryfu) [mm]")
    print(f"{'punkt':<11}{'A':>6}{'cykl ms':>9}{'model':>7}{'roznica':>9}{'LP':>8}{'LT':>8}{'PT':>8}{'PP':>8}{'max':>7}")
    for r in Z:
        print(f"{r['proba']:<11}{r['wartosc']:>6}{float(r['t_cyklu_ms']):>9.1f}{float(r['t_pol_ms']):>7.1f}"
              f"{float(r['t_cyklu_ms']) - float(r['t_pol_ms']):>+9.1f}" + "".join(f"{float(r[k]):>+8.3f}" for k in ("dLP", "dLT", "dPT", "dPP"))
              + f"{float(r['max']):>7.3f}")
    fig, (a1, a2) = plt.subplots(1, 2, figsize=(11, 4.5), dpi=110)
    tm = [float(r["t_pol_ms"]) for r in Z]; tc = [float(r["t_cyklu_ms"]) for r in Z]
    a1.plot(tm, tc, "o", color="#1f5fbf"); a1.plot([70, 210], [70, 210], color="#999", lw=1)
    a1.set_xlabel("model 'polaczone' [ms]"); a1.set_ylabel("zmierzony cykl [ms]"); a1.set_title("czas cyklu vs model", fontsize=10)
    a1.grid(alpha=.3)
    x = np.arange(len(Z))
    for k, c in zip(("dLP", "dLT", "dPT", "dPP"), ("#bbbbbb", "#8a5cc2", "#3a8f3a", "#b23030")):
        a2.plot(x, [float(r[k]) for r in Z], "o-", color=c, ms=4, lw=1, label=k[1:])
    a2.axhspan(-0.03, 0.03, color="#eee", zorder=0)
    a2.set_xticks(x); a2.set_xticklabels([r["proba"].replace("t1 ", "").replace("ref ", "") for r in Z], rotation=45, fontsize=8)
    a2.set_ylabel("zmiana rogu [mm] (szare = prog 0.03)"); a2.set_title("K0 po 50 z-hopach", fontsize=10)
    a2.grid(alpha=.3); a2.legend(frameon=False, ncol=4, fontsize=8)
    fig.suptitle("Voron - kontrola: czas cyklu i gubienie krokow, 261116 14:29")
    fig.tight_layout(); fig.savefig(os.path.join(D, "zres_4_cykl.png"))
print("PODSUMOWANIE zres_plots: 4 wykresy w " + os.path.abspath(D))
