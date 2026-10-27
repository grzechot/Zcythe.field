; printinit_cfg.g - PrintInit: timers while the printer waits for the operator (window, bed probe) [min]
; Used by op_wait.g and daemon.g (task 15, 2026-10-22, operator). Edit here.
if !exists(global.piWaitHeatOff)
  global piWaitHeatOff = 30
if !exists(global.piWaitMotorsOff)
  global piWaitMotorsOff = 30
if !exists(global.piWaitRemind)
  global piWaitRemind = 5
set global.piWaitHeatOff = 30     ; no answer for this long -> heaters off (bed and nozzle)
set global.piWaitMotorsOff = 30   ; then this much longer -> motors off (everything off)
set global.piWaitRemind = 5       ; reminder every N min: beep + console line with the waiting time
