; bed.g - bed levelling (G32): 4 Z motors corrected from K0 at the 4 leadscrew points
; Homing is NOT done here - start.g does it (only when axes are not homed) or a manual G28.
; Passes: at least 2, more until the deviation before correction <= 0.02 mm (max 6). Not converged -> full-screen
; window: OK = level again, Cancel = stop (heaters keep running). Then Z0 is set again with K0 at X193 Y195.
; K0 probing = homing values (decision 2026-10-16): M558 K0 H5:3 F120:80 A5 S0.01.
; Summary in both consoles (msg.g): passes, deviation per pass, time. levelDone = true only after convergence.
M561                        ; clear old bed transforms
if !move.axes[0].homed || !move.axes[1].homed || !move.axes[2].homed
  abort "bed.g: axes not homed - run G28 first (start.g does it)"
if !exists(global.levelDone)
  global levelDone = false
set global.levelDone = false   ; levelling in progress - set true only at the very end
if !exists(global.bedDevs)
  global bedDevs = ""
if !exists(global.bedPasses)
  global bedPasses = 0
var t0 = state.upTime
M98 P"0:/sys/tolerances.g"
var tol = global.tolBed     ; [mm] deviation before correction that counts as level (tolBed in 0:/sys/tolerances.g)
var maxPasses = 6

; gentler carriage dynamics during levelling (K0 has a very light trigger and closed early from shocks);
; restored at the end, after abort/Cancel it stays gentle until restart (safe direction)
var ax = move.axes[0].acceleration    ; mm/s^2
var ay = move.axes[1].acceleration
var jx = move.axes[0].jerk            ; mm/min (as M566)
var jy = move.axes[1].jerk
M201 X1500 Y1500
M566 X300 Y300
G91
G92 U0
G1 H2 Z15 F6000             ; 2026-10-19: 15 mm (was 5) - after mechanical work the gantry can be skewed by several mm
M401
G90
M561
M98 P"0:/sys/deployprobe0.g"   ; K0 must be open before the first point (waits for the operator)
M558 K0 H5:3 F120:80 A5 S0.01 T21000

while true
  set global.bedDevs = ""
  set global.bedPasses = 0
  M558 K0 H15:3 F120:80 A5 S0.01 T21000   ; pass 1: dive from 15 mm (skewed gantry, 2026-10-19)
  M98 P"0:/sys/bed_pass.g"     ; pass 1 - coarse correction
  M558 K0 H5:3 F120:80 A5 S0.01 T21000    ; next passes: homing values again
  M561
  M98 P"0:/sys/bed_pass.g"     ; pass 2
  while move.calibration.initial.deviation > var.tol && global.bedPasses < var.maxPasses
    M98 P"0:/sys/bed_pass.g"
  if move.calibration.initial.deviation <= var.tol
    break
  M98 P"0:/sys/fmt3.g" V{move.calibration.initial.deviation}
  M98 P"0:/sys/msg.g" S{"ERROR bed dev " ^ global.fmt ^ " > tolBed " ^ var.tol}
  M98 P"0:/sys/msg.g" S{"Dev:" ^ global.bedDevs}
  M300 S2500 P300
  M300 S1800 P300
  M291 P{"Bed not level after " ^ global.bedPasses ^ " passes: deviation " ^ global.fmt ^ " > " ^ var.tol ^ " mm (tolBed in 0:/sys/tolerances.g). OK = level again, Cancel = stop."} R"LEVELING ERROR" S3
  M98 P"0:/sys/msg.g" S"Repeating bed levelling"

G4 P500                     ; let the mechanics settle
G1 X205 Y235 F9000          ; nozzle -> K0 at X193 Y195
M98 P"0:/sys/k0g30.g"       ; final Z0 after levelling

M558 K0 H5:3 F120:80 T18000 A5 S0.01 R0.3   ; probe settings back to config.g
M557 X5:400 Y10:370 P6:6
G1 Z2
M201 X{var.ax} Y{var.ay}    ; restore dynamics from before levelling
M566 X{var.jx} Y{var.jy}
set global.levelDone = true    ; levelled - start.g skips G32 until something homes the axes

M98 P"0:/sys/msg.g" S{"-- LEVELING DONE  " ^ (state.upTime - var.t0) ^ " s --"}
M98 P"0:/sys/msg.g" S{"Passes: " ^ global.bedPasses ^ "  tolBed " ^ var.tol}
M98 P"0:/sys/msg.g" S{"Dev:" ^ global.bedDevs}
