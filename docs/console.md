# Console messages (PanelDue + DWC)

Rules used by all core macros:

- **PanelDue and DWC show the same text.** Every line goes through `0:/sys/msg.g`
  (`M118 P2` + `M118 P3`), never `M118 P2` or `echo` alone.
- English, `label: value` format, numbers with at most 4 decimals (`fmt4.g`).
- Lines ≤ 40 characters: PanelDue 5"/7" (800 × 480) uses a proportional font, a row is ~700 px and longer text wraps.
- PanelDue keeps only **12 rows** of history → a step summary has ≤ 8 lines:
  `-- STEP DONE  n s --`, then key values; `WARNING …` only when something is out of tolerance.
- No `M291`/`M117` windows inside measuring loops and in `home*.g`, except for errors that need the operator
  (homing error, G32 not converged, HesCal2 rejected/failed, Mesh check, K0 manual deploy, K1 manual position).
  Those are full-screen windows with buttons; heaters keep running while they wait.
- G-code lines < 256 characters after expression substitution (otherwise "GCode command too long" stops the macro
  half-way).
- No `M`, `G` or `E` parameters in `M98` calls (RRF treats them specially).

Example – end of HesCal2 (illustrative values):

```
-- HESCAL2 DONE  61 s --
K1 tip/bed: 1.3012 (ref 1.2638)
dz: 1.1513  K1 margin: 0.1502
K1 screw: OK
G31 tip: 0.8978  bed: 0.8601
G31 SET 0.8978 (measured)
```
