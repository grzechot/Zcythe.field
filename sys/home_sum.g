; home_sum.g - homing summary on PanelDue + DWC (msg.g), English, numbers with unit and limit, lines <= 40 chars
; called at the end of homeall.g / homex.g / homey.g / homez.g
; param A = "all", "X", "Y" or "Z"; start time in global.homeT0 (state.upTime, set by the homing file)
; 2026-10-22 (task 15): X/Y line with check B also for single axes (G28 XYZ in start.g); Z: zero change with limit,
; probe offset; WARNING with what to do; inside HesCal2 (global.hesQuiet) one line only.
if !exists(global.homeT0)
  global homeT0 = state.upTime
var dt = state.upTime - global.homeT0
M98 P"0:/sys/tolerances.g"   ; tolXY, tolZ in 0:/sys/tolerances.g
var tolXY = global.tolXY
var tolZ = global.tolZ

; single X or Y: one line with check B (repeatability) when measured
if param.A == "X" || param.A == "Y"
  var cb = (param.A == "X") ? (exists(global.homeChkX) ? global.homeChkX : -999) : (exists(global.homeChkY) ? global.homeChkY : -999)
  if var.cb > -900
    M98 P"0:/sys/fmt3s.g" V{var.cb}
    M98 P"0:/sys/msg.g" S{param.A ^ " homed " ^ var.dt ^ " s: " ^ global.fmt ^ " mm (max " ^ var.tolXY ^ ")"} L{param.A ^ " homed in " ^ var.dt ^ " s; endstop repeatability (check B) " ^ global.fmt ^ " mm, tolXY " ^ var.tolXY ^ " mm"}
  else
    M98 P"0:/sys/msg.g" S{param.A ^ " homed (" ^ var.dt ^ " s)"}
  M99

; not homed axes (only reported when any)
var bad = ""
while iterations < 3
  if !move.axes[iterations].homed
    set var.bad = var.bad ^ " " ^ move.axes[iterations].letter

M98 P"0:/sys/fmt3.g" V{sensors.probes[0].triggerHeight}
var g31 = global.fmt
var zs = "n/a (first homing)"
var zOk = exists(global.homeZShift) && global.homeZShift > -900
if var.zOk
  M98 P"0:/sys/fmt3s.g" V{global.homeZShift}
  set var.zs = global.fmt
M98 P"0:/sys/fmt3.g" V{var.tolZ}
var sTolZ = global.fmt

; Z homing inside HesCal2 (new probe offset): one line
if param.A == "Z" && exists(global.hesQuiet) && global.hesQuiet
  M98 P"0:/sys/msg.g" S"Z re-homed with new offset" L{"Z re-homed with the new probe offset (G31 " ^ var.g31 ^ " mm) in " ^ var.dt ^ " s"}
  M99

M98 P"0:/sys/msg.g" S{"-- " ^ (param.A == "all" ? "HOMING" : "Z HOMING") ^ " DONE  " ^ var.dt ^ " s --"}
if var.bad != ""
  M98 P"0:/sys/msg.g" S{"WARNING not homed:" ^ var.bad}
if param.A == "all" && exists(global.homeChkX) && global.homeChkX > -900
  M98 P"0:/sys/fmt3s.g" V{global.homeChkX}
  var sx = global.fmt
  M98 P"0:/sys/fmt3s.g" V{global.homeChkY}
  var sy = global.fmt
  M98 P"0:/sys/msg.g" S{"X/Y repeat: " ^ var.sx ^ "/" ^ var.sy ^ " mm (max " ^ var.tolXY ^ ")"} L{"X/Y endstop repeatability (check B): " ^ var.sx ^ " / " ^ var.sy ^ " mm, tolXY " ^ var.tolXY ^ " mm"}
M98 P"0:/sys/msg.g" S{"Z zero change: " ^ var.zs ^ (var.zOk ? (" mm (max " ^ var.sTolZ ^ ")") : "")} L{"Z zero change vs previous homing (check C, tolZ in sys/tolerances.g): " ^ var.zs ^ (var.zOk ? " mm" : "")}
M98 P"0:/sys/msg.g" S{"Probe offset: " ^ var.g31 ^ " mm"} L{"Probe offset (G31 Z, K0 trigger height): " ^ var.g31 ^ " mm"}
if var.zOk && abs(global.homeZShift) > var.tolZ
  M98 P"0:/sys/msg.g" S{"WARNING Z zero moved " ^ var.zs ^ " mm"} L{"WARNING Z zero moved " ^ var.zs ^ " mm since the previous homing (tolZ " ^ var.sTolZ ^ " mm) - Z drive drift, see task 14"}
  M98 P"0:/sys/msg.g" S{" max " ^ var.sTolZ ^ " - after print check Z drive"}
