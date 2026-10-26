; bedsoak.g - wygrzewanie stolu przed poziomowaniem i pomiarami (Zcythe Field; dane z testu 2026-10-12, PLA 55 C):
; kopula stolu tworzy sie w ~2 min po osiagnieciu temperatury i ustala sie (+-0.005 mm) w 2-9 min (od zimnego ok. 9 min).
; Wolanie: M98 P"0:/sys/bedsoak.g" B<temp stolu> A<temp stolu na poczatku> T<upTime startu grzania> [C<s od zimnego, 480>] [W<s gdy cieply, 180>]
; Zasady (od 2026-10-12 wieczorem, z daemon.g):
;   1) stol JUZ w celu (daemon.g: global.bedInTargetSince, ta sama zadana) - C s liczone od chwili wejscia stolu w cel;
;      stol w celu od >= C s (po pauzie, anulowaniu, poprzednim druku) - bez czekania.
;   2) stol nie w celu, ale na poczatku w 5 C od celu - W s od osiagniecia celu.
;   3) zimny - C s od osiagniecia celu. Gdy stol nie dojdzie do celu w 20 min: komunikat i liczenie od teraz.
;   Bez daemon.g (brak globala): jak dawniej - stol w pasmie przy starcie = liczenie od startu grzania (T).
; Komunikaty (2026-10-20): tylko msg.g (konsola PanelDue + DWC, EN) na poczatku, co 60 s i na koncu; bez okien (toasty w DWC).
; 2026-10-22 (zad. 15): teksty dla operatora (temperatura co 60 s przy grzaniu, minuty), R1 = ponowne wygrzanie po
;   wylaczeniu grzalek przez timer (op_wait.g). Stol nie w celu po 20 min: OKNO (decyzja operatora) +10 min /
;   Continue (= start przy N C, jak dawniej: liczenie od teraz) / Cancel. Algorytm (czasy, pasma) bez zmian.
; 261023 (pliki_31, operator): okno wygrzewania Wait / Skip / Abort|Stop - maly wydruk moze pominac czekanie (odksztalcenie
;   brzegow stolu wazne tylko dla duzych wydrukow). M291 S4 T{pozostaly czas} J2: bez wyboru okno znika po czasie
;   (result -1) = czekanie do konca; J2 dodaje przycisk Cancel panelu = zamknij okno, czekaj dalej (dlatego "Abort").
;   Q0 = bez okna (testy).
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
var lim = 1200                        ; [s] czekanie na cel; "+10 min" dodaje 600
var cont = false                      ; operator: Continue (stol ponizej celu)
var tLog = state.upTime
var k = -1
var m = ""
var cancel = (job.file.fileName != null) ? "Cancel" : "Stop"
var bk = (exists(global.piBackLbl) && exists(global.piRun) && global.piRun && job.file.fileName != null) ? global.piBackLbl : ""   ; 261024 (pliki_36): krok wstecz w PrintInit
if !exists(global.soakWaited)
  global soakWaited = false
if exists(param.R) && param.R == 1
  M98 P"0:/sys/msg.g" S"Bed cooled - warm-up again"
if var.inTgt
  set var.tReach = global.bedInTargetSince
  set var.why = "bed at target for " ^ (state.upTime - var.tReach) ^ " s"
else
  if abs(heat.heaters[0].current - var.bed) > 1
    M98 P"0:/sys/msg.g" S{"Heating bed: " ^ floor(heat.heaters[0].current) ^ " C -> " ^ var.bed ^ " C"} L{"bedsoak: heating bed to " ^ var.bed ^ " C (now " ^ heat.heaters[0].current ^ " C)"}
  while true
    while abs(heat.heaters[0].current - var.bed) > 1 && state.upTime - var.tw0 < var.lim
      G4 S2
      if state.upTime - var.tLog >= 60
        set var.tLog = state.upTime
        M98 P"0:/sys/msg.g" S{"Heating bed: " ^ floor(heat.heaters[0].current) ^ " C / " ^ var.bed ^ " C"}
    if abs(heat.heaters[0].current - var.bed) <= 1
      break
    ; not at target in time - window (operator 2026-10-22)
    var now = floor(heat.heaters[0].current)
    set var.m = "After " ^ floor((state.upTime - var.tw0) / 60) ^ " min the bed is at " ^ var.now ^ " C (target " ^ var.bed ^ " C)."
    set var.m = var.m ^ " Check: bed heater cable and connector, mains/SSR, room draught. Heaters stay on."
    M98 P"0:/sys/msg.g" S{"ERROR bed only " ^ var.now ^ " C (target " ^ var.bed ^ " C)"} L{"ERROR bedsoak: bed did not reach " ^ var.bed ^ " C in " ^ floor((state.upTime - var.tw0) / 60) ^ " min (now " ^ heat.heaters[0].current ^ " C)"}
    M300 S2500 P300
    M300 S1800 P300
    M98 P"0:/sys/op_wait.g" S1 W"operator"
    G4 P400
    if var.bk == ""
      M291 P{var.m} R{"Bed does not reach " ^ var.bed ^ " C"} S4 K{"+10 min", "Continue", var.cancel}
    else
      M291 P{var.m} R{"Bed does not reach " ^ var.bed ^ " C"} S4 K{"+10 min", "Continue", var.cancel, var.bk}
    set var.k = input
    M98 P"0:/sys/op_wait.g" S0
    if var.k == 0
      set var.lim = state.upTime - var.tw0 + 600
      M98 P"0:/sys/msg.g" S"Operator: wait 10 min more"
    elif var.k == 3
      set global.piBack = global.piStage - 1
      M98 P"0:/sys/msg.g" S{"Operator: " ^ var.bk}
      M99
    elif var.k == 1
      set var.cont = true
      M98 P"0:/sys/msg.g" S{"WARNING bed only " ^ var.now ^ " C (target " ^ var.bed ^ " C)"} L{"WARNING bed only " ^ var.now ^ " C (target " ^ var.bed ^ " C) - operator: Continue; warm-up counted from now"}
      M98 P"0:/sys/msg.g" S" 1st layer may not stick"
      break
    else
      abort "Bed warm-up stopped by operator"
  if var.cont
    set var.tReach = state.upTime
  elif state.upTime - var.tw0 < 4
    set var.tReach = var.tHeat0 + var.heatEst   ; stol byl w pasmie przy pierwszym sprawdzeniu
  else
    set var.tReach = state.upTime
  set var.why = var.isWarm ? "warm start" : "cold start"
if var.tReach > state.upTime
  set var.tReach = state.upTime
set var.left = var.need - (state.upTime - var.tReach)
if var.left > 0
  M98 P"0:/sys/msg.g" S{"Bed at " ^ var.bed ^ " C - settling " ^ floor((var.left + 59) / 60) ^ " min"} L{"bedsoak (" ^ var.why ^ "): soak " ^ var.need ^ " s so the bed shape settles, " ^ var.left ^ " s left"}
elif var.inTgt
  M98 P"0:/sys/msg.g" S{"Bed warm-up not needed (hot " ^ floor((state.upTime - var.tReach) / 60) ^ " min)"} L{"bedsoak (" ^ var.why ^ ", required " ^ var.need ^ " s): no waiting"}
else
  M98 P"0:/sys/msg.g" S"Bed warm-up not needed" L{"bedsoak (" ^ var.why ^ ", required " ^ var.need ^ " s): no waiting"}
var skipped = false
; 261024 (operator): minuty w oknie odswiezane co 60 s - okno z T{min(60, pozostalo)}, po timeoucie pokazane od nowa
var askW = var.left > 20 && !(exists(param.Q) && param.Q == 0)
var mins = 0
var stop = (job.file.fileName != null) ? "Abort" : "Stop"
var tw = 0
var tOpen = 0
var r = 0
var ch = 0
if var.askW
  M300 S2000 P150
while var.askW
  set var.mins = floor((var.left + 59) / 60)
  set var.tw = min(60, var.left)
  set var.tOpen = state.upTime
  if var.bk == ""
    M291 P{"Bed edges settle " ^ var.mins ^ " min. Large print: Wait. Small print in the middle: Skip. No choice or Cancel = wait."} R{"Bed warm-up " ^ var.mins ^ " min"} S4 K{"Wait", "Skip", var.stop} F0 T{var.tw} J2
  else
    M291 P{"Bed edges settle " ^ var.mins ^ " min. Large print: Wait. Small print in the middle: Skip. No choice or Cancel = wait."} R{"Bed warm-up " ^ var.mins ^ " min"} S4 K{"Wait", "Skip", var.stop, var.bk} F0 T{var.tw} J2
  set var.r = result
  set var.ch = input
  set var.left = var.need - (state.upTime - var.tReach)
  if var.r == -1
    if state.upTime - var.tOpen < var.tw - 2
      set var.askW = false
      if var.left > 5
        M98 P"0:/sys/msg.g" S"Warm-up window closed - waiting"
    elif var.left <= 5
      set var.askW = false
  elif var.ch == 1
    set var.askW = false
    set var.skipped = true
    var early = max(0, var.left)
    M98 P"0:/sys/msg.g" S{"WARNING warm-up skipped " ^ floor((var.early + 59) / 60) ^ " min early"} L{"WARNING bedsoak: operator Skip, " ^ var.early ^ " s before the bed shape settles - G32 and map on a bed still changing shape (edges)"}
  elif var.ch == 2
    abort "Bed warm-up stopped by operator"
  elif var.ch == 3
    set global.piBack = global.piStage - 1
    M98 P"0:/sys/msg.g" S{"Operator: " ^ var.bk}
    M99
  else
    set var.askW = false
if var.skipped
  set var.left = 0
set var.tLog = state.upTime
var waited = var.left > 0
while var.left > 0
  if state.upTime - var.tLog >= 60
    M98 P"0:/sys/msg.g" S{"Bed warm-up: " ^ floor((var.left + 59) / 60) ^ " min left"}
    set var.tLog = state.upTime
  G4 S{min(10, var.left)}
  set var.left = var.need - (state.upTime - var.tReach)
set global.soakWaited = var.waited || var.skipped   ; 261024: start.g step 6 (leveling check) after a real warm-up
if var.skipped
  M98 P"0:/sys/msg.g" S{"-- BED WARM-UP SKIPPED  " ^ floor((state.upTime - var.tw0) / 60 + 0.5) ^ " min --"}
elif var.waited || state.upTime - var.tw0 >= 60
  var dt = state.upTime - var.tw0
  M98 P"0:/sys/msg.g" S{"-- BED WARM-UP DONE  " ^ (var.dt >= 120 ? (floor(var.dt / 60 + 0.5) ^ " min") : (var.dt ^ " s")) ^ " --"}
