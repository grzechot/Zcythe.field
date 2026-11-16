; ztest_chk.g - tilt check for ztest12.g (pliki_58, 261113): K0 at the 4 leadscrew points, ONE slow dive each
; (G30 S-1, no motor correction), as sim_tilt.g but without waiting for the operator.
; Result: global.ztH[4] = trigger heights (LP, LT, PT, PP), global.ztChk = 0 ok, 1 K0 closed, 2 no reading.
if !exists(global.ztH)
  global ztH = vector(4, 0)
if !exists(global.ztChk)
  global ztChk = 0
set global.ztChk = 0
var px = {10, 10, 380, 380}
var py = {5, 360, 360, 5}
var ox = sensors.probes[0].offsets[0]
var oy = sensors.probes[0].offsets[1]
M558 K0 H5 F80 A1 T21000
G90
while iterations < 4
  G1 Z6 F960
  G1 X{var.px[iterations] - var.ox} Y{var.py[iterations] - var.oy} F18000
  M400
  if sensors.probes[0].value[0] >= sensors.probes[0].threshold
    set global.ztChk = 1
    break
  G30 S-1
  if result != 0
    set global.ztChk = 2
    break
  set global.ztH[iterations] = sensors.probes[0].lastStopHeight
G1 Z6 F960
G1 X205 Y235 F18000
M558 K0 H5:3 F120:80 T18000 A5 S0.01 R0.3     ; config.g values
