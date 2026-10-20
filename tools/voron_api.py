"""Wspolne funkcje HTTP (API rr_*) dla Vorona (Duet 2 WiFi, RRF 3.6.1). Bez hasla.
Uzywane przez r1run.py, k1meas.py, fetch_logs.py, pclog.py, watch_start.py.
Kazda komenda (run) czeka, az kanal HTTP bedzie bezczynny; wszystko idzie do logu z data i godzina."""
import json, os, time, urllib.parse, urllib.request

H = "http://" + os.environ.get("PRINTER_HOST", os.environ.get("VORON_IP", "printer.local"))   # set PRINTER_HOST=<IP or hostname of your Duet>
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))   # repository root
DATA = os.path.join(ROOT, "data")
LOGDIR = os.path.join(DATA, "logs")
LOG = None   # ustawia set_log()

# kolumny 0:/sys/hes_hist.csv
HIST_COLS = ["czas", "zBed", "x0", "y0", "zK0v", "k1Stol", "xHE", "yHE", "zHEv", "dzK0HE", "offX", "offY", "G31Z", "wynik"]


def set_log(name):
    global LOG
    os.makedirs(LOGDIR, exist_ok=True)
    LOG = os.path.join(LOGDIR, f"{name}_{time.strftime('%Y%m%d_%H%M')}.log")
    return LOG


def get(p, timeout=10):
    # Duet przy przeciazeniu serwera HTTP zwraca 503 - ponow kilka razy zamiast przerywac skrypt (17.10)
    for i in range(6):
        try:
            return urllib.request.urlopen(H + p, timeout=timeout).read().decode("utf-8", "replace")
        except urllib.error.HTTPError as e:
            if e.code != 503 or i == 5:
                raise
            time.sleep(1 + i)


def m(k):
    return json.loads(get(f"/rr_model?key={k}&flags=d99v"))["result"]


def log(s):
    line = f"{time.strftime('%F %T')} {s}"
    print(line, flush=True)
    if LOG:
        with open(LOG, "a", encoding="utf-8") as f:
            f.write(line + "\n")


def connect():
    log(f"connect: {get('/rr_connect?password=')}")


def disconnect():
    try:
        get("/rr_disconnect")
    except Exception:
        pass


def status():
    return m("state")["status"]


def homed():
    return all(a["homed"] for a in m("move.axes")[:3])


def http_busy():
    x = [i for i in m("inputs") if i and i.get("name") == "HTTP"][0]
    return x["stackDepth"] > 0 or x["state"] != "idle"


def state():
    s = m("state"); h = m("heat.heaters"); p = m("sensors.probes")[0]; ax = m("move.axes")
    g = m("global")
    return (f"status={s['status']} msg={s.get('displayMessage')!r} box={'TAK' if s.get('messageBox') else '-'} "
            f"homed={[a['homed'] for a in ax[:3]]} bed={h[0]['current']}/{h[0]['active']} "
            f"hot={h[1]['current']}/{h[1]['active']}/{h[1]['standby']} K0={p['value'][0]} G31={p['triggerHeight']} "
            f"comp={m('move.compensation')['type']} levelDone={g.get('levelDone')} skipCal={g.get('skipCal')} "
            f"lastGoodG31={g.get('lastGoodG31')}")


def run(code, max_s=600):
    """Wysyla G-code, czeka na koniec (kanal HTTP bezczynny). Zwraca (ok, odpowiedz)."""
    get("/rr_reply")
    r = get("/rr_gcode?gcode=" + urllib.parse.quote(code)).strip()
    log(f"WYSLANO: {code}  ({r})")
    t0 = time.time(); box_seen = False; out = []
    time.sleep(1.0)
    while time.time() - t0 < max_s:
        rep = get("/rr_reply").strip()
        if rep:
            out.append(rep)
        s = m("state")
        if s.get("messageBox") and not box_seen:
            box_seen = True
            log(f"  OKNO NA PANELU: {s['messageBox'].get('title')!r} {s['messageBox'].get('message')!r} - czekam na uzytkownika")
        if not http_busy():
            rep = get("/rr_reply").strip()
            if rep:
                out.append(rep)
            break
        time.sleep(2)
    else:
        log(f"  LIMIT CZASU {max_s} s - kanal HTTP nadal zajety")
        return False, "\n".join(out)
    txt = "\n".join(out)
    log(f"  koniec po {time.time() - t0:.0f} s; odpowiedz: {txt[:400]!r}")
    bad = any(w in txt.lower() for w in ("error", "abort", "przerwane"))
    return not bad, txt


def download(name):
    """rr_download zawsze zwraca caly plik (Range ignorowany)."""
    return get("/rr_download?name=" + urllib.parse.quote(name), timeout=60)


def hist_rows():
    return download("0:/sys/hes_hist.csv").strip().splitlines()


def parse_hist(line):
    f = line.split(",")
    d = dict(zip(HIST_COLS, f))
    for k in HIST_COLS[1:-1]:
        try:
            d[k] = float(d[k])
        except (KeyError, ValueError):
            pass
    if isinstance(d.get("zHEv"), float) and isinstance(d.get("zBed"), float):
        d["zapas"] = d["zHEv"] - d["zBed"]   # zapas K1 nad K0
    return d


def frac(x):
    """Obrot sruby jako ulamek: 1/6, 1/4, 1/3, 1/2, 2/3, 3/4, 5/6, 1 i 1/3 ..."""
    from fractions import Fraction
    cands = sorted({Fraction(n, d) for d in (2, 3, 4, 6) for n in range(0, 3 * d + 1)})
    best = min(cands, key=lambda c: abs(float(c) - abs(x)))
    whole, rest = divmod(best, 1)
    if best == 0:
        return "0"
    if rest == 0:
        return f"{whole}"
    return f"{rest.numerator}/{rest.denominator}" if whole == 0 else f"{whole} i {rest.numerator}/{rest.denominator}"
