; hes_manual.g - HesCal2 (0:/sys/hescal2_m.g): K0 missed K1 -> operator sets the K0 needle over the K1 tip by hand (2026-10-19)
; Param Z = safe Z for jogging. Result: global.hesManOk (true = Manual + Done + OK), global.hesManX / hesManY = K0 start point.
; Own X/Y buttons 5 / 0.5 mm (M291 jog steps come from the panel). PanelDue puts 5 buttons in a row:
; X-5 X-0.5 X+0.5 X+5 Done / Y-5 Y-0.5 Y+0.5 Y+5 = 4x2 + Done. G4 + title with position: PanelDue misses a new box
; right after closing one with the same title (test 2026-10-19 13:03).
; 2026-10-22 (task 15): operator texts (Nozzle sensor not found / Probe over sensor / Probe height check); wait timers.
if !exists(global.hesManOk)
  global hesManOk = false
  global hesManX = 0
  global hesManY = 0
set global.hesManOk = false
G90
G1 Z{param.Z} F600
M400
M98 P"0:/sys/hes_log.g" S"Nozzle sensor not found" L"HesCal2: K0 missed K1 (nozzle sensor) - window: set by hand"
M300 S2500 P300
M300 S1800 P300
G4 P400
M98 P"0:/sys/op_wait.g" S1 W"operator"
M291 P"The bed probe missed the nozzle sensor tip. Set it by hand: move the probe needle over the sensor tip with the X/Y buttons." R"Nozzle sensor not found" S4 K{"Manual","Stop"}
if input != 0
  M98 P"0:/sys/op_wait.g" S0
  M99
var x0 = move.axes[0].userPosition    ; buttons limited to +-15 mm from here
var y0 = move.axes[1].userPosition
var st = {-5, -0.5, 0.5, 5}
var b = 0
var fx = ""
while var.b != 4
  M98 P"0:/sys/fmt4.g" V{move.axes[0].userPosition}
  set var.fx = global.fmt
  M98 P"0:/sys/fmt4.g" V{move.axes[1].userPosition}
  G4 P400
  M291 P"Move the probe needle exactly over the sensor tip, then Done." R{"Probe over sensor: X" ^ var.fx ^ " Y" ^ global.fmt} S4 K{"X-5","X-0.5","X+0.5","X+5","Done","Y-5","Y-0.5","Y+0.5","Y+5"}
  set var.b = input
  if var.b < 4
    G1 X{max(var.x0 - 15, min(var.x0 + 15, move.axes[0].userPosition + var.st[var.b]))} F3000
  elif var.b > 4
    G1 Y{max(var.y0 - 15, min(var.y0 + 15, move.axes[1].userPosition + var.st[var.b - 5]))} F3000
  M400
G4 P400
M291 P"Lower Z if needed - keep the needle above the sensor tip. OK = measure." R"Probe height check" S2 Z1
M98 P"0:/sys/op_wait.g" S0
M400
set global.hesManX = move.axes[0].userPosition
set global.hesManY = move.axes[1].userPosition
set global.hesManOk = true
M98 P"0:/sys/fmt4.g" V{global.hesManX}
set var.fx = global.fmt
M98 P"0:/sys/fmt4.g" V{global.hesManY}
M98 P"0:/sys/hes_log.g" S{"Probe set by hand: X" ^ var.fx ^ " Y" ^ global.fmt}
