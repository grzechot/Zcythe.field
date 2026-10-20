; hes_log.g - one console line for the Hes* macros; since 2026-10-16 via msg.g = PanelDue AND DWC (same text)
; S = text (short, English, <= 40 chars when possible). Parameters C/R ignored (compatibility with older macros).
if exists(param.S)
  M98 P"0:/sys/msg.g" S{param.S}
