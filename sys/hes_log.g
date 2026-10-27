; hes_log.g - one console line for the Hes* macros; via msg.g (PanelDue short S, DWC long L when given)
; S = text (short, English, <= 40 chars; <= 35 with L). L = optional long text for DWC. Parameters C/R ignored (compatibility).
; 2026-10-22 (task 15): D = DWC-only line (service values, dive details)
if exists(param.D)
  M98 P"0:/sys/msg.g" D{param.D}
  M99
if exists(param.S)
  if exists(param.L)
    M98 P"0:/sys/msg.g" S{param.S} L{param.L}
  else
    M98 P"0:/sys/msg.g" S{param.S}
