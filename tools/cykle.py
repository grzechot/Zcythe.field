"""cykle.py - N start cycles on the Voron: G28, G32, wipe + HesCal2, Mesh. Moves the machine - only with the operator's consent.
Optional upload of a prepared folder first (diff against the firmware copy, stop on any difference).
Usage: python cykle.py [--n 10] [--upload <folder with prepared files>]
Output: data/cykle_YYYYMMDD_HHMM.csv (one row per cycle), log in data/logs, last line PODSUMOWANIE.
"""
import argparse, csv, os, re, statistics as st, time, urllib.error, urllib.parse, urllib.request
import voron_api as v

ap = argparse.ArgumentParser()
ap.add_argument('--n', type=int, default=10)
ap.add_argument('--upload', default=None)
a = ap.parse_args()
FW = os.path.join(v.ROOT, 'firmware')
TARGET = {'Mesh': 'macros', 'HesCal2': 'macros'}      # everything else -> sys

v.set_log('cykle')
v.log('START ' + v.state())
if v.status() != 'idle':
    v.log('STOP: status != idle'); raise SystemExit(1)

if a.upload:
    files = [f for f in sorted(os.listdir(a.upload)) if f.endswith('.g') or f in TARGET]
    bk = os.path.join(a.upload, 'przed_karta'); os.makedirs(bk, exist_ok=True)
    for n in files:
        card = f'0:/{TARGET.get(n, "sys")}/{n}'; fwp = os.path.join(FW, TARGET.get(n, 'sys'), n)
        try:
            c = v.download(card).encode()
        except urllib.error.HTTPError as e:
            if os.path.exists(fwp):
                v.log(f'STOP: {card} missing on card'); raise SystemExit(1)
            v.log(f'diff {card}: new ({e.code})'); continue
        if c != open(fwp, 'rb').read():
            open(os.path.join(bk, n + '_karta'), 'wb').write(c)
            v.log(f'STOP: {card} changed on card - copy saved, nothing uploaded'); raise SystemExit(1)
        open(os.path.join(bk, n), 'wb').write(c)
        v.log(f'diff {card}: card = firmware copy')
    for n in files:
        card = f'0:/{TARGET.get(n, "sys")}/{n}'
        data = open(os.path.join(a.upload, n), 'rb').read()
        v.get('/rr_connect?password=')
        req = urllib.request.Request(v.H + '/rr_upload?name=' + urllib.parse.quote(card), data=data, method='POST')
        r = urllib.request.urlopen(req, timeout=30).read().decode().strip()
        ok = v.download(card).encode() == data
        v.log(f'upload {card}: {r} {len(data)} B ok={ok}')
        if not ok:
            raise SystemExit(1)
        open(os.path.join(FW, TARGET.get(n, 'sys'), n), 'wb').write(data)


def step(code, max_s):
    t = time.time()
    ok, r = v.run(code, max_s)
    dt = time.time() - t
    if not ok:
        v.log(f'STEP FAILED: {code}\n{r}')
    return ok, r, dt


def num(pat, txt, default=''):
    m = re.findall(pat, txt)
    return m[-1] if m else default


ax = v.m('move.axes'); acc = (ax[0]['acceleration'], ax[1]['acceleration']); jerk = (ax[0]['jerk'], ax[1]['jerk'])
rows = []
fcsv = os.path.join(v.DATA, f'cykle_{time.strftime("%Y%m%d_%H%M")}.csv')
cols = ['n', 'start', 't_G28', 'B_X', 'B_Y', 'C_Zshift', 't_G32', 'G32_passes', 'G32_devs',
        't_HesCal', 'tipBed', 'dz', 'K1margin', 'G31_tip', 'G31_bed', 'hes_result', 'G31_after',
        't_Mesh', 'mesh_range', 'mesh_mean', 'mesh_check', 'console']
try:
    for k in range(1, a.n + 1):
        row = {'n': k, 'start': time.strftime('%T')}
        cons = []
        ok, r, dt = step('G28', 600); row['t_G28'] = round(dt); cons.append(r)
        g = v.m('global')
        row.update(B_X=g.get('homeChkX'), B_Y=g.get('homeChkY'), C_Zshift=g.get('homeZShift'))
        if not ok: rows.append(row); break
        ok, r, dt = step('G32', 900); row['t_G32'] = round(dt); cons.append(r)
        g = v.m('global'); row.update(G32_passes=g.get('bedPasses'), G32_devs=(g.get('bedDevs') or '').strip())
        if not ok: rows.append(row); break
        for c in ('set global.hopZ = max(1.5, sensors.probes[0].triggerHeight + 0.8)', 'M201 X2000 Y2000', 'M566 X300 Y300'):
            v.run(c, 10)
        ok, r, _ = step('M98 P"0:/macros/wipe"', 300)
        if not ok: rows.append(row); break
        ok, r, dt = step('M98 P"0:/macros/HesCal2"', 1800); row['t_HesCal'] = round(dt); cons.append(r)
        v.run('M201 X%s Y%s' % acc, 10); v.run('M566 X%s Y%s' % jerk, 10)
        h = v.parse_hist(v.hist_rows()[-1])
        row.update(tipBed=h.get('k1Stol'), dz=h.get('dzK0HE'), G31_tip=h.get('G31Z'), hes_result=h.get('wynik'),
                   K1margin=num(r'K1 margin: (-?[\d.]+)', r), G31_bed=num(r'bed: (-?[\d.]+)', r),
                   G31_after=v.m('sensors.probes')[0]['triggerHeight'])
        if not ok: rows.append(row); break
        v.run('set global.hopZ = max(1.5, sensors.probes[0].triggerHeight + 0.8)', 10)
        ok, r, dt = step('M98 P"0:/macros/Mesh"', 1800); row['t_Mesh'] = round(dt); cons.append(r)
        row.update(mesh_range=num(r'Range: (-?[\d.]+)', r), mesh_mean=num(r'mean: (-?[\d.]+)', r),
                   mesh_check=num(r'Check X\d+ Y\d+: (-?[\d.]+)', r))
        row['console'] = ' | '.join(x.replace('\n', ' / ') for x in cons)
        rows.append(row)
        v.log('CYCLE %d: %s' % (k, {c: row.get(c) for c in cols[:-1]}))
        if not ok: break
finally:
    v.run('M201 X%s Y%s' % acc, 10); v.run('M566 X%s Y%s' % jerk, 10)
    with open(fcsv, 'w', newline='', encoding='utf-8') as fh:
        w = csv.DictWriter(fh, fieldnames=cols); w.writeheader(); w.writerows(rows)


def rng(c):
    xs = [float(r[c]) for r in rows if r.get(c) not in (None, '', -999)]
    xs = [x for x in xs if x > -900]
    return f'{c} {min(xs):.4f}..{max(xs):.4f} (sd {st.pstdev(xs):.4f})' if xs else f'{c} -'


v.log('PODSUMOWANIE: cycles %d/%d | %s | CSV %s' % (len(rows), a.n, ' | '.join(
    rng(c) for c in ('B_X', 'B_Y', 'C_Zshift', 'tipBed', 'dz', 'G31_tip', 'G31_bed', 'G31_after', 'mesh_mean', 'mesh_range', 'mesh_check')), fcsv))
