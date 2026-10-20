; home_do.g - home axis/axes and REPEAT until correct; param A = 0 (X), 1 (Y), 2 (Z), 3 (X then Y)
; On error: line in both consoles (msg.g), beep, full-screen window (M291, PanelDue + DWC).
; OK = repeat this axis, Cancel = stop the whole procedure (RRF aborts all macros). Heaters keep running.
var L = (param.A == 0) ? "X" : ((param.A == 1) ? "Y" : ((param.A == 2) ? "Z" : "XY"))
while true
  if param.A == 2
    M98 P"0:/sys/home_z.g"
  elif param.A == 3
    M98 P"0:/sys/home_xy.g" A0
    if global.homeErr == ""
      M98 P"0:/sys/home_xy.g" A1
  else
    M98 P"0:/sys/home_xy.g" A{param.A}
  if global.homeErr == ""
    break
  if param.A != 2
    M18 X Y                     ; XY motors off: axis no longer counts as homed, head can be moved by hand
  M98 P"0:/sys/msg.g" S{"ERROR " ^ global.homeErr}
  M300 S2500 P300
  M300 S1800 P300
  M291 P{global.homeErr ^ ". Fix it, then OK = repeat " ^ var.L ^ " homing, Cancel = stop."} R{"HOMING ERROR " ^ var.L} S3
  M98 P"0:/sys/msg.g" S{"Repeating " ^ var.L ^ " homing"}
  if param.A != 2
    M913 X25 Y25                ; reduced XY current again (motors were off)
