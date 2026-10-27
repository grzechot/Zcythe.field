; homeall.g - home X, Y, Z; each axis checked, on error a window and repeat (home_do.g); summary (home_sum.g)
if !exists(global.skipCal)
  global skipCal = false
if !exists(global.levelDone)
  global levelDone = false
if !exists(global.homeT0)
  global homeT0 = 0
set global.homeT0 = state.upTime
M98 P"0:/sys/msg.g" S"Homing X, Y, Z"   ; 2026-10-22 (task 15): stage line
set global.skipCal = false    ; any homing (even one axis) invalidates skipCal: the endstop may give a slightly
                               ; different zero, so a fresh calibration is forced on the next start
set global.levelDone = false  ; same for levelling (bed.g): after homing the bed must be levelled again
; stage timers [s] (global.homeTa..homeTz, read by tools - not printed)
if !exists(global.homeTa)
  global homeTa = 0.0
if !exists(global.homeTxy)
  global homeTxy = 0.0
if !exists(global.homeTc0)
  global homeTc0 = 0.0
if !exists(global.homeTc1)
  global homeTc1 = 0.0
if !exists(global.homeTz)
  global homeTz = 0.0
set global.homeTa = state.upTime + state.msUpTime / 1000
G29 S2                  ; mesh off - an active mesh breaks homing and would distort check C
G92 U0
G91
G1 H2 Z20 F600          ; raise head 20 mm (individual Z motors, no homing needed)
G90
M913 X25 Y25            ; reduced XY motor current for homing
M98 P"0:/sys/home_do.g" A3   ; X then Y, checked (endstop reached/released, check B)
if exists(global.piBack) && global.piBack > 0
  M913 X100 Y100
  M99
set global.homeTxy = state.upTime + state.msUpTime / 1000
M913 X100 Y100
G1 X160 Y170 F15000     ; nozzle to probe point (K0 at X150 Y130)
M98 P"0:/sys/home_do.g" A2   ; Z with K0, checked (check C inside)
if exists(global.piBack) && global.piBack > 0
  M99                          ; 261024 (pliki_36): operator step back - start.g repeats an earlier step
M98 P"0:/sys/home_sum.g" A"all"
