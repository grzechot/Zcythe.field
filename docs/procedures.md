# Procedures

All procedures move the machine. Empty bed, K0 open, operator watching, hand on E-stop.
Read the printer state first – never upload or test while `state.status` is not `idle`.

## When to recalibrate what

| Change | Then |
|---|---|
| bed sheet / bed screws adjusted | K1 screw (margin), new `kThr`, new R1 |
| K1 screw or mount changed | K1 margin, new `kThr`, new R1 (if K1 moved in XY: `HesFind` or the Manual window) |
| nozzle changed / hotend work | HesCal2 (normal start); check the first layer, R1 if G31 is off |
| power-off, `M18` | nothing manual – `start.g` homes and levels (G32 from 15 mm) |

## K1 margin after a screw adjustment

Goal: `K1 margin` (`zHEv − zBed`) = `kMargin` ± `kMarginTol` (0.2 ± 0.15; the author aims at ~0.18).

1. Heat the hotend to standby (165 °C), home, G32.
2. `python tools/k1meas.py --n 4 --wipe-each --kthr <kThr> --ref-zapas <margin at which kThr was set> --obrot "<turn>"`
   – runs `wipe` + 4 × HesCal2 with G31 writing blocked (`lastGoodG31 = 99`), restores everything at the end,
   prints a table and a `PODSUMOWANIE` (summary) line.
3. Use the **first run after a wipe** (later runs read ~0.01 lower).
4. Out of target → turn the K1 screw (HesCal2 prints `K1 screw: tighten/loosen 1/3 turn`). Measured
   0.4–0.55 mm per turn; loosening raises K1. Repeat.

## New kThr

1. With the margin in target, print a first-layer test (e.g. 250 × 250 mm single layer, nominal 0.20).
2. Measure the layer with a micrometer at several points, or note the babystep that made it right
   (`M290 Z−x` = closer to the bed = larger true G31).
3. `G31_true = G31_used − babystep` (a babystep of −0.05 that fixed the layer means G31 was 0.05 too small);
   `kThr = G31_true + K1 margin` (same mechanical state).
4. Edit `var kThr` in `sys/hescal2_m.g`, upload, then R1.

## R1 – new reference

Saves the current geometry as the reference for the "from the tip" method.

1. `python tools/r1run.py S` – state only (status, homed, temperatures, `lastGoodG31`).
2. Back up `0:/sys/hes_refdata.g`.
3. `python tools/r1run.py A` – hotend 165 °C, K0 deploy (operator opens the needle), `k0offset.g`, G32.
   Continue only if the last G32 deviation ≤ 0.02.
4. `python tools/r1run.py B` – `hopZ` and dynamics as in `start.g`, `wipe`, `HesCal2 R1`, restore.
   Expected G31 on the author's printer ≈ 0.80–0.90; anything else – check before printing.

`hes_refdata.g` is loaded once per power cycle; R1 sets the `global.ref*` values and `lastGoodG31` directly.

## After a print

`python tools/fetch_logs.py` (read-only) downloads `hes_hist.csv`, `mesh_log.csv`, `cancel_log.csv` and shows
the last rows: G31 used, HesCal2 result (`OK2`, `OK2-STOL` = methods disagree, `KALIBRACJA2` = rejected),
mesh range and check. Compare with the first layer; adjust `manualZTrim` or `kThr` only with a measured reason.

## Accuracy rules of thumb

- Verify with a print, not a feeler gauge.
- An unexplained G31 change > 0.02–0.03 mm → stop and check mechanics before printing.
- Z drive problems (lost steps, a sagging gantry) show up as G32 needing many passes or large first corrections;
  `tools/zstep.py`, `zdrop.py`, `zwatch.py` help to diagnose them.
