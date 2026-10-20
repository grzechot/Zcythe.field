; hes_manual.g - HesCal2 (0:/sys/hescal2_m.g): K0 missed K1 -> operator sets the K0 needle over the K1 tip by hand (2026-10-19)
; Param Z = safe Z for jogging. Result: global.hesManOk (true = Manual + Done + OK), global.hesManX / hesManY = K0 start point.
; Own X/Y buttons 5 / 0.5 mm (M291 jog steps come from the panel). PanelDue puts 5 buttons in a row:
; X-5 X-0.5 X+0.5 X+5 Done / Y-5 Y-0.5 Y+0.5 Y+5 = 4x2 + Done. G4 + title with position: PanelDue misses a new box
; right after closing one with the same title (test 2026-10-19 13:03).
if !exists(global.hesManOk)
  global hesManOk = false
  global hesManX = 0
  global hesManY = 0
set global.hesManOk = false
G90
G1 Z{param.Z} F600
M400
M98 P"0:/sys/hes_log.g" S"K0 missed K1"
M300 S2500 P300
M300 S1800 P300
G4 P400
M291 P"K0 missed K1. Manual = set the K0 needle over the K1 tip by hand (jog), then HesCal2 continues. Stop = HesCal2 error." R"HesCal2: K1 not found" S4 K{"Manual","Stop"}
if input != 0
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
  M291 P"K0 needle over the K1 tip, then Done." R{"K0 at X" ^ var.fx ^ " Y" ^ global.fmt} S4 K{"X-5","X-0.5","X+0.5","X+5","Done","Y-5","Y-0.5","Y+0.5","Y+5"}
  set var.b = input
  if var.b < 4
    G1 X{max(var.x0 - 15, min(var.x0 + 15, move.axes[0].userPosition + var.st[var.b]))} F3000
  elif var.b > 4
    G1 Y{max(var.y0 - 15, min(var.y0 + 15, move.axes[1].userPosition + var.st[var.b - 5]))} F3000
  M400
G4 P400
M291 P"Z jog if needed (keep the K0 needle above K1). OK = continue HesCal2." R"HesCal2: Z check" S2 Z1
M400
set global.hesManX = move.axes[0].userPosition
set global.hesManY = move.axes[1].userPosition
set global.hesManOk = true
M98 P"0:/sys/fmt4.g" V{global.hesManX}
set var.fx = global.fmt
M98 P"0:/sys/fmt4.g" V{global.hesManY}
M98 P"0:/sys/hes_log.g" S{"Manual K0: X" ^ var.fx ^ " Y" ^ global.fmt}
