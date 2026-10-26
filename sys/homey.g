; homey.g - home Y; checked, on error a window and repeat (home_do.g); one-line summary
if !exists(global.skipCal)
  global skipCal = false
if !exists(global.levelDone)
  global levelDone = false
if !exists(global.homeT0)
  global homeT0 = 0
set global.homeT0 = state.upTime
if exists(global.piBack) && global.piBack > 0
  M99                          ; 261024 (pliki_36): operator step back - start.g repeats an earlier step
; 2026-10-22 (task 15): stage line (in PrintInit homex.g prints "Homing X, Y")
if !(exists(global.piRun) && global.piRun && job.file.fileName != null)
  M98 P"0:/sys/msg.g" S"Homing Y"
set global.skipCal = false    ; any homing (even one axis) invalidates skipCal: the endstop may give a slightly
                               ; different zero, so a fresh calibration is forced on the next start
set global.levelDone = false  ; same for levelling (bed.g): after homing the bed must be levelled again
M400
M913 X25 Y25            ; reduced XY motor current for homing
M98 P"0:/sys/home_do.g" A1
M913 X100 Y100
if exists(global.piBack) && global.piBack > 0
  M99                          ; 261024 (pliki_36): operator step back - start.g repeats an earlier step
M98 P"0:/sys/home_sum.g" A"Y"
