; zhop4_step.g - Z-hop split into 4 phases, each with its own acceleration (pliki_69, 261116, Gregor).
; Trident: Z+ = bed DOWN (nozzle leaves the part), Z- = bed UP (back to the layer).
;   phase 1: bed down, accelerate  (A1)     phase 2: bed down, brake (A2)
;   phase 3: bed up,   accelerate  (A3)     phase 4: bed up,   brake (A4)
; Each direction = 2 collinear moves, no M400 between them. M201/M566 are taken when a move is queued, so move 1
; accelerates with its own A and move 2 decelerates with its own A. Split point s1/s2 = A2/A1 (resp. A4/A3), so the peak
; speed falls exactly on the junction (collinear junction - no jerk limit there). Jerk J only at start, top reversal, landing.
; M98 P"0:/sys/zhop4_step.g" A<1> C<2> D<3> H<4> J<mm/min> [V<down mm/s, 13.2>] [U<up mm/s, 13.2>]
;        [S<stroke mm, 0.4>] [N<cycles, 50>] [B<lower Z mm, 30>] [W<dwell after landing ms, 0>]
;        [R1 = LIS3DH records ~2 s from the start] [F"<file>"]
; (letters: A,C,D,H = phases 1..4; M,G,E,T,P are avoided as M98 parameters)
; Driven by tools\zhop4_sweep.py (step loss measured outside: ztest_chk.g before and after).
if !exists(param.A) || !exists(param.C) || !exists(param.D) || !exists(param.H) || !exists(param.J)
  abort "zhop4_step: A C D H (phases 1-4) and J are required"
if job.file.fileName != null
  abort "zhop4_step: not during a print"
if !move.axes[2].homed
  abort "zhop4_step: home Z first"
var s = exists(param.S) ? param.S : 0.4
var n = exists(param.N) ? param.N : 50
var b = exists(param.B) ? param.B : 30
var w = exists(param.W) ? param.W : 0
if var.b < 6 || var.b + var.s > move.axes[2].max - 3 || var.s <= 0
  abort "zhop4_step: stroke outside Z 6.." ^ (move.axes[2].max - 3) ^ " mm"
var oV = move.axes[2].speed               ; mm/min (as M203)
var oA = move.axes[2].acceleration        ; mm/s^2
var oJ = move.axes[2].jerk                ; mm/min (as M566)
var fd = (exists(param.V) ? param.V : 13.2) * 60
var fu = (exists(param.U) ? param.U : 13.2) * 60
var fm = max(var.fd, var.fu)
var s1 = var.s * param.C / (param.A + param.C)    ; bed-down accel part
var s3 = var.s * param.H / (param.D + param.H)    ; bed-up accel part
G90
G1 Z{var.b} F{var.oV}                     ; start height with the config limits
M400
M203 Z{var.fm}
M566 Z{param.J}
if exists(param.R) && param.R == 1 && exists(boards[0].accelerometer) && boards[0].accelerometer != null
  M956 P0 S2688 A1 F{exists(param.F) ? param.F : "zh/step.csv"}   ; ~2 s at 1344 Hz, starts at once
var t0 = state.upTime
var t0ms = state.msUpTime
while iterations < var.n
  M201 Z{param.A}
  G1 Z{var.b + var.s1} F{var.fd}          ; 1 bed down, accelerate
  M201 Z{param.C}
  G1 Z{var.b + var.s} F{var.fd}           ; 2 bed down, brake
  M201 Z{param.D}
  G1 Z{var.b + var.s - var.s3} F{var.fu}  ; 3 bed up, accelerate
  M201 Z{param.H}
  G1 Z{var.b} F{var.fu}                   ; 4 bed up, brake (landing)
  if var.w > 0
    G4 P{var.w}
M400
var dt = (state.upTime - var.t0) * 1000 + (state.msUpTime - var.t0ms)
M203 Z{var.oV}
M201 Z{var.oA}
M566 Z{var.oJ}
echo "zhop4_step done: A" ^ param.A ^ " C" ^ param.C ^ " D" ^ param.D ^ " H" ^ param.H ^ " J" ^ param.J ^ ", " ^ var.n ^ " x " ^ var.s ^ " mm from Z" ^ var.b ^ ", ms " ^ var.dt
