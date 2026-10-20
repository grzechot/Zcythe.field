; home_sum.g - homing summary on PanelDue + DWC (msg.g), English, numbers max 4 decimals, lines <= 40 chars
; called at the end of homeall.g / homex.g / homey.g / homez.g
; param A = "all", "X", "Y" or "Z"; start time in global.homeT0 (state.upTime, set by the homing file)
if !exists(global.homeT0)
  global homeT0 = state.upTime
var dt = state.upTime - global.homeT0

; single X or Y: one line only
if param.A == "X" || param.A == "Y"
  M98 P"0:/sys/msg.g" S{param.A ^ " homed (" ^ var.dt ^ " s)"}
  M99

; not homed axes (only reported when any)
var bad = ""
while iterations < 3
  if !move.axes[iterations].homed
    set var.bad = var.bad ^ " " ^ move.axes[iterations].letter

M98 P"0:/sys/fmt4.g" V{sensors.probes[0].triggerHeight}
var g31 = global.fmt

; tolerances: B = XY endstop repeatability, C = Z zero shift
M98 P"0:/sys/tolerances.g"   ; tolXY, tolZ in 0:/sys/tolerances.g
var tolXY = global.tolXY
var tolZ = global.tolZ


M98 P"0:/sys/msg.g" S{"-- " ^ (param.A == "all" ? "HOMING" : "Z HOMING") ^ " DONE  " ^ var.dt ^ " s --"}
if var.bad != ""
  M98 P"0:/sys/msg.g" S{"WARNING not homed:" ^ var.bad}
if param.A == "all" && exists(global.homeChkX) && global.homeChkX > -900
  var cx = global.homeChkX
  var cy = global.homeChkY
  M98 P"0:/sys/fmt4.g" V{var.cx}
  var sx = (var.cx >= 0 ? "+" : "") ^ global.fmt
  M98 P"0:/sys/fmt4.g" V{var.cy}
  var sy = (var.cy >= 0 ? "+" : "") ^ global.fmt
  M98 P"0:/sys/msg.g" S{"XY endstop: " ^ var.sx ^ " / " ^ var.sy}
  if abs(var.cx) > var.tolXY
    M98 P"0:/sys/msg.g" S{"WARN X endstop " ^ var.sx ^ " > tolXY " ^ var.tolXY}
  if abs(var.cy) > var.tolXY
    M98 P"0:/sys/msg.g" S{"WARN Y endstop " ^ var.sy ^ " > tolXY " ^ var.tolXY}
var zs = "n/a"
if exists(global.homeZShift) && global.homeZShift > -900
  M98 P"0:/sys/fmt4.g" V{global.homeZShift}
  set var.zs = (global.homeZShift >= 0 ? "+" : "") ^ global.fmt
M98 P"0:/sys/msg.g" S{"Z shift: " ^ var.zs ^ "  G31: " ^ var.g31}
if var.zs != "n/a" && abs(global.homeZShift) > var.tolZ
  M98 P"0:/sys/msg.g" S{"WARN Z shift " ^ var.zs ^ " > tolZ " ^ var.tolZ}
