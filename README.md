# Zcythe Field – automatic Z offset with Zcythe + Zcythe Stone

**Zcythe Field** is an automatic Z-offset (`G31 Z`) calibration system for RepRapFirmware printers.
Two probes work together:

| Probe | Name | Where | In RRF |
|---|---|---|---|
| bed probe – ball tip on a pivoting arm, opto sensor | **Zcythe** (K0) | on the toolhead | `K0`, `sensors.probes[0]` |
| nozzle reference sensor – rounded M3 screw head on a lever, opto sensor | **Zcythe Stone** (K1) | on the bed frame, next to the bed | `K1`, `sensors.probes[1]` |

Before every print the macros measure the bed and the top of K1 with K0, then press the nozzle onto K1.
From these three dives they compute the nozzle height at the K0 trigger point and set `G31 K0 Z` –
no paper, no feeler gauge, no manual babystepping after a nozzle change.

This repository is the **system**: the RepRapFirmware macros for print start-up (heating, homing, levelling,
calibration, mesh, prime), the calibration macro `HesCal2`, console helpers, Python tools that drive and log the
printer over HTTP, and the documentation of the method. The probes are separate projects:

- [Zcythe](https://github.com/grzechot/Zcythe.3d-printer-bed-probe) – the bed probe (K0),
- [Zcythe Stone](https://github.com/grzechot/Zcythe.stone) – the nozzle sensor (K1).

## Status

Working prototype on one machine (Voron-style CoreXY, 400 × 400 bed, 4 independent Z motors,
Duet 2 WiFi, RRF 3.6.1). It is used for real prints, but:

- the method still needs one external reference (R1, a first-layer print) – see
  [how it works](docs/how-it-works.md#the-missing-constant);
- parameters (`kThr`, `refTipBed`, offsets, wiper position) are specific to the author's printer and
  must be re-measured on yours;
- many code comments are still in Polish (the console output and these docs are English).

Expect to read the macros before using them. Nothing here is plug-and-play yet.

## Which printers

Any printer where Zcythe Stone can be fixed rigidly to the bed (or its frame) and the nozzle can reach it:

| Kinematics | Examples | Where Stone goes | Status |
|---|---|---|---|
| CoreXY, bed moves in Z | Voron Trident, RatRig V-Core, VZBot | bed frame, beside the bed | **tested** (4 Z motors, 400 × 400) |
| CoreXY, flying gantry, fixed bed | Voron 2.4 | bed / bed frame | should work, untested |
| bed slinger (bed moves in Y) | Prusa i3 style, Ender style | on the moving bed carriage | should work, untested |
| Cartesian / IDEX with a Z bed | – | bed frame | should work, untested |
| Delta | Kossel style | on the bed / base, beside the print area | should work, untested |

`bed.g` is written for 4 independent Z motors (`G32` with `M671`); with 1–3 Z motors adapt the levelling points
or skip G32 in `start.g`; on a delta use its own calibration instead of G32.

## Requirements

- **The nozzle must travel about 15 mm beyond the bed edge** – Stone sits outside the print area, and both the
  nozzle and Zcythe (offset from the nozzle) have to reach its tip. Check `M208` limits and the cable chain.
- Duet 2 WiFi with **RepRapFirmware 3.6.1** – the only tested combination. Duet 3 / RRF 3.5.x may work
  (the macros use `fileread`, `M291 S4/S6` with buttons, `G38.3 K`, object model expressions) but are untested.
  Klipper / Marlin: untested – the principle is the same; the macros use RRF meta-commands and need to be ported.
- Two digital probe inputs: Zcythe as `M558 P5` (K0) and Stone as `M558 K1 P8`.
- XY probing with moderate dynamics (≈ 2000 mm/s², the macros set it) – Zcythe has a very light trigger.
- PanelDue (optional – console rules are tuned for the 5"/7" 800 × 480 panel) and DWC.
- Python 3.8+ (standard library only) for `tools/`.

## Measured accuracy

Author's printer, October 2026 (raw data in the work logs, not in this repository).

| Quantity | Result |
|---|---|
| Zcythe single dive, same point (σ) | 0.0012–0.0016 mm; spread of single dives ≤ 0.007 mm |
| Two consecutive dives must agree | within 0.006 mm (HesCal2), 0.01 mm (G32, Mesh) |
| Bed map noise (two meshes in a row) | σ of the difference 0.004 mm, max 0.015 mm |
| Mesh check (re-measured points vs map) | ± 0.008 mm |
| Z homing repeatability (check C) | 0.003–0.01 mm |
| XY endstop repeatability (check B) | ± 0.0125 mm |
| G32 final deviation (4 Z motors) | ≤ 0.02 mm, typically 0.014 mm, 2–4 passes |
| G31 from HesCal2, 10 full start cycles | 0.895–0.907 mm, σ 0.004 mm (10/10 without errors) |
| G31 vs first-layer print (micrometer) | "from the bed" method 0.862–0.873 mm vs ≈ 0.86 from the print |
| Full start sequence (home, G32, HesCal2, Mesh 7 × 7) | ≈ 6 min; HesCal2 alone ≈ 60 s |

Limits: the result is only as good as the reference R1 (one first-layer print) and the Z drive – lost Z steps or
a sagging gantry show up directly in the numbers (see below).

## Diagnostics – what it shows about the printer

With a 0.001–0.004 mm probe on the toolhead and a fixed reference beside the bed, the system measures the printer
itself. Findings on the author's machine (scripts in `tools/`):

- **Bed thermal expansion:** the 400 mm steel bed forms a dome of 0.10 mm at 45 °C, 0.13 at 55 °C, 0.165 at 65 °C
  (≈ 0.0035 mm/K), no hysteresis, settles within ± 0.005 mm in 2–9 min → automatic bed soak before levelling (`bedsoak.g`).
- **Gantry / Z-screw drift while warming up:** −0.156 mm mean Z and tilt over 2.5 h, removed by one G32 → level after warm-up.
- **Hotend thermal expansion:** the nozzle grows 0.015–0.025 mm relative to Zcythe at 220–275 °C; Zcythe drifts
  ≈ −0.03 mm next to a hot hotend.
- **Bed sag / Z drive:** lost steps on one Z motor (0.8–2.7 mm after a few hundred fast Z cycles, `zstep.py`), driver dropouts and a
  slowly sinking bed (0.02–0.08 mm/h per corner, `zwatch.py`), gantry skew after motors off (± 1.5 mm, `zdrop.py`).
- **Probe vs speed:** trigger height depends on the dive speed (0.04 mm between 240 and 30–60 mm/min, `zspeed.py`).
- **Carriage / harness:** Zcythe reads 0.018 mm lower after the head was at the left end of X (cable chain load, `xdir.py`);
  approach direction −X vs +X ≤ 0.009 mm (`adir.py`).
- **Bed stability map** (repeatability per point, drift-corrected, `bedstab.py`) and **mesh density check**
  (dense profile vs mesh ≤ 0.016 mm, `prof.py`).
- **Hotend mount stability:** a loose hotend in its housing was found from repeated HesCal2 runs (22 Oct 2026): the
  nozzle height at the Stone trigger stayed within 0.012 mm inside one series but jumped in steps of 0.05–0.12 mm
  between series (pushed up by the dives onto the Stone, moved back by hand cleaning), while Zcythe on the Stone tip
  and on the bed stayed constant. A probe on the carriage plus a nozzle reference separates "the nozzle moved" from
  "the bed moved".
- **Every start:** homing checks B/C catch a failing endstop (a +5 mm fault was caught) or a Z zero shift;
  G32 passes and HesCal2 values (K1 margin, tip height, G31 methods) are logged to `hes_hist.csv`, so changes in the
  mechanics show up from print to print.

In short: if the printer has a mechanical imperfection that moves the nozzle relative to the bed by more than
~0.01 mm, Zcythe Field will usually show it – bed thermal deformation, bed frame sag, skipped Z steps, hotend
thermal growth and the stability of the hotend and probe mounts. Fix the mechanics first: the calibration cannot
be more accurate than the loosest part of the machine.

## Layout

```
sys/        files for 0:/sys  (start.g, homing, bed.g, HesCal2 measurement, Mesh helpers, console helpers)
macros/     files for 0:/macros (HesCal2 wrapper, Mesh, wipe, prime, HesFind, HesTip …)
examples/   the author's config.g (reference only)
tools/      Python/PowerShell helpers using the rr_* HTTP API (set PRINTER_HOST); tools/cad – .pk2 thumbnails
docs/       documentation
```

## Documentation

- [How it works](docs/how-it-works.md) – the three dives, the formulas, why a reference is needed
- [Installation](docs/installation.md) – files on the SD card, `config.g` lines, first run
- [Macros](docs/macros.md) – every file in `sys/` and `macros/`
- [Parameters](docs/parameters.md) – what to tune and where
- [Geometry](docs/geometry.md) – probe dimensions and how they map to the parameters
- [Procedures](docs/procedures.md) – R1 reference, K1 margin, screw adjustment, after a print
- [Console](docs/console.md) – PanelDue/DWC message rules
- [Tools](docs/tools.md) – Python scripts
- [Troubleshooting / lessons learned](docs/troubleshooting.md)
- [Changelog](CHANGELOG.md)

## Safety

These macros move the machine, press the nozzle onto a sensor and change `G31`. A wrong parameter can
crash the nozzle into the bed or into K1. Test every change with a hand on the emergency stop, with an
empty bed, and check the first layer.

## License

TODO – not decided yet (see `LICENSE`).
