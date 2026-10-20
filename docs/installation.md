# Installation

> The files in `sys/` are the complete working set of the author's printer (Voron-style CoreXY, 400 × 400,
> 4 Z motors, Duet 2 WiFi, RRF 3.6.1), not a generic package. Merge them with your configuration by hand.
> **Back up your SD card first.**

## 1. Hardware wiring (author's printer)

| Probe | Input | `config.g` |
|---|---|---|
| K0 Zcythe | `zstop` (pull-up) | `M558 P5 C"^zstop" H5:3 F120:80 T18000 A5 S0.01 R0.3` + `G31 P500 X-10 Y-40 Z0.9` |
| K1 Zcythe Stone | `e0stop` | `M558 K1 P8 C"e0stop" H3 F60 T6000 A1` + `G31 K1 P500 X0 Y0 Z0` |

The Zcythe README suggests `M558 P5 C"zstop" H1.2:0.4 F150:90 T30000 A5 S0.003` for a single probe.
Zcythe Field uses higher dive heights (5 / 3 mm, 15 mm for the first G32 pass – the gantry can be skewed after
power-off) and one fixed fine speed everywhere (80 mm/min), because the K0 trigger height depends on the speed.

K1 is defined permanently, so DWC shows both probes. The `G31 K0` values in `config.g` are only start-up
defaults – `k0offset.g` (written by `HesCal2 O1`) and `HesCal2` overwrite them at runtime.

## 2. `config.g` lines the macros rely on

```gcode
M584 X0 Y1 Z5:6:7:8 E3 U4 P4                 ; 4 independent Z motors
M671 X-70:-70:560:560 Y-55:520:520:-55 S20   ; leadscrew positions for G32 (bed.g)
M558 P5 C"^zstop" H5:3 F120:80 T18000 A5 S0.01 R0.3   ; K0: coarse 120 mm/min from 5 mm, fine 80 mm/min from 3 mm
G31 P500 X-10 Y-40 Z0.9
M558 K1 P8 C"e0stop" H3 F60 T6000 A1
G31 K1 P500 X0 Y0 Z0
M557 X5:410 Y5:370 P6:6                      ; only for a plain G29; Mesh uses its own 7x7 grid
M575 P1 S1 B57600                            ; PanelDue
```

`examples/config.g` is the full file of the author's printer, for reference. Do not copy it blindly
(motors, currents, heaters, filament sensor and tool definitions are machine-specific).

No globals have to be declared in `config.g` – every macro creates the globals it needs
(`if !exists(global.x)`), and they are re-created after a reset.

## 3. Files on the SD card

Copy `sys/*` to `0:/sys/` and `macros/*` to `0:/macros/`. Required for the start sequence:

- `start.g`, `cancel.g`, `pause.g`, `resume.g`, `daemon.g`, `bedsoak.g`
- homing: `homeall.g`, `homex.g`, `homey.g`, `homez.g`, `home_do.g`, `home_xy.g`, `home_z.g`, `home_zshift.g`, `home_sum.g`
- levelling: `bed.g`, `bed_pass.g`, `k0g30.g`, `deployprobe0.g`
- calibration: `macros/HesCal2`, `hescal2_m.g`, `hes_h.g`, `hes_vdive.g`, `hes_manual.g`, `hes_log.g`,
  `hes_refdata.g`, `hes_last.g`
- mesh: `macros/Mesh`, `mesh.g`
- console and tolerances: `msg.g`, `fmt4.g`, `fmt3.g`, `tolerances.g`, `tol_ask.g`, `tol_save.g`, `tol_check.g`
- nozzle cleaning: `macros/wipe`, `macros/prime`

`hes_refdata.g` and `hes_last.g` are **data files** written by HesCal2. The copies here contain the author's
values – replace them after your first R1 (see [procedures](procedures.md)). `hes_refdata.g` must exist
(HesCal2 loads it unconditionally).

Optional files created at runtime: `k0offset.g` (K0→nozzle XY offset, `HesCal2 O1`), `hes_cfg.g`
(`global.hesR`, effective K1 tip radius from `HesTip`; default 5.0 when absent), `heightmap_ext.csv`,
`hes_hist.csv`, `hes_h.csv`, `mesh_log.csv`, `cancel_log.csv`.

## 4. Machine-specific values to edit

See [parameters](parameters.md). At minimum: wiper position (`macros/wipe`: `wiperX`, `wiperY`, `parkYOffset`),
bed temperature and prime temperature (`start.g`), Mesh grid (`macros/Mesh`), leadscrew probe points (`bed.g`),
K1 position (`hes_last.g` / `hes_refdata.g`, or run `HesFind`), `kThr` and margins (`hescal2_m.g`).

## 5. Slicer start G-code

`start.g` runs automatically before the print file. The slicer start G-code only needs the print temperatures,
e.g. (OrcaSlicer):

```gcode
G10 P0 S[nozzle_temperature_initial_layer]
M116
```

## 6. First run (checklist)

1. Empty bed, filament loaded, nozzle clean, hand on E-stop.
2. `G28` – watch the homing summary (`-- HOMING DONE --`).
3. `G32` – converges in 2–4 passes to ≤ `tolBed`.
4. `HesFind` – locate the K1 apex with K0 (writes `global.findX/Y/Z`); put it into `hes_last.g`.
5. `HesTip` (optional) – characterise the effective K1 tip radius R → `hes_cfg.g`.
6. `macros/wipe`, then `HesCal2` with `lastGoodG31 = 99` (test mode, G31 is not written) – check `K1 margin`
   and adjust the K1 screw to `kMargin` ± `kMarginTol`.
7. Print a first-layer test, determine the true G31, set `kThr`, run `HesCal2 R1`.
8. Normal prints: `start.g` does the rest.
