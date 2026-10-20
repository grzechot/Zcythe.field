"""zspeed.py - K0 trigger height vs probing speed (Voron). Moves the machine - run only with the operator's consent.

One G28 at the start, then only G30 S-1 (Z zero never changes -> all heights in one frame).
Per speed (highest first): M558 K0 F<v> A1 (single dive, fixed dive height), N dives at one K0 point.
At the end the probe settings from config.g are restored and G31 is checked unchanged.
Usage: python zspeed.py [--x 200 --y 200 --n 5 --speeds 240,180,120,100,80,60,30 --dive 3]
Output: data/zspeed_YYYYMMDD_HHMM.csv, log in data/logs, last line PODSUMOWANIE.
"""
import argparse, csv, os, re, statistics as st, time
import voron_api as v

RESTORE = 'M558 K0 H5:3 F120:80 T18000 A5 S0.01 R0.3'   # = config.g line 91 without P/C

ap = argparse.ArgumentParser()
ap.add_argument('--x', type=float, default=200)
ap.add_argument('--y', type=float, default=200)
ap.add_argument('--n', type=int, default=5)
ap.add_argument('--speeds', default='240,180,120,100,80,60,30')
ap.add_argument('--dive', type=float, default=3)
ap.add_argument('--a', type=int, default=5)
ap.add_argument('--h', default=None, help='M558 H value, e.g. 3:0.5 (default = --dive)')
a = ap.parse_args()
speeds = a.speeds.split(',')   # '60' = single dive A1; '240:60' = fast + fine dives, A{--a} (RRF averages / drops outlier)

v.set_log('zspeed')
v.log('START ' + v.state())
if v.status() != 'idle':
    v.log('STOP: status != idle'); raise SystemExit(1)


def run(code, max_s=300):
    ok, r = v.run(code, max_s)
    if not ok:
        v.log(f'BLAD: {code} -> {r}')
        raise SystemExit(1)
    return r


def echo(expr):
    r = run('echo ' + expr, 30)
    for _ in range(6):                              # reply sometimes arrives late / empty
        n = re.findall(r'-?\d+\.?\d*', r)
        if n:
            return float(n[-1])
        time.sleep(0.5)
        r = v.get('/rr_reply').strip()
    raise RuntimeError('echo: no reply for ' + expr)


def zpos():
    return v.m('move.axes')[2]['userPosition']


def send_wait(code, done, max_s=60):
    """Send G-code, then wait until done(z) holds, machine idle and Z stable (replies are not used)."""
    v.get('/rr_reply')
    v.get('/rr_gcode?gcode=' + v.urllib.parse.quote(code))
    t0 = time.time(); last = None; stable = 0
    while time.time() - t0 < max_s:
        time.sleep(0.3)
        z = zpos(); st_ = v.m('state')['status']
        rep = v.get('/rr_reply').strip()
        if 'rror' in rep:
            v.log(f'BLAD: {code} -> {rep}'); raise SystemExit(1)
        stable = stable + 1 if (last is not None and abs(z - last) < 1e-4) else 0
        last = z
        if st_ == 'idle' and done(z) and stable >= 2:
            return z
    v.log(f'BLAD: {code} - timeout, Z {last}'); raise SystemExit(1)


rows = []
try:
    run('G29 S2')
    run('G28')
    g31 = echo('sensors.probes[0].triggerHeight')
    ox, oy = echo('sensors.probes[0].offsets[0]'), echo('sensors.probes[0].offsets[1]')
    nx, ny = a.x - ox, a.y - oy                      # nozzle position for K0 at (x, y)
    run(f'G1 Z{a.dive + 2:.2f} F600')
    run(f'G1 X{nx:.3f} Y{ny:.3f} F12000')
    h = v.m('heat.heaters')
    v.log(f'G31 {g31}  K0 X{a.x} Y{a.y} (nozzle X{nx:.3f} Y{ny:.3f})  bed {h[0]["current"]}  hot {h[1]["current"]}')
    for spd in speeds:
        run(f'M558 K0 H{a.h or a.dive} F{spd} A{a.a if ":" in spd else 1} S0.01')
        for i in range(1, a.n + 1):
            zs0 = g31 + a.dive
            send_wait(f'G1 Z{zs0:.3f} F600', lambda z: abs(z - zs0) < 0.002)   # same start height every dive
            t = time.strftime('%T')
            zu = send_wait('G30 S-1', lambda z: z < zs0 - 0.5, 120)            # head stays at the trigger point
            z = v.m('sensors.probes')[0]['lastStopHeight']
            rows.append([spd, i, t, z, round(z - g31, 5), zu])
            v.log(f'F{spd} #{i}: {z:.5f}  (vs G31 {z - g31:+.5f})  userZ {zu}')
finally:
    run(f'G1 Z{a.dive + 2:.2f} F600')
    run(RESTORE)
    g31b = echo('sensors.probes[0].triggerHeight')
    v.log(f'restore: {RESTORE}; G31 {g31b}')

f = os.path.join(v.DATA, f'zspeed_{time.strftime("%Y%m%d_%H%M")}.csv')
with open(f, 'w', newline='') as fh:
    csv.writer(fh).writerows([['F_mm_min', 'n', 'czas', 'lastStopHeight', 'minus_G31', 'userPosZ']] + rows)
summ = []
for spd in speeds:
    zs = [r[3] for r in rows if r[0] == spd]
    if zs and spd not in [x.split()[0][1:] for x in summ]:
        summ.append(f'F{spd}: sr {st.mean(zs):.4f} rozstep {max(zs) - min(zs):.4f} sd {st.pstdev(zs):.4f}')
v.log('PODSUMOWANIE: ' + ' | '.join(summ) + f' | CSV {f}')
