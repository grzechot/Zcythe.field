# Troubleshooting and lessons learned

Collected while developing Zcythe Field on RRF 3.6.1 / Duet 2 WiFi (Sept–Oct 2026).

## Probes

| Symptom | Cause / fix |
|---|---|
| "Probe already triggered", "K0 did not find the bed", K0 "closes by itself" | The nozzle triggered K1 *lower* than K0 touches the bed (`K1 margin` < 0): the K0 needle is pushed into the bed and latches closed. Raise K1 (screw) to a positive margin (~0.2). Second cause: shocks – K0 has a very light trigger, so probing uses gentle dynamics (M201 2000, M566 300). |
| K0 misses K1 (`hSt 1`) | K1 moved (mechanics changed, ΔX −3.6 mm seen) – use the Manual window or `HesFind`. |
| First dive in a new spot reads 0.02–0.045 low | Normal. A preliminary dive is discarded, then two dives must agree within 0.006. |
| Nozzle-on-K1 heights drift or jump between two states (~0.13) | Dirty nozzle (PLA on the tip), K1 mount loose, or the flag sitting right at the opto beam edge (dead-zone screw over-adjusted). Clean the nozzle hot; check the K1 mount. |
| K1 trigger height drops with every dive | The lever was pressed far beyond the trigger point repeatedly. Do not push K1 past its trigger. |
| G31 depends on probing speed | Yes: F240 ≈ 0.04 lower than F30–F60. Use one speed everywhere (80 mm/min fine). |
| K1 tip response is a parabola, not a flat ring | Measured with `HesTip`: the nozzle (ring ID 0.4 / OD 1.0) on the K1 tip also gives a parabola; error ≈ d²/(2R), R ≈ 7.5 (0.1 mm off-centre → 0.001; 0.5 → 0.025). |

## Mechanics seen through the probes

| Observation | Finding |
|---|---|
| G32 needs 4+ passes, one Z motor 2–3 mm off | Lost steps on one Z motor (external A4988 drivers). Step timing `M569 … T5:5:10:10` (A4988 needs ≥ 1 µs) helped but was not the root cause; a better frame mount and driver cooling fixed most of it. Test with `zstep.py`. Note: `M906` does nothing for external drivers – current is set by Vref. |
| Front of the bed drops during a session | Momentary A4988 dropouts; `zwatch.py` showed steady sinking of 0.02–0.08 mm/h per corner. Open issue. |
| Gantry skewed ±1.5 mm after power-off | Trapezoidal leadscrews are not self-locking; the bed sags without current. Accepted – `start.g` always levels after `M18`/power-on, and `bed.g` starts the first pass from 15 mm. |
| K0 reads ~0.018 lower after the head was at the left end of X (nozzle X < 60) | Something (cable chain / harness) loads the carriage at the left end. Under investigation. |
| Approach direction −X vs +X | ≤ 0.009 (alternating ≤ 0.003) – not a cause of first-layer errors. |
| Is a 59 mm mesh pitch enough? | A dense profile every 9.8 mm differed from the mesh by ≤ 0.016 – yes. |
| Bed dome after heating | Forms ~2 min after reaching temperature, settles (±0.005) in 2–9 min → `bedsoak.g`. |

## RRF / Duet pitfalls

- A `G30`/`G38.x` error inside a macro does **not** stop the macro (`result` = 2, the loop goes on). Always check
  `result` and the probe `value` before and after.
- `abort` restores nothing: filament stays retracted, the mesh stays off (`G29 S2`), dynamics stay gentle.
  Restore before `abort` (HesCal2 tracks owed filament in `global.eOwed`).
- `global x = …` a second time in the same power cycle → "variable already exists". Use
  `if !exists(global.x)` + `global x = 0`, then a separate `set global.x = …`. Globals vanish on reset/E-stop.
- Declare `var` before `while` loops (re-declaration inside a loop is an error); a `var` name colliding with another
  in the same file fails only when that line is reached.
- `var a = move.compensation.file` follows the live object – after `G29 S2` it becomes empty. Copy it: `"" ^ …`.
- A G-code line > 255 characters *after substitution* → "GCode command too long" and the macro stops half-way
  (also for `echo >>` and `M291`).
- RRF does not format numbers (`0.6249998`) → `fmt4.g`. `fileread()` reads only the first line of a CSV.
- `M561` (used in `bed.g`) clears the mesh – run G32 before loading a map. `G29` without `S` runs `mesh.g`; `S0/S1/S2` do not.
- RRF compensates the mesh under the **nozzle**, 40 mm from the probe: a mesh check with the map on is invalid –
  check with the map off against the map value.
- `M104`/`M109` also overwrite the *standby* temperature. Use `M568 P0 S<t> A2` + `M116 P0`.
  `heat.coldExtrudeTemperature` = 160 – aim at ≥ 165 for wipe/prime/calibration.
- `M18`/`M84`/reset clear `homed`; after power to the motors the old levelling is invalid.
- Measurements before `G32` after a reset are in a different Z frame (zBed 1.28 instead of 0.92). Always level first.
- `move.calibration.final.deviation` is null until the first G32 after start-up.
- `G30 S-1` does one dive at the *first* configured speed only.

## Windows (M291) and PanelDue

- `M291` is shared by DWC and PanelDue; a new one replaces the previous one; `state.messageBox` null = no window.
- PanelDue shows 3 lines / ~165 characters, no `<br/>`; buttons wrap 5 per row.
- PanelDue may miss a new box opened right after closing one with the same title – add `G4` and vary the title.
- Even `M118 P2` pops up a short "Response" box on PanelDue unless the console tab is open or "Info timeout" = 0.
- `M118 P2` (PanelDue) cannot be read back over HTTP – hence `msg.g` sends every line to DWC (`P3`) too.

## HTTP API

- `rr_upload` returns "not authenticated" after 8 s idle (session timeout) → `rr_connect` right before every upload,
  then `rr_download` and compare. With DWC open: occasionally "no more sessions available".
- Upload macros as UTF-8 without BOM.
- `M25` does not stop a macro started over HTTP; emergency: `M112` + `M999` (board back in 8–27 s).
- `M122` clears the `rr_reply` buffer.
- Object model values right after `rr_gcode` may be stale (move still queued) → `M400` first.
- Duet sometimes answers HTTP 503 under load → retry (`voron_api.get` does).
