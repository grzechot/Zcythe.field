; msg.g - one console line, the same text to PanelDue (M118 P2) and DWC (M118 P3)
; rule: PanelDue and DWC consoles must contain the same messages (DWC keeps history, PanelDue only 12 rows)
; S = text: English, numbers max 4 decimals (fmt4.g), <= 40 chars (PanelDue 800x480: 700 px row, longer text wraps)
if exists(param.S)
  M118 P2 S{param.S}
  M118 P3 S{param.S}
