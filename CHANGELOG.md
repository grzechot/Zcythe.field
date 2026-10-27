# Changelog

Dates are when a version went onto the author's printer. Summarised from the Polish work journal.

## 2026-10-26
- New Zcythe Stone (K1 v2, long lever): `hescal2_m.g` `kThr` 1.0103 → 0.972 mm; `hes_refdata.g` = new R1 reference.

## 2026-10-22 – 2026-10-24 – PrintInit (operator messages)
- `start.g`: **10 stages** `[1/10]…[10/10]` in a loop, a stage that is already done is skipped with one line,
  `-- PRINT INIT DONE  n min --` at the end. New: stage 6 *Leveling check* on the warm bed.
- Every error during the start is a pause with a window (cause, *Check: …*, buttons named after the action),
  never a cancel. Step-back buttons `< Probe`, `< Home`, `< Level`, `< Warm`, `< Clean`, `< Calib` return to the
  stage the problem comes from. Button labels ≤ 8 characters (PanelDue has fixed 125 px buttons).
- Wait timers: `op_wait.g` + `daemon.g`, times in `printinit_cfg.g` – reminder every 5 min, heaters off after
  30 min, motors off 30 min later; heating and bed warm-up resume when the operator answers.
- `endstop_test.g`, `probe_test.g`: *Test* buttons – manual signal test, no motion.
- `msg.g`: `D` = DWC-only line; no " >DWC" marker. Mesh table and HesCal2 service values in DWC only.
- `bedsoak.g`: progress every 60 s, window *Wait / Skip* (a small print may skip the soak), window
  *Bed does not reach … C* after 20 min.
- `deployprobe0.g`: window `S0 T60` (RRF 3.6 rejects `S0 T0`); K0 closing during a measurement is counted.
- New `mesh_ask.g`, `fmt3s.g`, macro `Legend`. Docs: [docs/printinit.md](docs/printinit.md).
- Measuring algorithms (homing, G32, HesCal2, Mesh) unchanged.

## 2026-10-19
- `hes_manual.g` (new) + `hescal2_m.g` v5: every K0 dive that misses K1 opens a *Manual / Stop* window; the operator
  jogs K0 over the K1 ball (±5 / ±0.5 mm buttons, Z window) and the step restarts from there, in a loop.
- `bed.g`: first pass from 15 mm (`M558 H15:3`) – copes with a gantry skewed ~14 mm after power-off.
- `k0g30.g`: when K0 is already triggered (pressed into the bed), lift Z up to 3 × 5 mm before asking the operator.
- `config.g`: `M569 P5..P8 … T5:5:10:10` – step timing for the external A4988 Z drivers.
- Tools: `zdrop.py`, `zwatch.py`, `adir.py`, `prof.py`.

## 2026-10-17
- HesCal2 during a print no longer cancels on failure: window *HESCAL2: ERROR* – Repeat / Use last good / Cancel.
  `hes_h.g` returns `hSt 9` instead of `abort` when the probe is blocked during a print.
- Tools: `bedstab.py`, `xdir.py`, `zstep.py`; `voron_api.get` retries on HTTP 503.

## 2026-10-16
- Console: PanelDue = DWC (`msg.g`), English, ≤ 40 characters, max 4 decimals, step summaries ≤ 8 lines.
- Homing v2: every axis checked (endstop reached/released), check B (XY endstop repeatability), check C (Z zero
  shift, `home_zshift.g`), error windows with retry (`home_do.g`), summary (`home_sum.g`).
- K0 probing everywhere as in homing: coarse 120 mm/min from 5 mm, fine 80 mm/min from 3 mm, up to 5 dives,
  pair within 0.01 (G32, HesCal2, Mesh).
- `tolerances.g` + `tol_ask.g` / `tol_save.g` / `tol_check.g`: all tolerances in one file, changeable from windows.
- HesCal2 split into a wrapper (`macros/HesCal2`) and the measurement (`sys/hescal2_m.g`); window
  *G31 REJECTED* – Use measured / Repeat / Change tol.
- `bed.g` / `bed_pass.g`: passes until deviation ≤ `tolBed`, window when not converged.
- Mesh: check point measured with the map **off** against the map value (`tolCheck` 0.03).

## 2026-10-15
- `fmt4.g` (numbers with 4 decimals). HesCal3 experiment (bed reference in a corner) – not adopted.

## 2026-10-13
- HesCal2: "from the tip" becomes the main G31 method; nozzle floor from the expected K1 trigger
  (`floorMargin` 0.30); fallback to `lastGoodG31` instead of the `config.g` value.
- Mesh 7 × 7 + extrapolated 8th row (`heightmap_ext.csv`), because K0 reaches only Y370.

## 2026-10-12
- `daemon.g` + `bedsoak.g`: bed soak counted from the moment the bed reaches its target (thermal test).

## 2026-10-07 – 2026-10-09
- HesCal2 (new algorithm for a ball-top K1): bed dive, K0 cross of 5 dives with apex from the curvature,
  nozzle dives at apex + offset; `HesTip` characterisation (R ≈ 7.5 mm); K0→nozzle offset measured
  (X −12.365, Y −39.593); K1 permanently defined as probe 1.

## 2026-09-25 – 2026-10-06
- First version (`HesCal`): K0 on bed, K0 on the K1 tip with adaptive dives and climbing, nozzle profile;
  `start.g` with resumable steps, `wipe`, `prime`, `pause`/`resume`, `cancel.g`.
