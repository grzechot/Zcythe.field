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

## Requirements

- Duet 2 WiFi with **RepRapFirmware 3.6.1** – the only tested combination. Duet 3 / RRF 3.5.x may work
  (the macros use `fileread`, `M291 S4/S6` with buttons, `G38.3 K`, object model expressions) but are untested.
- A bed probe usable as `M558 P5` (digital, K0) and a second digital probe input for K1 (`M558 K1 P8`).
- PanelDue (optional – console rules are tuned for the 5"/7" 800 × 480 panel) and DWC.
- Python 3.8+ (standard library only) for `tools/`.

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
