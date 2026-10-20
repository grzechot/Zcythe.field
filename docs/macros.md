# Macros

Every file in `sys/` and `macros/`. "Core" = part of Zcythe Field; "printer" = the author's machine
configuration, kept because the core files call it or assume it.

## Start sequence and job events (`sys/`)

| File | Role |
|---|---|
| `start.g` | Core. Runs before every print: 1 heat, 2 open K0 + home (if needed) + bed soak + G32 (if needed), 3 wipe, 4 HesCal2 (unless `skipCal`), 5 Mesh (always), 6 prime. `M98 P"0:/sys/start.g" S<n>` resumes from step n. Sets `hopZ` (travel height after levelling = max(1.5, G31 + 0.8)) and gentle dynamics (M201 2000 / M566 300) for the sequence, restores them at the end. |
| `cancel.g` | Core. On cancel: logs the state to `cancel_log.csv`, returns filament owed by an interrupted calibration (`eOwed`), clears `skipCal` when axes are no longer homed. |
| `pause.g` / `resume.g` | Printer. Park at the wiper station (`wiperX`, `wiperY + parkYOffset`), retract `pauseRetract`; resume restores temperature, runs `wipe` + `prime`, returns to the print. |
| `daemon.g` | Core. Runs every ~10 s (RRF daemon). Only bookkeeping: records since when the bed is at its target (`bedInTargetSince`) for `bedsoak.g`. |
| `bedsoak.g` | Core. Bed soak before G32 and measurements: 8 min from reaching the target when cold, 3 min when it started within 5 °C, none when the bed has been at target long enough (data: thermal test 2026-10-12, PLA 55 °C – the bed dome settles in 2–9 min). |
| `sleep.g`, `stop.g` | Printer. Empty templates from the RRF configuration tool. |
| `config.g`, `config-override.g` | Printer. Reference only – see [installation](installation.md). |

## Homing (`sys/`)

| File | Role |
|---|---|
| `homeall.g` | Home X, Y, Z with checks; summary `-- HOMING DONE n s --`. Clears `levelDone` and `skipCal` (a new zero forces a new calibration). |
| `homex.g`, `homey.g`, `homez.g` | Single axis, same checks. |
| `home_do.g` | Homes an axis and repeats it on error: beep + full-screen window (OK = repeat axis, Cancel = stop; heaters stay on). |
| `home_xy.g` | One X/Y axis: coarse + fine approach, switch must release after back-off, check **B** – re-approach with `H4` without resetting the zero → endstop repeatability vs `tolXY`. |
| `home_z.g` | Z with K0 at the current XY (`G30`), check **C** via `home_zshift.g`. |
| `home_zshift.g` | Check C: one `G38.3` dive in the old Z frame → Z zero shift since the previous homing vs `tolZ`. |
| `home_sum.g` | Summary lines for both consoles (B, C, not-homed axes). |

## Bed levelling (`sys/`)

| File | Role |
|---|---|
| `bed.g` | G32: K0 at the 4 leadscrew points, at least 2 passes, more until the deviation before correction ≤ `tolBed` (max 6). First pass from 15 mm (`M558 H15:3`) to cope with a gantry skewed after power-off. Then Z0 again with K0 at X193 Y195. Gentle dynamics. Sets `levelDone` only after convergence; otherwise a window (OK = level again, Cancel = stop). |
| `bed_pass.g` | One pass: 4 × `k0g30.g`, motor correction (`S4`), deviation added to `bedDevs`. |
| `k0g30.g` | One `G30` with K0, protected: opens K0 first, repeats the point up to 6×, lifts Z (≤ 3 × 5 mm) when K0 is already pressed against the bed, then asks the operator. |
| `deployprobe0.g` | K0 manual deploy: returns at once when open; otherwise window + beep every 5 s, console line every 30 s, until the operator opens the needle. |
| `retractprobe0.g` | Template, does nothing (K0 closes by itself). |

## Calibration – HesCal2

| File | Role |
|---|---|
| `macros/HesCal2` | Wrapper. `M98 P"0:/macros/HesCal2" [O1] [A1] [R1]`. Runs `hescal2_m.g` and repeats it when the operator chooses *Repeat*. `O1` = also measure the K0→nozzle XY offset (writes `k0offset.g`), `A1` = accept an XY change > 0.5 mm, `R1` = save as new reference. |
| `sys/hescal2_m.g` | The measurement and **all its parameters** (`kThr`, `kMargin`, `dK`, `agree`, `floorMargin`, `calRetract` …). Three dives (bed, K0 on K1, nozzle on K1), G31 computation, gates, windows, history `hes_hist.csv`, `hes_last.g`, optional `hes_refdata.g` (R1) and `k0offset.g` (O1). See [how it works](how-it-works.md). |
| `sys/hes_h.g` | One dive of probe K (0 or 1) at X/Y from Z = S down to L, slow; result `global.hSt` (0 triggered, 1 not triggered, 2 already triggered at S, 9 blocked during a print), `global.hZ`; row in `hes_h.csv`. Respects `hesFloor` (nozzle never below) and `hesK0Clear`. |
| `sys/hes_vdive.g` | N vertical `G38.3` dives (coarse bed find, 120 mm/min); result `vdZ`, `vdR`, `vdOk`. |
| `sys/hes_manual.g` | When K0 misses K1: window *Manual / Stop*, then X/Y jog buttons (±5, ±0.5 mm, laid out 4 × 2 + Done for PanelDue) and a Z window; result `hesManOk`, `hesManX/Y` = new start point. |
| `sys/hes_log.g` | One console line for the Hes* macros (via `msg.g`). |
| `sys/hes_refdata.g` | Data: R1 reference (`refK0X/Y`, `refHEX/Y`, `refTipBed`, `refK0v`, `refHEv`, `refG31Z`). Written by `HesCal2 R1`. |
| `sys/hes_last.g` | Data: last K1 apex positions for K0 and nozzle (`lastK0X/Y`, `lastHEX/Y`) – start point of the next run. |
| `macros/HesFind` | Finds the K1 apex with K0 by scan lines along X (when K1 was moved or HesCal2 cannot find it). Results to console, `hes_find.csv`, `global.findX/Y/Z/findBed`. |
| `macros/HesTip` | Data collection only: cross profiles of K0 and nozzle over K1 and repeatability → `hes_tip_char.csv`, used to fit the effective radius R (≈ 7.5 mm) offline. Writes nothing to G31. |

## Mesh

| File | Role |
|---|---|
| `macros/Mesh` | Fresh 7 × 7 map in probe coordinates (X 5–395 step 65, Y 10–364 step 59) plus an extrapolated 8th row (Y423 = row 7 + `row7Delta`), because K0 reaches only Y370 while the nozzle prints to Y400. Up to 5 `G38.3` dives per point at 80 mm/min until two agree within 0.01. Writes `heightmap_ext.csv`, loads it (`G29 S1`), then re-measures the highest point with the map off vs the map (`tolCheck`) → window *Continue / Repeat / Change tol* when out. `T1` = dry run. |
| `sys/mesh.g` | Called by plain `G29`: gentler dynamics (K0 false-triggers from shocks). Not used by `start.g`. |

## Console and tolerances

| File | Role |
|---|---|
| `msg.g` | One console line to PanelDue (`M118 P2`) **and** DWC (`M118 P3`). See [console](console.md). |
| `fmt4.g` / `fmt3.g` | Number → text with 4 / 3 decimals in `global.fmt` (RRF prints e.g. 0.6249998). |
| `tolerances.g` | All tolerances in one place, each with a range {recommended min, max, allowed min, max}. Loaded by every macro that uses them. |
| `tol_ask.g` | Number window to change a tolerance (allowed range enforced, outside recommended → confirmation). |
| `tol_save.g` | Rewrites `tolerances.g` after *Change tol*. |
| `tol_check.g` | Console warning for tolerances outside their recommended range (printed only when the set changes). |

## Nozzle cleaning and start helpers (`macros/`)

| File | Role |
|---|---|
| `wipe` | Temperature check (heats to standby ≥ 165 °C if needed), 2 mm retract, zig-zag over the physical wiper. **Defines** `wiperX`, `wiperY`, `parkYOffset` – edit them here. |
| `prime` | Reload + purge + brush pass, no return to park. Called by `start.g` (step 6) and `resume.g`. `L` = reload length, `Q` = retract after purge. |
| `RetryLastStep` | Resume `start.g` from `lastInitStep` while the axes are still homed. |
| `SkipCalOn` / `SkipCalOff` | Next `start.g` skips / does G32 and HesCal2. |

## Not included

Older calibration macros (`HesCal`, `HesCal3`, `hes_adive.g`, `hes_climb.g`, `hes_hprof.g`, `hes_line.g`,
`fmt3s.g`), thermal test macros, the AirSquare drift test, filament/tool-change macros and RRF templates
unrelated to calibration are not part of this repository.
