; home_xy.g - home ONE axis X or Y with checks; result in global.homeErr ("" = OK, else error text)
; param A = 0 (X) or 1 (Y). Called by home_do.g (retry loop). Motor current M913 25 % set by the caller.
; Checks: endstop reached after coarse and fine approach, endstop released after 5 mm back-off (stuck switch),
; B = repeatability: back off 5 mm, approach again at fine speed with H4 (stops, zero NOT reset) -> deviation.
if !exists(global.homeErr)
  global homeErr = ""
if !exists(global.homeChkX)
  global homeChkX = -999
if !exists(global.homeChkY)
  global homeChkY = -999
var a = param.A
var L = (var.a == 0) ? "X" : "Y"
M98 P"0:/sys/tolerances.g"
var tolB = global.tolXY          ; [mm] check B tolerance = tolXY in 0:/sys/tolerances.g
var travel = move.axes[var.a].max - move.axes[var.a].min + 5
set global.homeErr = ""
if var.a == 0
  set global.homeChkX = -999
else
  set global.homeChkY = -999
G91
; 1. coarse approach
if var.a == 0
  G1 H1 X{-var.travel} F3000
else
  G1 H1 Y{-var.travel} F3000
M400
if !sensors.endstops[var.a].triggered
  set global.homeErr = var.L ^ " endstop not reached (coarse)"
  G90
  M99
; 2. back off 5 mm - switch must release
if var.a == 0
  G1 X5 F6000
else
  G1 Y5 F6000
M400
if sensors.endstops[var.a].triggered
  set global.homeErr = var.L ^ " endstop stuck after back-off"
  G90
  M99
; 3. fine approach - sets the zero
if var.a == 0
  G1 H1 X{-var.travel} F1500
else
  G1 H1 Y{-var.travel} F1500
M400
if !sensors.endstops[var.a].triggered
  set global.homeErr = var.L ^ " endstop not reached (fine)"
  G90
  M99
; 4. check B: back off 5 mm (must release), approach again with H4
if var.a == 0
  G1 X5 F6000
else
  G1 Y5 F6000
M400
if sensors.endstops[var.a].triggered
  set global.homeErr = var.L ^ " endstop stuck after back-off"
  G90
  M99
if var.a == 0
  G1 H4 X-10 F1500
else
  G1 H4 Y-10 F1500
M400
G90
var dev = move.axes[var.a].machinePosition
if var.a == 0
  set global.homeChkX = var.dev
else
  set global.homeChkY = var.dev
if !sensors.endstops[var.a].triggered
  set global.homeErr = var.L ^ " endstop not reached (check B)"
  M99
if abs(var.dev) > var.tolB
  M98 P"0:/sys/fmt4.g" V{var.dev}
  set global.homeErr = var.L ^ " endstop " ^ global.fmt ^ " > tolXY " ^ var.tolB
