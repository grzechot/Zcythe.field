# How it works

## The two probes

- **K0 – Zcythe** (bed probe, on the toolhead). A 3.2 mm ball on a short arm (10 mm) of a pivoting lever;
  the long arm (85 mm) carries a flag in an opto sensor (≈ 8.5 : 1 lever ratio). It is a *manually deployed*
  needle: before probing it must be open (`deployprobe0.g` waits for the operator), and it closes by itself
  when pushed too far. Offset from the nozzle on the author's printer: X −12.365, Y −39.593 mm.
  Trigger height `G31 K0 Z` ≈ 0.8–0.9 mm (the nozzle is that high above the bed when K0 triggers).
- **K1 – Zcythe Stone** (nozzle sensor, on the bed frame beside the bed, outside the print area). A ball top on a
  lever with an opto sensor. K0 is too light to trigger it; only the nozzle pressing on it does. Its trigger point
  is set mechanically by a screw (≈ 0.4–0.55 mm per turn, loosening raises K1).

Both probes are continuous-mode digital probes; a probe "releases" when the motion is reversed.

## The three dives (HesCal2)

```
            K0 on bed            K0 on K1 apex          nozzle on K1
               |                     |                      ||
               o  <- K0 ball         o                     _||_  <- nozzle
                                    ( )  <- K1 ball top    ( )
  ============bed=========   |=====frame=====|     |=====frame=====|
        zBed                       zK0v                   zHEv          (machine Z at trigger)
```

1. **Bed next to K1** – K0 dives on the bed 20 mm left of K1 (`bedOff`): `zBed`.
2. **K0 on the K1 apex** – one preliminary dive (discarded – the first dive in a new spot is 0.02–0.045 mm low)
   plus 4 dives at ±`dK` (0.6 mm) in X and Y. The response of a ball is a parabola,
   `z(d) ≈ z0 − d²/(2R)` with the effective radius R ≈ 7.5 mm, so the apex position is
   `x0 = cX + R·(z(+dK) − z(−dK)) / (2·dK)` (same in Y). Then two agreeing dives (within `agree` = 0.006 mm)
   at the apex: `zK0v`.
3. **Nozzle on K1** – the nozzle goes to apex + K0→nozzle offset and dives until K1 triggers; two agreeing
   dives: `zHEv`. A floor (`global.hesFloor`) stops the nozzle `floorMargin` (0.30 mm) below the expected trigger
   and never closer than 0.3 mm above the bed.

Derived values:

| Value | Formula | Meaning |
|---|---|---|
| `tipBed` | `zK0v − zBed` | K1 apex above the bed, as seen by K0 (≈ 1.1–1.3 mm) |
| `dz` | `zK0v − zHEv` | K0 trigger on the apex vs nozzle trigger on the apex |
| `kMarg` | `zHEv − zBed` | K1 margin: how much higher K1 triggers than K0 on the bed (target `kMargin` 0.2) |
| `G31 bed` | `zBed − (zHEv − kThr)` | "from the bed" method |
| `G31 tip` | `dz − refTipBed + kThr` | "from the tip" method – independent of the bed spot next to K1 |

`kThr` = nozzle height above the bed at the moment K1 triggers – a constant of the K1 setting.

## The missing constant

Write the physics with three unknowns: true trigger height `g` (= G31), K1 apex height above the bed `T`, and
the K1 dead travel `d` (how far the nozzle pushes the K1 ball down before the sensor switches). With K0 pretravel
equal on the bed and on the apex:

```
zK0v − zBed = T                       (tipBed)
zHEv        = (zBed − g) + T − d      (nozzle touches the apex at T, triggers d lower)
dz          = zK0v − zHEv = g + d
```

Three dives give the frame (`zBed`), `T` and **g + d** – but `g` and `d` cannot be separated. One external
reference is needed. Today it is `kThr = T − d`, obtained once from a first-layer print:

1. print a first layer, find the true G31 (micrometer on the layer, or the babystep that made it right);
2. `kThr = G31_true + kMarg` (kMarg from a HesCal2 run in the same mechanical state);
3. save a reference with `HesCal2 R1` (stores `refTipBed`, `refK0v`, `refHEv`, `refG31Z` in `hes_refdata.g`).

Every mechanical change of K1 (screw, mount) or of the bed sheet changes `T` and/or `d` → new `kThr` and new R1.

**Planned:** measure `d` directly (the operator brings a rigid part of the toolhead onto the K1 ball until it
triggers), then `G31 = dz − d` with no print reference and a single method.

## Two methods – which one is used

- *From the tip* (`G31 tip`) depends only on `dz` and the constants from R1. It was made the main method on
  2026-10-13, because the bed spot next to K1 "floats" after a large G32 correction.
- *From the bed* (`G31 bed`) depends on the bed spot next to K1. R1 uses it as the absolute anchor.

Observation 2026-10-19: after mechanical changes to K1, `G31 bed` (0.862–0.873) matched the first-layer print,
while `G31 tip` with the old `kThr`/`refTipBed` was too high. Both constants have to be re-measured after any K1
change – the macro warns when the methods differ by more than `tolG31Methods`.

## Gates and fallbacks

- New G31 vs `lastGoodG31` > `tolG31Live` → window **HESCAL2: G31 REJECTED** (Use measured / Repeat / Change tol).
- Methods differ > `tolG31Methods` → console warning only.
- Measurement fails during a print → window **HESCAL2: ERROR** (Repeat / Use last good / Cancel); heaters stay on.
- K0 misses K1 → window from `hes_manual.g`: the operator jogs K0 over the K1 ball (±5 / ±0.5 mm buttons) and
  the step restarts from there.
- `kThr <= 0` → G31 is never written (measurement-only mode). `lastGoodG31 = 99` blocks writing for test runs.

## Where it sits in the start sequence

`start.g` (run automatically before every print):

1. heat (bed to print temperature, hotend 165 °C standby);
2. open K0 → home XYZ (only if not homed) → bed soak (`bedsoak.g`, 3–8 min) → G32 (`bed.g`, only if not done);
3. `wipe`;
4. `HesCal2` (skipped if `skipCal` is set after a good calibration);
5. `Mesh` – fresh 7 × 7 map + extrapolated 8th row, every print;
6. `prime`.

A failed step leaves `global.lastInitStep`; `macros/RetryLastStep` resumes from there while the axes stay homed.
