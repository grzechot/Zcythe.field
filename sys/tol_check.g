; tol_check.g - called at the end of tolerances.g: one console line per tolerance outside its RECOMMENDED range.
; tolerances.g is loaded by many macros (homing loads it per axis) - the lines are printed only when the set of
; out-of-range values differs from the last printed one (global.tolWarnLast).
if !exists(global.tolWarnLast)
  global tolWarnLast = ""
var w = ""
if global.tolXY < global.tolXYR[0] || global.tolXY > global.tolXYR[1]
  set var.w = var.w ^ " tolXY " ^ global.tolXY
if global.tolZ < global.tolZR[0] || global.tolZ > global.tolZR[1]
  set var.w = var.w ^ " tolZ " ^ global.tolZ
if global.tolBed < global.tolBedR[0] || global.tolBed > global.tolBedR[1]
  set var.w = var.w ^ " tolBed " ^ global.tolBed
if global.tolG31Live < global.tolG31LiveR[0] || global.tolG31Live > global.tolG31LiveR[1]
  set var.w = var.w ^ " tolG31Live " ^ global.tolG31Live
if global.tolG31Methods < global.tolG31MethodsR[0] || global.tolG31Methods > global.tolG31MethodsR[1]
  set var.w = var.w ^ " tolG31Methods " ^ global.tolG31Methods
if global.tolCheck < global.tolCheckR[0] || global.tolCheck > global.tolCheckR[1]
  set var.w = var.w ^ " tolCheck " ^ global.tolCheck
if var.w != global.tolWarnLast
  set global.tolWarnLast = var.w
  if var.w != ""
    M98 P"0:/sys/msg.g" S{"WARN out of recommended range:"}
    M98 P"0:/sys/msg.g" S{var.w}
