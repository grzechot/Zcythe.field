; bed_pass.g - one G32 pass: K0 at the 4 leadscrew points, then Z motor correction (S4)
; Adds the deviation BEFORE this correction to global.bedDevs (text, 3 decimals) and counts global.bedPasses.
M98 P"0:/sys/k0g30.g" N0 X10 Y5
M98 P"0:/sys/k0g30.g" N1 X10 Y360
M98 P"0:/sys/k0g30.g" N2 X380 Y360
M98 P"0:/sys/k0g30.g" N3 X380 Y5 S4
if exists(global.piBack) && global.piBack > 0
  M99                          ; 261024 (pliki_36): operator step back - start.g repeats an earlier step
M98 P"0:/sys/fmt3.g" V{move.calibration.initial.deviation}
set global.bedDevs = global.bedDevs ^ " " ^ global.fmt
set global.bedPasses = global.bedPasses + 1
