# Geometry – probes and macro parameters

Values from the author's printer. Original table 2026-10-10, updated 2026-10-19 where newer measurements exist.

| Quantity | Value | Used in |
|---|---|---|
| Effective radius of the tip response (ball + arm), K0 and nozzle | R ≈ 7.5 mm (K0 7.44 ± 0.65, nozzle 7.60 ± 0.58), fitted from `HesTip` data – **not** the ball radius | `0:/sys/hes_cfg.g` (`global.hesR`) |
| K0 travel | ~1 mm, then it closes by itself (needle ~1 mm above the nozzle when closed) | `deployprobe0.g` |
| K0 → nozzle offset | X −12.365, Y −39.593 mm (± 0.055) | `0:/sys/k0offset.g` (`G31 K0 X Y`) |
| K0 trigger height `G31 K0 Z` | ≈ 0.80–0.90 mm | written by `HesCal2` |
| K1 margin over K0 on the bed | target +0.18 … +0.20 (± 0.05 … 0.15) | `kMargin`, `kMarginTol` in `hescal2_m.g` |
| `kThr` (nozzle above the bed when K1 triggers) | 0.94 (2026-10-09) → 1.0103 (2026-10-14); to be re-measured after K1 mount changes | `hescal2_m.g` |
| K1 height screw (M3) | ≈ 0.40–0.55 mm per turn; **loosening raises K1** | `screwMmPerTurn` |
| K1 dead-zone screw | moves the flag in the opto slot – changes the trigger point, not the rest height of the ball; recommended 0.05–0.15 mm (measured 0.16–0.19) | – |
| K1 apex above the bed (seen by K0) | ≈ 1.12 (2026-10-09), 1.26 (R1 2026-10-14), 1.30 (2026-10-16) | `refTipBed` in `hes_refdata.g` |
| K1 dead travel `d` | not yet measured directly (see [how it works](how-it-works.md#the-missing-constant)) | planned |
| Filament retract during K1 measurement | 6 mm (`calRetract`) | `hescal2_m.g` |

## Mounting

- K0 is on the toolhead; the needle pivots on its axis (it cannot bend) and is opened by hand before probing.
- K1 is screwed to the **bed frame** (not to the sheet), outside the print area, beside the right edge of the bed
  (K1 apex at about X425 Y322 in K0 coordinates on the author's printer). The bed sheet itself sits rigid in the
  centre and on 8 spring screws at the edges – adjusting those changes the bed height next to K1, so every sheet
  adjustment needs a new K1 margin, `kThr` and R1.
- K1 triggers only from a vertical push (from the side only when pressed in −Y).
- K1 material: ABS.

## Construction

Parts, assembly and BOM of the probes: [Zcythe](https://github.com/grzechot/Zcythe.3d-printer-bed-probe) (K0) and
[Zcythe Stone](https://github.com/grzechot/Zcythe.stone) (K1).
