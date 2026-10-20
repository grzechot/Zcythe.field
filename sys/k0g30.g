; k0g30.g - one G30 with K0 for bed.g, protected against a closed / prematurely triggered K0
; Call: M98 P"0:/sys/k0g30.g" N<point> X<x> Y<y> [S<s>]   (no parameters = plain G30 at the current position)
; Before EVERY G30: K0 must be open (deployprobe0.g shows "Manual Deploy" and waits). After G30: result != 0 = failed,
; the SAME point is repeated (max 6 tries). Then a full-screen window: OK = try this point again, Cancel = stop.
; Probe settings (speeds, dive heights) are set by bed.g.
var pt = exists(param.N) ? ("point " ^ param.N) : "Z0 point"
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
        M98 P"0:/sys/msg.g" S{"K0 was triggered - Z lifted " ^ (var.up * 5) ^ " mm"}
      M98 P"0:/sys/deployprobe0.g"
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
  M98 P"0:/sys/msg.g" S{"ERROR K0 failed 6x at " ^ var.pt}
  M300 S2500 P300
  M300 S1800 P300
  M291 P{"K0 failed 6 times at " ^ var.pt ^ " (closes too early?). Check K0, then OK = try again, Cancel = stop."} R"LEVELING ERROR" S3
  M98 P"0:/sys/msg.g" S{"Repeating " ^ var.pt}
