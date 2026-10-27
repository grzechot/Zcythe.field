; bed.g - bed levelling (G32): 4 Z motors corrected from K0 at the 4 leadscrew points
; Homing is NOT done here - start.g does it (only when axes are not homed) or a manual G28.
; Passes: at least 2, more until the deviation before correction <= 0.02 mm (max 6). Not converged -> full-screen
; window: OK = level again, Cancel = stop (heaters keep running). Then Z0 is set again with K0 at X193 Y195.
; K0 probing = homing values (decision 2026-10-16): M558 K0 H5:3 F120:80 A5 S0.01.
; Summary in both consoles (msg.g): passes, deviation per pass, time. levelDone = true only after convergence.
; 2026-10-22 (task 15): line after every pass; window Level again / Continue anyway / Change limit / Cancel print
; (operator); Continue anyway = level of the last pass kept, Z0 set, levelDone = true, WARNING. Moves unchanged.
M561                        ; clear old bed transforms
if !move.axes[0].homed || !move.axes[1].homed || !move.axes[2].homed
  abort "Level bed: home first (G28)"
if !exists(global.levelDone)
  global levelDone = false
set global.levelDone = false   ; levelling in progress - set true only at the very end
if !exists(global.bedDevs)
  global bedDevs = ""
if !exists(global.bedPasses)
  global bedPasses = 0
var t0 = state.upTime
M98 P"0:/sys/tolerances.g"
var tol = global.tolBed     ; [mm] deviation before correction that counts as level (tolBed in 0:/sys/tolerances.g)
var maxPasses = 6
var dev1 = ""                ; tilt before the first correction (summary)
var forced = false           ; operator: Continue anyway
var cancel = (job.file.fileName != null) ? "Cancel" : "Stop"
var bk = (exists(global.piBackLbl) && exists(global.piRun) && global.piRun && job.file.fileName != null) ? global.piBackLbl : ""   ; 261024 (pliki_36): krok wstecz w PrintInit
if !exists(global.piBack)
  global piBack = 0
M98 P"0:/sys/msg.g" D"Leveling: Z +15 mm first (gantry may be tilted), gentle moves, K0 at the 4 leadscrew points"

; gentler carriage dynamics during levelling (K0 has a very light trigger and closed early from shocks);
; restored at the end, after abort/Cancel it stays gentle until restart (safe direction)
var ax = move.axes[0].acceleration    ; mm/s^2
var ay = move.axes[1].acceleration
var jx = move.axes[0].jerk            ; mm/min (as M566)
var jy = move.axes[1].jerk
M201 X1500 Y1500
M566 X300 Y300
G91
G92 U0
G1 H2 Z15 F6000             ; 2026-10-19: 15 mm (was 5) - after mechanical work the gantry can be skewed by several mm
M401
G90
M561
M98 P"0:/sys/deployprobe0.g"   ; K0 must be open before the first point (waits for the operator)
M558 K0 H5:3 F120:80 A5 S0.01 T21000

while true
  set global.bedDevs = ""
  set global.bedPasses = 0
  M558 K0 H15:3 F120:80 A5 S0.01 T21000   ; pass 1: dive from 15 mm (skewed gantry, 2026-10-19)
  M98 P"0:/sys/bed_pass.g"     ; pass 1 - coarse correction
  if global.piBack > 0
    break
  set var.dev1 = global.fmt
  M98 P"0:/sys/msg.g" S{"Pass " ^ global.bedPasses ^ ": bed tilt " ^ global.fmt ^ " mm"}
  M558 K0 H5:3 F120:80 A5 S0.01 T21000    ; next passes: homing values again
  M561
  M98 P"0:/sys/bed_pass.g"     ; pass 2
  if global.piBack > 0
    break
  M98 P"0:/sys/msg.g" S{"Pass " ^ global.bedPasses ^ ": bed tilt " ^ global.fmt ^ " mm"}
  while move.calibration.initial.deviation > var.tol && global.bedPasses < var.maxPasses
    M98 P"0:/sys/bed_pass.g"
    if global.piBack > 0
      break
    M98 P"0:/sys/msg.g" S{"Pass " ^ global.bedPasses ^ ": bed tilt " ^ global.fmt ^ " mm"}
  if global.piBack > 0
    break
  if move.calibration.initial.deviation <= var.tol
    break
  M98 P"0:/sys/fmt3.g" V{move.calibration.initial.deviation}
  var sDev = global.fmt
  M98 P"0:/sys/fmt3.g" V{var.tol}
  var sTol = global.fmt
  M98 P"0:/sys/msg.g" S{"ERROR bed tilt " ^ var.sDev ^ " mm (max " ^ var.sTol ^ ")"} L{"ERROR bed levelling (G32): deviation " ^ var.sDev ^ " mm > tolBed " ^ var.sTol ^ " mm after " ^ global.bedPasses ^ " passes; per pass:" ^ global.bedDevs}
  M300 S2500 P300
  M300 S1800 P300
  var m = "After " ^ global.bedPasses ^ " passes the bed tilt is still " ^ var.sDev ^ " mm (max " ^ var.sTol ^ "). Tilt per pass:" ^ global.bedDevs ^ "."
  set var.m = var.m ^ " Check: Z belts and couplers, a Z motor losing steps, loose bed screws. Heaters and motors stay on."
  var act = ""
  M98 P"0:/sys/op_wait.g" S1 W"operator"
  while var.act == ""
    G4 P400
    if var.bk == ""
      M291 P{var.m} R"Bed not level" S4 K{"Relevel", "Continue", "Set limit", var.cancel}
    else
      M291 P{var.m} R"Bed not level" S4 K{"Relevel", "Continue", "Set limit", var.cancel, var.bk}
    var k = input
    if var.k == 0
      set var.act = "again"
    elif var.k == 1
      set var.act = "continue"
    elif var.k == 3
      set var.act = "cancel"
    elif var.k == 4
      set var.act = "back"
    else
      var oldTol = var.tol
      M98 P"0:/sys/tol_ask.g" S"tolBed" V{var.tol} A{global.tolBedR[0]} B{global.tolBedR[1]} L{global.tolBedR[2]} H{global.tolBedR[3]} T"BED LEVEL - CHANGE LIMIT"
      if global.tolAskVal >= 0
        set var.tol = global.tolAskVal
        set global.tolBed = global.tolAskVal
        M98 P"0:/sys/tol_save.g" S"tolBed" V{var.oldTol} N{global.tolBed}
        if move.calibration.initial.deviation <= var.tol
          set var.act = "accepted"
  M98 P"0:/sys/op_wait.g" S0
  if var.act == "cancel"
    abort "Leveling stopped by operator"
  if var.act == "continue"
    set var.forced = true
    break
  if var.act == "accepted"
    break
  if var.act == "back"
    set global.piBack = global.piStage - 1
    M98 P"0:/sys/msg.g" S{"Operator: " ^ var.bk}
    break
  M98 P"0:/sys/msg.g" S"Operator: level again"

if global.piBack > 0
  M558 K0 H5:3 F120:80 T18000 A5 S0.01 R0.3   ; probe settings back to config.g
  M201 X{var.ax} Y{var.ay}
  M566 X{var.jx} Y{var.jy}
  M99                         ; 261024 (pliki_36): step back - start.g repeats an earlier step
G4 P500                     ; let the mechanics settle
G1 X205 Y235 F9000          ; nozzle -> K0 at X193 Y195
M98 P"0:/sys/k0g30.g"       ; final Z0 after levelling
if global.piBack > 0
  M558 K0 H5:3 F120:80 T18000 A5 S0.01 R0.3   ; probe settings back to config.g
  M201 X{var.ax} Y{var.ay}
  M566 X{var.jx} Y{var.jy}
  M99                         ; 261024 (pliki_36): step back - start.g repeats an earlier step

M558 K0 H5:3 F120:80 T18000 A5 S0.01 R0.3   ; probe settings back to config.g
M557 X5:400 Y10:370 P6:6
G1 Z2
M201 X{var.ax} Y{var.ay}    ; restore dynamics from before levelling
M566 X{var.jx} Y{var.jy}
set global.levelDone = true    ; levelled - start.g skips G32 until something homes the axes

M98 P"0:/sys/fmt3.g" V{move.calibration.initial.deviation}
var sEnd = global.fmt
M98 P"0:/sys/fmt3.g" V{var.tol}
var sTolE = global.fmt
M98 P"0:/sys/msg.g" S{"-- BED LEVELING DONE  " ^ (state.upTime - var.t0) ^ " s --"}
M98 P"0:/sys/msg.g" S{"Bed tilt: " ^ var.dev1 ^ " -> " ^ var.sEnd ^ " mm (max " ^ var.sTolE ^ ")"} L{"G32 tilt (max deviation of the 4 probe points before correction) per pass:" ^ global.bedDevs ^ " mm, tolBed " ^ var.sTolE ^ " mm"}
M98 P"0:/sys/msg.g" S{"Passes: " ^ global.bedPasses}
if var.forced
  M98 P"0:/sys/msg.g" S{"WARNING bed tilt " ^ var.sEnd ^ " mm (max " ^ var.sTolE ^ ")"} L{"WARNING bed tilt " ^ var.sEnd ^ " mm > tolBed " ^ var.sTolE ^ " mm - operator: Continue anyway"}
  M98 P"0:/sys/msg.g" S" after print: check Z drive"
