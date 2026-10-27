; tol_ask.g - number window for a new tolerance, with recommended / allowed range.
; Params: S name, V current value, A recommended min, B recommended max, L allowed min, H allowed max, T window title.
; Result: global.tolAskVal = new value, -1 = cancelled. The allowed range is enforced by the number field (M291 S6 L H);
; a value outside the recommended range needs confirmation (Keep / Enter again) and gives a console warning.
if !exists(global.tolAskVal)
  global tolAskVal = -1
set global.tolAskVal = -1
while true
  M291 P{"New " ^ param.S ^ " [mm], now " ^ param.V ^ ". Recommended " ^ param.A ^ "-" ^ param.B ^ ", allowed " ^ param.L ^ "-" ^ param.H} R{param.T} S6 F{param.V} L{param.L} H{param.H} J2
  if result != 0
    M99                         ; Cancel - nothing changed
  var nv = input
  if var.nv >= param.A && var.nv <= param.B
    set global.tolAskVal = var.nv
    M99
  M98 P"0:/sys/msg.g" S{"WARN " ^ param.S ^ " " ^ var.nv ^ " outside " ^ param.A ^ "-" ^ param.B}
  M291 P{param.S ^ " " ^ var.nv ^ " is outside the recommended " ^ param.A ^ "-" ^ param.B ^ " mm."} R"TOLERANCE OUT OF RANGE" S4 K{"Keep", "Re-enter"}
  if input == 0
    set global.tolAskVal = var.nv
    M99
