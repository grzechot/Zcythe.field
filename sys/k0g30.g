; k0g30.g - one G30 with K0 for bed.g, protected against a closed / prematurely triggered K0
; Call: M98 P"0:/sys/k0g30.g" N<point> X<x> Y<y> [S<s>]   (no parameters = plain G30 at the current position)
; Before EVERY G30: K0 must be open (deployprobe0.g shows "Manual Deploy" and waits). After G30: result != 0 = failed,
; the SAME point is repeated (max 6 tries). Then a full-screen window: OK = try this point again, Cancel = stop.
; Probe settings (speeds, dive heights) are set by bed.g.
; 2026-10-22 (task 15): operator texts; window Try point again / Test probe manually / Cancel print; K0 closed
; during levelling -> deployprobe0.g C"leveling". Probing unchanged.
var pt = exists(param.N) ? ("point " ^ param.N) : "Z0 point"
var ptT = exists(param.N) ? ("point " ^ (param.N + 1)) : "Z zero point"
var ptL = ""
if exists(param.N)
  set var.ptL = "point " ^ (param.N + 1) ^ " of 4 (X" ^ param.X ^ " Y" ^ param.Y ^ ")"
else
  set var.ptL = "the Z zero point (X" ^ floor(move.axes[0].userPosition + sensors.probes[0].offsets[0] + 0.5)
  set var.ptL = var.ptL ^ " Y" ^ floor(move.axes[1].userPosition + sensors.probes[0].offsets[1] + 0.5) ^ ")"
var cancel = (job.file.fileName != null) ? "Cancel" : "Stop"
var bk = (exists(global.piBackLbl) && exists(global.piRun) && global.piRun && job.file.fileName != null) ? global.piBackLbl : ""   ; 261024 (pliki_36): krok wstecz w PrintInit
if exists(global.piBack) && global.piBack > 0
  M99                          ; 261024 (pliki_36): operator step back - start.g repeats an earlier step
var nf = 0
var tries = 0
var ok = false
while true
  set var.tries = 0
  while !var.ok && var.tries < 6
    if sensors.probes[0].value[0] >= sensors.probes[0].threshold
      ; 2026-10-19: K0 may be pressed against the bed (skewed gantry) - lift up to 3 x 5 mm before asking the operator
      var up = 0
      while sensors.probes[0].value[0] >= sensors.probes[0].threshold && var.up < 3
        G91
        G1 H2 Z5 F600
        G90
        M400
        set var.up = var.up + 1
      if var.up > 0
        M98 P"0:/sys/msg.g" S{"Bed probe touched early - Z up " ^ (var.up * 5) ^ " mm"} L{"K0 was triggered before " ^ var.pt ^ " - Z lifted " ^ (var.up * 5) ^ " mm"}
      M98 P"0:/sys/deployprobe0.g" C"leveling"
    if exists(param.N)
      if exists(param.S)
        G30 P{param.N} X{param.X} Y{param.Y} Z-99999 S{param.S}
      else
        G30 P{param.N} X{param.X} Y{param.Y} Z-99999
    else
      G30
    if result == 0
      set var.ok = true
    set var.tries = var.tries + 1
  if var.ok
    break
  set var.nf = var.nf + 1
  M98 P"0:/sys/msg.g" S{"ERROR bed probe failed at " ^ var.ptT} L{"ERROR K0 failed 6 times at " ^ var.pt ^ " (G30 result != 0)"}
  M300 S2500 P300
  M300 S1800 P300
  var m = "The probe gave no valid reading 6 times at " ^ var.ptL ^ "."
  set var.m = var.m ^ " Check: probe flag closes too early (shocks), needle dirty, something on the bed there. Heaters and motors stay on."
  var k = 1
  M98 P"0:/sys/op_wait.g" S1 W"operator"
  while var.k == 1
    G4 P400
    if var.bk == ""
      M291 P{var.m} R{"Bed probe failed at " ^ var.ptT} S4 K{"Retry", "Test", var.cancel}
    else
      M291 P{var.m} R{"Bed probe failed at " ^ var.ptT} S4 K{"Retry", "Test", var.cancel, var.bk}
    set var.k = input
    if var.k == 1
      M98 P"0:/sys/probe_test.g" B"Back"
  M98 P"0:/sys/op_wait.g" S0
  if var.k == 2
    abort "Leveling stopped by operator"
  if var.k == 3
    set global.piBack = global.piStage - 1
    M98 P"0:/sys/msg.g" S{"Operator: " ^ var.bk}
    M99
  M98 P"0:/sys/msg.g" S{"Operator: try point again (" ^ (var.nf + 1) ^ ")"}
  set var.ok = false
