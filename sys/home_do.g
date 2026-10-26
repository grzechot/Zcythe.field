; home_do.g - home axis/axes and REPEAT until correct; param A = 0 (X), 1 (Y), 2 (Z), 3 (X then Y)
; Homing moves and checks unchanged (home_xy.g / home_z.g). Heaters keep running.
; 2026-10-22 (task 15): operator window with cause, what to check and named buttons (error code from home_xy.g /
; home_z.g): Home X again / Test endstop X manually / Cancel; endstop repeatability (> tolXY): XY motors stay on,
; Continue anyway / Change limit; Z: Test probe manually; X/Y not homed: Home X/Y now. Wait timers: op_wait.g.
; XY motors off (M18 X Y) only for mechanical errors (CoreXY: both axes lost -> the retry homes X again before Y).
; globals exist only after the first home_xy.g / home_z.g run - declare here (after a reset: "unknown variable", 22.10 16:37)
if !exists(global.homeErr)
  global homeErr = ""
if !exists(global.homeErrCode)
  global homeErrCode = 0
if !exists(global.homeErrAxis)
  global homeErrAxis = 0
var cancel = (job.file.fileName != null) ? "Cancel" : "Stop"
var bk = (exists(global.piBackLbl) && exists(global.piRun) && global.piRun && job.file.fileName != null) ? global.piBackLbl : ""   ; 261024 (pliki_36): krok wstecz w PrintInit
var xNeed = (param.A == 0 || param.A == 3)
var n = 0
var c = 0
var L = ""
var t = ""
var m = ""
var k = -1
var act = ""
var dev = 0
var sDev = ""
while true
  set global.homeErr = ""
  if param.A == 2
    M98 P"0:/sys/home_z.g"
  else
    if var.xNeed
      M98 P"0:/sys/home_xy.g" A0
      if global.homeErr == ""
        set var.xNeed = false
    if global.homeErr == "" && param.A != 0
      M98 P"0:/sys/home_xy.g" A1
  if global.homeErr == ""
    break
  set var.n = var.n + 1
  set var.c = global.homeErrCode
  set var.L = (global.homeErrAxis == 0) ? "X" : ((global.homeErrAxis == 1) ? "Y" : "Z")
  ; --- texts ---
  if var.c == 1
    set var.t = var.L ^ " endstop not reached"
    set var.m = "The toolhead moved the whole " ^ var.L ^ " travel but the " ^ var.L ^ " endstop did not click."
    set var.m = var.m ^ " Check: nothing blocks the toolhead or belt; endstop cable plugged in."
  elif var.c == 2
    set var.t = var.L ^ " endstop stays pressed"
    set var.m = "5 mm away from the endstop it still reads pressed. Check: switch lever stuck, cable shorted."
  elif var.c == 3 || var.c == 4
    set var.t = var.L ^ " endstop signal unstable"
    set var.m = "It clicked on the fast approach but not on the slow one. Check: loose switch or cable, dirt on the lever."
  elif var.c == 5
    set var.dev = (global.homeErrAxis == 0) ? global.homeChkX : global.homeChkY
    M98 P"0:/sys/fmt3.g" V{abs(var.dev)}
    set var.sDev = global.fmt
    M98 P"0:/sys/fmt3.g" V{global.tolXY}
    set var.t = var.L ^ " endstop not repeatable"
    set var.m = "Two homings differ by " ^ var.sDev ^ " mm (max " ^ global.fmt ^ ")."
    set var.m = var.m ^ " Check: " ^ var.L ^ " belt tension, pulley screws, switch mounting."
  elif var.c == 11
    set var.t = "Z cannot home yet"
    set var.m = "X and Y are not homed, so the probe position is unknown."
  elif var.c == 12
    set var.t = "Bed probe pressed too early"
    set var.m = "The probe reads pressed 5 mm above the bed. Check: needle bent or dirty, flag fully open, nothing under the probe."
  else
    set var.t = "Bed probe gave no reading"
    set var.m = "The probe went down to the bed but gave no valid signal. Check: PEI sheet in place, probe cable, needle clean."
  if var.n >= 3
    set var.m = "Failed " ^ var.n ^ " times - check the " ^ (param.A == 2 ? "probe" : "endstop") ^ " mechanics before trying again. " ^ var.m
  if param.A != 2 && var.c != 5
    M18 X Y                     ; XY motors off: the toolhead can be moved by hand (both axes lost on CoreXY)
    set var.xNeed = true
    set var.m = var.m ^ " X/Y motors are off - you can move the toolhead by hand. Heaters on, Z unchanged."
  elif var.c == 5
    set var.m = var.m ^ " Motors stay on."
  elif var.c == 11
    set var.m = var.m ^ " Heaters stay on."
  else
    set var.m = var.m ^ " Heaters and motors stay on."
  M98 P"0:/sys/msg.g" S{"ERROR " ^ var.t} L{"ERROR homing " ^ var.L ^ ": " ^ global.homeErr ^ " (home_xy.g / home_z.g)"}
  M300 S2500 P300
  M300 S1800 P300
  ; --- window: act = again / test / continue / limit / homexy / cancel ---
  M98 P"0:/sys/op_wait.g" S1 W"operator"
  set var.act = ""
  while var.act == ""
    G4 P400                     ; PanelDue misses a new box right after closing one (test 2026-10-19)
    if var.c == 5
      if var.bk == ""
        M291 P{var.m} R{var.t} S4 K{"Rehome", "Continue", "Set limit", var.cancel}
      else
        M291 P{var.m} R{var.t} S4 K{"Rehome", "Continue", "Set limit", var.cancel, var.bk}
      set var.k = input
      set var.act = (var.k == 0) ? "again" : ((var.k == 1) ? "continue" : ((var.k == 2) ? "limit" : ((var.k == 4) ? "back" : "cancel")))
    elif var.c == 11
      if var.bk == ""
        M291 P{var.m} R{var.t} S4 K{"Home", var.cancel}
      else
        M291 P{var.m} R{var.t} S4 K{"Home", var.cancel, var.bk}
      set var.act = (input == 0) ? "homexy" : ((input == 2) ? "back" : "cancel")
    elif param.A == 2
      if var.bk == ""
        M291 P{var.m} R{var.t} S4 K{"Rehome", "Test", var.cancel}
      else
        M291 P{var.m} R{var.t} S4 K{"Rehome", "Test", var.cancel, var.bk}
      set var.k = input
      set var.act = (var.k == 0) ? "again" : ((var.k == 1) ? "test" : ((var.k == 3) ? "back" : "cancel"))
    else
      if var.bk == ""
        M291 P{var.m} R{var.t} S4 K{"Rehome", "Test " ^ var.L, var.cancel}
      else
        M291 P{var.m} R{var.t} S4 K{"Rehome", "Test " ^ var.L, var.cancel, var.bk}
      set var.k = input
      set var.act = (var.k == 0) ? "again" : ((var.k == 1) ? "test" : ((var.k == 3) ? "back" : "cancel"))
    if var.act == "test"
      if param.A == 2
        M98 P"0:/sys/probe_test.g" B"Back"
      else
        M98 P"0:/sys/endstop_test.g" A{global.homeErrAxis}
      set var.act = ""
    elif var.act == "limit"
      var oldTol = global.tolXY
      M98 P"0:/sys/tol_ask.g" S"tolXY" V{global.tolXY} A{global.tolXYR[0]} B{global.tolXYR[1]} L{global.tolXYR[2]} H{global.tolXYR[3]} T{var.L ^ " ENDSTOP - CHANGE LIMIT"}
      if global.tolAskVal >= 0
        set global.tolXY = global.tolAskVal
        M98 P"0:/sys/tol_save.g" S"tolXY" V{var.oldTol} N{global.tolXY}
      set var.act = (global.tolAskVal >= 0 && abs(var.dev) <= global.tolXY) ? "accepted" : ""
  M98 P"0:/sys/op_wait.g" S0
  if var.act == "cancel"
    abort "Homing stopped by operator"
  if var.act == "back"
    set global.piBack = global.piStage - 1
    M98 P"0:/sys/msg.g" S{"Operator: " ^ var.bk}
    M99
  if var.act == "continue" || var.act == "accepted"
    if var.act == "continue"
      M98 P"0:/sys/msg.g" S{"WARNING " ^ var.L ^ " endstop repeat " ^ var.sDev ^ " mm"} L{"WARNING " ^ var.L ^ " endstop repeatability (check B) " ^ var.sDev ^ " mm > tolXY - operator: Continue anyway"}
      M98 P"0:/sys/msg.g" S{" after print: check " ^ var.L ^ " belt/pulley"}
    if global.homeErrAxis == 0 && param.A == 3
      set var.xNeed = false     ; X accepted - continue with Y
    else
      break
  elif var.act == "homexy"
    M98 P"0:/sys/msg.g" S"Operator: home X/Y now"
    M913 X25 Y25
    M98 P"0:/sys/home_do.g" A3
    M913 X100 Y100
    if exists(global.piBack) && global.piBack > 0
      M99
    G1 X210 Y230 F6000          ; back to the Z probe point of homez.g (K0 at X200 Y190)
  else
    M98 P"0:/sys/msg.g" S{"Operator: home " ^ var.L ^ " again (" ^ (var.n + 1) ^ ")"}
    if param.A == 2 && move.axes[2].homed
      ; 261024 (pliki_33): a failed G30 may already have set Z homed (first fast tap); with Z homed RRF probes only
      ; down to Zmin - dive + trigger (about -4.3) -> after the gantry was moved the needle never reaches the bed.
      ; Z = max -> the next G30 travels the whole Z range like a first homing. Old Z zero invalid (check C skipped).
      G92 Z{move.axes[2].max}
      if exists(global.zRefValid)
        set global.zRefValid = false
  if param.A != 2
    M913 X25 Y25                ; reduced XY current again (motors may have been off)
