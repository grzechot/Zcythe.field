; zdir_step.g - one step of the direction-split Z drive sweep (pliki_67, 261115, Gregor): N cycles up/down,
; the UP move with its own speed/accel/jerk, the DOWN move with its own. Driven by tools\zdir_sweep.py (step loss
; measured outside: ztest_chk.g before and after). Z only, no XY, no probing.
; M98 P"0:/sys/zdir_step.g" U<up mm/s> A<up mm/s^2> J<up mm/min> D<down mm/s> C<down mm/s^2> K<down mm/min>
;        [S<stroke mm, 1>] [N<cycles, 50>] [B<lower Z mm, 30>] [R1 = LIS3DH records the first ~2 s] [F"<file>"]
; No M400 between the moves: M201/M203/M566 are taken when a move is queued, so each move is planned with its own set
; and the reversal into it (junction speed) is limited by its own jerk: down->up reversal = up jerk, up->down = down jerk.
; Config Z limits are restored at the end. After an abort inside the cycles zdir_sweep.py restores them.
if !exists(param.U) || !exists(param.A) || !exists(param.J) || !exists(param.D) || !exists(param.C) || !exists(param.K)
  abort "zdir_step: U A J (up) and D C K (down) are required"
if job.file.fileName != null
  abort "zdir_step: not during a print"
if !move.axes[2].homed
  abort "zdir_step: home Z first"
var s = exists(param.S) ? param.S : 1
var n = exists(param.N) ? param.N : 50
var b = exists(param.B) ? param.B : 30
if var.b < 6 || var.b + var.s > move.axes[2].max - 3 || var.s <= 0
  abort "zdir_step: stroke outside Z 6.." ^ (move.axes[2].max - 3) ^ " mm"
var oV = move.axes[2].speed               ; mm/min (as M203)
var oA = move.axes[2].acceleration        ; mm/s^2
var oJ = move.axes[2].jerk                ; mm/min (as M566)
var fu = param.U * 60
var fd = param.D * 60
G90
G1 Z{var.b} F{var.oV}                     ; start height with the config limits
M400
if exists(param.R) && param.R == 1 && exists(boards[0].accelerometer) && boards[0].accelerometer != null
  M956 P0 S2688 A1 F{exists(param.F) ? param.F : "zd/step.csv"}   ; ~2 s at 1344 Hz, starts at once
var t0 = state.upTime
while iterations < var.n
  M203 Z{var.fu}
  M201 Z{param.A}
  M566 Z{param.J}
  G1 Z{var.b + var.s} F{var.fu}
  M203 Z{var.fd}
  M201 Z{param.C}
  M566 Z{param.K}
  G1 Z{var.b} F{var.fd}
M400
M203 Z{var.oV}
M201 Z{var.oA}
M566 Z{var.oJ}
echo "zdir_step done: up V" ^ param.U ^ " A" ^ param.A ^ " J" ^ param.J ^ ", down V" ^ param.D ^ " A" ^ param.C ^ " J" ^ param.K ^ ", " ^ var.n ^ " x " ^ var.s ^ " mm from Z" ^ var.b ^ ", " ^ (state.upTime - var.t0) ^ " s"
