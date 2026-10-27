; homez.g - home Z with K0; checked, on error a window and repeat (home_do.g); summary (home_sum.g)
if !exists(global.skipCal)
  global skipCal = false
if !exists(global.levelDone)
  global levelDone = false
if !exists(global.homeT0)
  global homeT0 = 0
set global.homeT0 = state.upTime
if exists(global.piBack) && global.piBack > 0
  M99                          ; 261024 (pliki_36): operator step back - start.g repeats an earlier step
; 2026-10-22 (task 15): stage line; none inside HesCal2 (global.hesQuiet - one summary line in home_sum.g)
if exists(global.piRun) && global.piRun && job.file.fileName != null && !(exists(global.hesQuiet) && global.hesQuiet)
  M98 P"0:/sys/msg.g" S"[3/10] Homing Z"
elif !(exists(global.hesQuiet) && global.hesQuiet)
  M98 P"0:/sys/msg.g" S"Homing Z"
set global.skipCal = false    ; any homing (even one axis) invalidates skipCal: the endstop may give a slightly
                               ; different zero, so a fresh calibration is forced on the next start
set global.levelDone = false  ; same for levelling (bed.g): after homing the bed must be levelled again
G29 S2              ; mesh off - an active mesh breaks homing and would distort check C
G91
G1 H2 Z5 F6000      ; lift Z relative to current position
G90
G1 X210 Y230 F6000  ; nozzle to probe point (K0 at X200 Y190)
M98 P"0:/sys/home_do.g" A2
if exists(global.piBack) && global.piBack > 0
  M99                          ; 261024 (pliki_36): operator step back - start.g repeats an earlier step
M98 P"0:/sys/home_sum.g" A"Z"
