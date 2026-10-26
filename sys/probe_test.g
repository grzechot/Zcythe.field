; probe_test.g - "Test probe manually" from the probe error windows (task 15, 2026-10-22). No motion.
; The operator pushes the K0 needle up by hand and lets go; result in the console and a window.
; B = text of the button that returns (default "Back").
var t0 = state.upTime
var pressed = false
var released = false
M292
G4 P400
M291 P"Push the probe needle up by hand and let go. Waiting 30 s..." R"Test the bed probe" S0 T35
while state.upTime - var.t0 < 30 && !var.released
  G4 P100
  if sensors.probes[0].value[0] >= sensors.probes[0].threshold
    set var.pressed = true
  elif var.pressed
    set var.released = true
M292
var r = "Bed probe: no signal - check cable"
if var.released
  set var.r = "Bed probe works"
  M300 S2500 P300
elif var.pressed
  set var.r = "Bed probe stays pressed - check needle"
M98 P"0:/sys/msg.g" S{var.r} L{var.r ^ " (K0 manual test, probe_test.g)"}
G4 P400
M291 P{var.r ^ "."} R"Test the bed probe: result" S4 K{(exists(param.B) ? param.B : "Back"),}
