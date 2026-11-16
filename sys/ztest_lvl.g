; ztest_lvl.g - levelling for ztest12.g WITHOUT operator windows (pliki_58, 261113)
; As bed.g: K0 at the 4 leadscrew points, G30 ... S4 corrects the 4 Z motors; up to 6 passes, done when the
; deviation before correction <= 0.02 mm (pass 2 or later). Then Z0 with K0 at the centre (G30).
; Result: global.ztLvl = last deviation [mm], -1 = probe failure (caller ends the test, no window).
if !exists(global.ztLvl)
  global ztLvl = -1
set global.ztLvl = -1
var px = {10, 10, 380, 380}
var py = {5, 360, 360, 5}
var pass = 0
var ok = true
var dev = -1
M561
G90
G1 Z15 F960
while var.pass < 6
  set var.pass = var.pass + 1
  if var.pass == 1
    M558 K0 H15:3 F120:80 A5 S0.01 T21000   ; first pass from 15 mm (gantry may be tilted)
  else
    M558 K0 H5:3 F120:80 A5 S0.01 T21000
  while iterations < 4
    if sensors.probes[0].value[0] >= sensors.probes[0].threshold
      G91
      G1 H2 Z5 F600
      G90
    if iterations < 3
      G30 P{iterations} X{var.px[iterations]} Y{var.py[iterations]} Z-99999
    else
      G30 P3 X{var.px[3]} Y{var.py[3]} Z-99999 S4
    if result != 0
      set var.ok = false
      break
  if !var.ok
    break
  set var.dev = move.calibration.initial.deviation
  if var.dev <= 0.02 && var.pass >= 2
    break
M558 K0 H5:3 F120:80 T18000 A5 S0.01 R0.3     ; config.g values
if var.ok
  G1 Z6 F960
  G1 X205 Y235 F18000                         ; nozzle -> K0 at X193 Y195 (as bed.g)
  G30
  if result != 0
    set var.ok = false
G1 Z6 F960
if var.ok
  set global.ztLvl = var.dev
echo >>"0:/sys/ztest12.csv" state.time ^ ",level,passes " ^ var.pass ^ ",,,,,,,,,,,," ^ var.dev ^ "," ^ (var.ok ? "level ok" : "level FAILED") ^ "," ^ boards[0].freeRam ^ ","
