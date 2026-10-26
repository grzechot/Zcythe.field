; msg.g - one console line: PanelDue (M118 P2) short, DWC (M118 P3) full
; S = short text for PanelDue: English, numbers with unit and limit (fmt3/fmt4), <= 40 chars
; L = optional long text for DWC (expanded parameter names, details) - DWC gets L instead of S
; D = DWC-only line (service values, map table) - PanelDue gets nothing
; Rule (2026-10-20, operator): DWC shows everything PanelDue shows, plus expansions.
; 2026-10-22 (task 15): no " >DWC" marker - the PanelDue line is self-contained. Glossary: macro "Legend" (DWC).
if exists(param.D)
  M118 P3 S{param.D}
  M99
if exists(param.S)
  M118 P2 S{param.S}
  if exists(param.L)
    M118 P3 S{param.L}
  else
    M118 P3 S{param.S}
