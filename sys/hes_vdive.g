; hes_vdive.g - najazd pionowy sondą K w punkcie X/Y: N zjazdów G38.3 z Z = S do limitu L (1 mm/s)
; Wynik: global.vdZ (średnia), global.vdR (rozrzut), global.vdOk. Wpisy do konsoli PanelDue.
; Q1 = bez wpisów do konsoli (mniej okien Response na PanelDue).
; Wywołujący odpowiada za zdefiniowanie sondy K (dla K1 - zwolnienie J2 i M558 K1).
if !exists(global.vdZ)
  global vdZ = 0
  global vdR = 0
  global vdOk = false
set global.vdOk = false
var n = exists(param.N) ? param.N : 3
var f = (param.K == 0) ? 120 : 60   ; dive speed [mm/min]: K0 120 = homing coarse speed (2026-10-16), K1 60
var sum = 0
var zmn = 999
var zmx = -999
var z = 0
var i = 0
G90
G1 Z6 F600
G1 X{param.X} Y{param.Y} F6000
M400
while var.i < var.n
  set var.i = var.i + 1
  G1 Z{param.S} F600
  M400
  if sensors.probes[param.K].value[0] >= sensors.probes[param.K].threshold
    M98 P"0:/sys/hes_log.g" S{"ERROR K" ^ param.K ^ " triggered before dive"}
    G1 Z6 F600
    M99
  G38.3 K{param.K} Z{param.L} F{var.f}
  M400
  set var.z = move.axes[2].machinePosition
  ; zadziałanie = stan czujnika po zjeździe (pozycja Z zaokrąglana do mikrokroku)
  if sensors.probes[param.K].value[0] < sensors.probes[param.K].threshold
    G1 Z6 F600
    M98 P"0:/sys/hes_log.g" S{"ERROR K" ^ param.K ^ " no trigger down to Z" ^ param.L}
    M99
  set var.sum = var.sum + var.z
  set var.zmn = min(var.zmn, var.z)
  set var.zmx = max(var.zmx, var.z)
  if !exists(param.Q)
    M98 P"0:/sys/hes_log.g" S{"K" ^ param.K ^ " dive " ^ var.i ^ ": Z" ^ var.z}
G1 Z6 F600
M400
set global.vdZ = var.sum / var.n
set global.vdR = var.zmx - var.zmn
set global.vdOk = true
