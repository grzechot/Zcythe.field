; endstop_test.g - "Test endstop X/Y manually" from the homing error window (task 15, 2026-10-22). No motion.
; A = 0 (X) or 1 (Y). The operator presses the switch by hand and lets go; result in the console and a window.
var L = (param.A == 0) ? "X" : "Y"
var t0 = state.upTime
var pressed = false
var released = false
M292
G4 P400
M291 P{"Press the " ^ var.L ^ " endstop by hand and let go. Waiting 30 s..."} R{"Test endstop " ^ var.L} S0 T35
while state.upTime - var.t0 < 30 && !var.released
  G4 P100
  if sensors.endstops[param.A].triggered
    set var.pressed = true
  elif var.pressed
    set var.released = true
M292
var r = var.L ^ " endstop: no signal - check cable"
if var.released
  set var.r = var.L ^ " endstop works"
  M300 S2500 P300
elif var.pressed
  set var.r = var.L ^ " endstop stays pressed - check lever"
M98 P"0:/sys/msg.g" S{var.r}
G4 P400
M291 P{var.r ^ "."} R{"Test endstop " ^ var.L ^ ": result"} S4 K{"Back",}
