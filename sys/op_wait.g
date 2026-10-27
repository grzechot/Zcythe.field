; op_wait.g - the printer waits for the operator (window or bed probe); timers run in daemon.g (task 15, 2026-10-22)
; S1 W"<what>" = waiting starts (call just before the window / wait loop). W = text for the reminder line.
; S0 = the operator answered. If the timer switched the heaters off: heaters on again, bed warm-up again (bedsoak.g R1),
;      nozzle back to temperature. If the timer switched the motors off: positions are lost - stop with a message.
; Timers and reminder period: 0:/sys/printinit_cfg.g.
if !exists(global.opWaitSince)
  global opWaitSince = -1
if !exists(global.opWaitWhat)
  global opWaitWhat = ""
if !exists(global.opHeatOff)
  global opHeatOff = false
if !exists(global.opMotorsOff)
  global opMotorsOff = false
if !exists(global.opBed)
  global opBed = 0
if !exists(global.opRemind)
  global opRemind = 0
M98 P"0:/sys/printinit_cfg.g"
if param.S == 1
  if global.opWaitSince < 0         ; nested waits keep the first start time
    set global.opWaitSince = state.upTime
    set global.opRemind = state.upTime
    set global.opHeatOff = false
    set global.opMotorsOff = false
  set global.opWaitWhat = exists(param.W) ? param.W : "operator"
  M99
; S0 - operator answered
set global.opWaitSince = -1
if global.opMotorsOff
  set global.opHeatOff = false
  set global.opMotorsOff = false
  M98 P"0:/sys/msg.g" S"Motors were off - start again" L"Motors were switched off by the wait timer (printinit_cfg.g) - axis positions lost; start the print again"
  abort "Motors were off - start the print again"
if global.opHeatOff
  set global.opHeatOff = false
  M98 P"0:/sys/msg.g" S"Heaters back on - warming up" L"Heaters were switched off by the wait timer (printinit_cfg.g) - heating again, bed warm-up again"
  if global.opBed > 0
    M140 S{global.opBed}
  M568 P0 A2                        ; nozzle: active temperature as before (stored by RRF)
  if global.opBed > 0
    M98 P"0:/sys/bedsoak.g" B{global.opBed} R1
  M116 P0
