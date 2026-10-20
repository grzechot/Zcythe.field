; tolerances.g - all procedure tolerances [mm] in one place. Edit here (DWC) or with "Change tol" in the windows
; (the macro then rewrites this file via tol_save.g). Loaded at the start of every macro that uses them.
; Ranges xxxR = {recommended min, recommended max, allowed min, allowed max}: outside recommended -> warning and
; confirmation in the window; outside allowed -> not accepted by the number field. Sources: measurements 2026-10-16.
; last change: 2026-10-16 20:00 tolCheck 0.08 -> 0.03 (check now map off, 2 dives vs map value)
if !exists(global.tolXY)
  global tolXY = 0
if !exists(global.tolZ)
  global tolZ = 0
if !exists(global.tolBed)
  global tolBed = 0
if !exists(global.tolG31Live)
  global tolG31Live = 0
if !exists(global.tolG31Methods)
  global tolG31Methods = 0
if !exists(global.tolCheck)
  global tolCheck = 0
if !exists(global.tolXYR)
  global tolXYR = {0, 0, 0, 0}
if !exists(global.tolZR)
  global tolZR = {0, 0, 0, 0}
if !exists(global.tolBedR)
  global tolBedR = {0, 0, 0, 0}
if !exists(global.tolG31LiveR)
  global tolG31LiveR = {0, 0, 0, 0}
if !exists(global.tolG31MethodsR)
  global tolG31MethodsR = {0, 0, 0, 0}
if !exists(global.tolCheckR)
  global tolCheckR = {0, 0, 0, 0}
set global.tolXY = 0.30          ; homing check B: X/Y endstop repeatability -> error window (home_xy.g)
set global.tolZ = 0.03           ; homing check C: Z zero shift vs previous homing -> warning (home_sum.g)
set global.tolBed = 0.02         ; G32: deviation before correction counted as level (bed.g)
set global.tolG31Live = 0.05     ; HesCal2: new G31 vs last good G31 -> window G31 REJECTED (hescal2_m.g)
set global.tolG31Methods = 0.05  ; HesCal2: G31 from K1 tip vs from bed -> warning (hescal2_m.g)
set global.tolCheck = 0.03       ; Mesh: re-measured point (map off, 2 dives) vs map value -> window MESH CHECK (Mesh)
set global.tolXYR = {0.05, 0.30, 0.02, 1.0}          ; repeatability +-0.0125; endstop fault = 5 mm
set global.tolZR = {0.02, 0.05, 0.01, 0.2}           ; Z homing spread 0.003-0.01
set global.tolBedR = {0.01, 0.03, 0.005, 0.1}        ; final G32 deviation 0.014; tighter = more passes
set global.tolG31LiveR = {0.03, 0.08, 0.01, 0.5}     ; G31 sigma 0.003, drift ~0.03 / 10 min; real change -> "Use measured"
set global.tolG31MethodsR = {0.02, 0.06, 0.01, 0.2}  ; 16.10: 0.031 and 0.0425
set global.tolCheckR = {0.02, 0.05, 0.01, 0.2}       ; expected noise ~0.02; check with map on (+0.05 on 16.10) was invalid - nozzle/probe offset
M98 P"0:/sys/tol_check.g"        ; warning line when a value is outside its recommended range (printed once per change)
