; bedsoak.g - wygrzewanie stolu przed poziomowaniem i pomiarami (Zcythe Field; dane z testu 2026-10-12, PLA 55 C):
; kopula stolu tworzy sie w ~2 min po osiagnieciu temperatury i ustala sie (+-0.005 mm) w 2-9 min (od zimnego ok. 9 min).
; Wolanie: M98 P"0:/sys/bedsoak.g" B<temp stolu> A<temp stolu na poczatku> T<upTime startu grzania> [C<s od zimnego, 480>] [W<s gdy cieply, 180>]
; Zasady (od 2026-10-12 wieczorem, z daemon.g):
;   1) stol JUZ w celu (daemon.g: global.bedInTargetSince, ta sama zadana) - C s liczone od chwili wejscia stolu w cel;
;      stol w celu od >= C s (po pauzie, anulowaniu, poprzednim druku) - bez czekania.
;   2) stol nie w celu, ale na poczatku w 5 C od celu - W s od osiagniecia celu.
;   3) zimny - C s od osiagniecia celu. Gdy stol nie dojdzie do celu w 20 min: komunikat i liczenie od teraz.
;   Bez daemon.g (brak globala): jak dawniej - stol w pasmie przy starcie = liczenie od startu grzania (T).
; Komunikaty: M117 co 10 s oraz M118 P2 (konsola PanelDue) i P3 (konsola DWC) na poczatku, co 30 s i na koncu.
var bed = exists(param.B) ? param.B : 55
var atStart = exists(param.A) ? param.A : heat.heaters[0].current
var tHeat0 = exists(param.T) ? param.T : state.upTime
var cold = exists(param.C) ? param.C : 480
var warm = exists(param.W) ? param.W : 180
var inTgt = exists(global.bedInTargetSince) && global.bedInTargetSince >= 0 && global.bedTargetTemp == var.bed
var isWarm = var.atStart >= var.bed - 5
var need = (var.inTgt || !var.isWarm) ? var.cold : var.warm
var heatEst = var.isWarm ? 0 : 90     ; s od startu grzania do osiagniecia celu z zimnego (zmierzone: ok. 80 s)
var tw0 = state.upTime
var tReach = 0
var left = 0
var why = ""
var msg = ""
if var.inTgt
  set var.tReach = global.bedInTargetSince
  set var.why = "stol w celu od " ^ (state.upTime - var.tReach) ^ " s"
else
  if abs(heat.heaters[0].current - var.bed) > 1
    set var.msg = "bedsoak: grzanie stolu do " ^ var.bed ^ " C (teraz " ^ heat.heaters[0].current ^ " C)"
    M118 P2 S{var.msg}
    M118 P3 S{var.msg}
  while abs(heat.heaters[0].current - var.bed) > 1 && state.upTime - var.tw0 < 1200
    G4 S2
  if state.upTime - var.tw0 >= 1200
    M118 P2 S"bedsoak: stol nie doszedl do celu w 20 min - licze od teraz"
    M118 P3 S"bedsoak: stol nie doszedl do celu w 20 min - licze od teraz"
    set var.tReach = state.upTime
  elif state.upTime - var.tw0 < 4
    set var.tReach = var.tHeat0 + var.heatEst   ; stol byl w pasmie przy pierwszym sprawdzeniu
  else
    set var.tReach = state.upTime
  set var.why = var.isWarm ? "cieply start" : "zimny start"
if var.tReach > state.upTime
  set var.tReach = state.upTime
set var.left = var.need - (state.upTime - var.tReach)
if var.left > 0
  set var.msg = "bedsoak: " ^ var.why ^ " - wygrzewanie " ^ var.need ^ " s, jeszcze " ^ var.left ^ " s"
else
  set var.msg = "bedsoak: " ^ var.why ^ " (wymagane " ^ var.need ^ " s) - bez czekania"
M118 P2 S{var.msg}
M118 P3 S{var.msg}
var tLog = state.upTime
while var.left > 0
  M117 {"Stol: wygrzewanie, jeszcze " ^ var.left ^ " s"}
  if state.upTime - var.tLog >= 30
    set var.msg = "Stol: wygrzewanie, jeszcze " ^ var.left ^ " s"
    M118 P2 S{var.msg}
    M118 P3 S{var.msg}
    set var.tLog = state.upTime
  G4 S{min(10, var.left)}
  set var.left = var.need - (state.upTime - var.tReach)
M117 "Stol wygrzany"
M118 P2 S"Stol wygrzany"
M118 P3 S"Stol wygrzany"
