; home_z.g - home Z with K0 at the current XY; result in global.homeErr ("" = OK, else error text)
; Called by home_do.g (retry loop). X and Y must be homed. Check C (Z zero shift) via home_zshift.g.
if !exists(global.homeErr)
  global homeErr = ""
set global.homeErr = ""
if !move.axes[0].homed || !move.axes[1].homed
  set global.homeErr = "Z: X/Y not homed"
  M99
M98 P"0:/sys/deployprobe0.g"    ; K0 must be deployed (waits for the operator if closed)
if sensors.probes[0].value[0] != 0
  set global.homeErr = "Z: K0 triggered before probing"
  M99
if exists(global.homeTc0)
  set global.homeTc0 = state.upTime + state.msUpTime / 1000
M98 P"0:/sys/home_zshift.g"     ; check C (G38.3 in the old frame, only when a Z zero exists)
if exists(global.homeTc1)
  set global.homeTc1 = state.upTime + state.msUpTime / 1000
G30                             ; probe, set Z to trigger height
if exists(global.homeTz)
  set global.homeTz = state.upTime + state.msUpTime / 1000
if result != 0 || !move.axes[2].homed
  set global.homeErr = "Z: G30 failed (K0)"
  M99
if !exists(global.zRefValid)
  global zRefValid = false
set global.zRefValid = true     ; a valid Z zero exists - next homing can measure check C
if !exists(global.zRefG31)
  global zRefG31 = 0
set global.zRefG31 = sensors.probes[0].triggerHeight   ; G31 of this zero - reference for check C next time
