# Parameters

Values are the author's (2026-10-19). Units mm unless noted.

## `sys/hescal2_m.g` (HesCal2)

| Parameter | Value | Meaning / how to set |
|---|---|---|
| `kThr` | 1.0103 | Nozzle height above the bed when K1 triggers = true G31 + K1 margin. From a first-layer print, see [procedures](procedures.md#new-kthr). After a K1 screw change: `kThr_new = kThr_old + (margin_new − margin_old)` (compare first runs after a wipe). `<= 0` = never write G31. |
| `manualZTrim` | 0 | Added to G31 just before writing (positive = nozzle closer to the bed). |
| `kMargin` / `kMarginTol` | 0.2 / 0.15 | Target K1 margin (`zHEv − zBed`) and the band without a screw suggestion. K1 must trigger *before* K0 would touch the bed, with room for local bed height differences (0.05–0.1), thermal drift (0.03–0.05) and lever travel. |
| `screwMmPerTurn` | 0.4 | K1 trigger change per screw turn for the suggestion (measured 0.4–0.55; loosening raises K1). |
| `bedOff` | −20 | X offset of the bed dive from K1. |
| `dK` / `dHE` | 0.6 / 0.8 | Offsets of the cross dives for the apex fit (K0 / nozzle). |
| `agree` | 0.006 | Two consecutive dives must agree within this. |
| `floorMargin` | 0.30 | Nozzle floor below the expected K1 trigger. |
| `k0Clear`, `k0DiveStart` | 0.8 / 1.0 | K0 travel clearance and dive start above the bed. |
| `calRetract` | 6 | Filament retract during calibration (returned at the end; `eOwed` on abort). |
| `tolOffAccept` | 0.5 | Largest automatically accepted change of the K0→nozzle XY offset (`O1`). |
| `global.hesR` | 5.0 (default) | Effective radius of the K1 tip response; measured ≈ 7.5 with `HesTip`, set in `hes_cfg.g`. |

Reference values (`hes_refdata.g`, written by R1): `refTipBed`, `refK0v`, `refHEv`, `refG31Z`, `refK0X/Y`, `refHEX/Y`.
`lastGoodG31` (runtime global, starts from `refG31Z`) is the last accepted G31; `99` blocks writing (tests).

## `sys/tolerances.g`

| Tolerance | Value | Recommended | Allowed | Used by |
|---|---|---|---|---|
| `tolXY` | 0.30 | 0.05–0.30 | 0.02–1.0 | homing check B (endstop repeatability, typ. ±0.0125) |
| `tolZ` | 0.03 | 0.02–0.05 | 0.01–0.2 | homing check C (Z zero shift) |
| `tolBed` | 0.02 | 0.01–0.03 | 0.005–0.1 | G32 convergence |
| `tolG31Live` | 0.05 | 0.03–0.08 | 0.01–0.5 | HesCal2: new G31 vs last good → window |
| `tolG31Methods` | 0.05 | 0.02–0.06 | 0.01–0.2 | HesCal2: tip vs bed method → warning |
| `tolCheck` | 0.03 | 0.02–0.05 | 0.01–0.2 | Mesh: check point vs map → window |

## Probing speeds (K0)

Decision 2026-10-16: everywhere the same as homing – `M558 K0 H5:3 F120:80 A5 S0.01`
(coarse 120 mm/min from 5 mm, fine 80 mm/min from 3 mm, up to 5 dives, pair within 0.01).
Measured: the K0 trigger height depends on speed (F240 ≈ 0.04 lower than the F30–F60 plateau; F80 ≈ 0.007 below it);
single-dive spread ≤ 0.007. Note: `G30 S-1` does one dive at the *first* speed only.
K1 (nozzle) dives: 30 mm/min.

## Machine-specific values elsewhere

| File | Value |
|---|---|
| `macros/wipe` | `wiperX` 410, `wiperY` 35, `parkYOffset` −15, zig-zag geometry |
| `sys/start.g` | `bedTemp` 55 (PLA), `primeTemp` 220, hotend standby 165 |
| `sys/bed.g`, `bed_pass.g` | K0 points X10 Y5 / X10 Y360 / X380 Y360 / X380 Y5, Z0 point X193 Y195, max 6 passes |
| `macros/Mesh` | grid X5..395 / Y10..364, `row7Delta` −0.05, 8th row Y423 |
| `sys/bedsoak.g` | soak 480 s cold / 180 s warm |
