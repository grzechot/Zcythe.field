; mesh_ask.g - operator window when a bed map point fails (macro Mesh), task 15, 2026-10-22
; Params: K = 0 map point / 1 check point, X Y = point, N = 1 when K0 did not touch the bed (else: dives disagree).
; Try point again -> returns (Mesh probes the point again); Test probe manually -> probe_test.g, window again;
; Cancel -> abort. Wait timers: op_wait.g.
var cancel = (job.file.fileName != null) ? "Cancel" : "Stop"
var t = (param.K == 1) ? "Map check point failed" : "Bed map point failed"
var p = "X" ^ param.X ^ " Y" ^ param.Y
var m = ""
if param.N == 1
  set var.m = "The probe did not touch the bed at " ^ var.p ^ ". Check: PEI sheet in place there, probe needle."
else
  set var.m = "Probe readings at " ^ var.p ^ " disagree. Cause: dirt or filament on the bed there, or a dirty probe needle."
  set var.m = var.m ^ " Clean that spot, then try again."
set var.m = var.m ^ " Heaters and motors stay on."
M98 P"0:/sys/msg.g" S{"ERROR " ^ (param.K == 1 ? "map check point " : "bed map point ") ^ var.p} L{"ERROR Mesh: " ^ (param.N == 1 ? "K0 no trigger down to 2 mm below the expected bed" : "no 2 agreeing K0 dives (0.01 mm)") ^ " at " ^ var.p}
M300 S2500 P300
M300 S1800 P300
M98 P"0:/sys/op_wait.g" S1 W"operator"
var k = 1
while var.k == 1
  G4 P400
  M291 P{var.m} R{var.t} S4 K{"Retry", "Test", var.cancel}
  set var.k = input
  if var.k == 1
    M98 P"0:/sys/probe_test.g" B"Back"
M98 P"0:/sys/op_wait.g" S0
if var.k == 2
  abort "Bed map stopped by operator"
M98 P"0:/sys/msg.g" S"Operator: try point again"
