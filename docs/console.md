# Console messages (PanelDue + DWC)

Rules used by all core macros:

- **DWC shows everything PanelDue shows, plus expansions.** Every line goes through `0:/sys/msg.g`
  (`S` = both consoles, `L` = a longer DWC version of the same line, `D` = DWC only), never `M118 P2` or
  `echo` alone. The PanelDue line is self-contained – no "see DWC" markers.
- What the operator sees during the start sequence, screen by screen: [PrintInit](printinit.md).
- English, `label: value` format, numbers with at most 4 decimals (`fmt4.g`).
- Lines ≤ 40 characters: PanelDue 5"/7" (800 × 480) uses a proportional font, a row is ~700 px and longer text wraps.
- PanelDue keeps only **12 rows** of history → a step summary has ≤ 8 lines:
  `-- STEP DONE  n s --`, then key values; `WARNING …` only when something is out of tolerance.
- No `M291`/`M117` windows inside measuring loops and in `home*.g`, except for errors that need the operator
  (homing error, G32 not converged, HesCal2 rejected/failed, Mesh check, K0 manual deploy, K1 manual position).
  Those are full-screen windows with the cause, *Check: …* and buttons named after the action
  (≤ 8 characters, PanelDue has fixed 125 px buttons); heaters keep running while they wait, wait timers in
  `printinit_cfg.g`. A window without buttons needs a timeout (`S0 T60`) – RRF 3.6 rejects `S0 T0`.
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
