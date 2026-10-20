; home_zshift.g - check C: Z zero shift since the previous homing
; One G38.3 dive with K0 in the OLD Z frame (nothing is changed, no firmware "Stopped at height" line);
; shift = Z at trigger - G31 Z. Called by home_z.g just before G30. Result in global.homeZShift (-999 = n/a).
; G28 clears the "homed" flags BEFORE homeall.g/homez.g run, so move.axes[2].homed cannot tell whether an old
; Z zero exists. global.zRefValid (set by home_z.g after a good Z homing, gone after power-off/reset) is used instead.
; Note: a G32 since the last homing also moves Z at the probe point - the shift then includes levelling.
var spd = 80                    ; [mm/min] dive speed = fine speed of the homing G30 (M558 F120:80)
if !exists(global.homeZShift)
  global homeZShift = -999
set global.homeZShift = -999
if !exists(global.zRefValid) || !global.zRefValid
  M99                           ; power-on / first homing: no old zero to compare
; reference = G31 used by the PREVIOUS Z homing (global.zRefG31): HesCal2 may change G31 before its G28 Z - that is
; not a Z shift. Fallback: current G31.
var g31 = (exists(global.zRefG31) ? global.zRefG31 : sensors.probes[0].triggerHeight)
; fast down to G31 + 3 mm (old frame; H2 because Z is flagged not homed during G28)
var dz = var.g31 + 3 - move.axes[2].userPosition
if var.dz < 0
  G91
  G1 H2 Z{var.dz} F600
  G90
M400
G38.3 K0 Z{var.g31 - 1.5} F{var.spd}   ; stop at K0 trigger, max 1.5 mm below the expected point
var ok = (result == 0) && sensors.probes[0].value[0] > 0
M400
if var.ok
  set global.homeZShift = move.axes[2].userPosition - var.g31
G91
G1 H2 Z3 F600                   ; lift so the probe is clear before the real G30
G90
