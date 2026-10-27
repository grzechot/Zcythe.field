; daemon.g - Zcythe Field: RRF uruchamia ten plik sam, co ok. 10 s (kanal Daemon). Tylko obliczenia - bez ruchow, bez G4.
; Sledzi, OD KIEDY stol jest w temperaturze docelowej, zeby bedsoak.g liczyl wygrzewanie od tej chwili, a nie od startu druku
; (np. po pauzie / anulowaniu stol stoi w 55 C od pol godziny - wtedy nie ma na co czekac).
;   global.bedInTargetSince = upTime [s] wejscia stolu w pasmo docelowe (grzalka aktywna); -1 = poza pasmem / grzalka nieaktywna
;   global.bedTargetTemp    = zadana temperatura, ktorej dotyczy licznik (zmiana zadanej = liczenie od nowa)
; Histereza: wejscie w pasmo przy odchylce <= 1 C, wyjscie dopiero przy > 2 C (chwilowe wahania nie zeruja licznika).
; Rozdzielczosc ok. 10 s - moment wejscia moze byc zapisany do 10 s pozniej (bezpieczny kierunek: dluzsze wygrzewanie).
if !exists(global.bedInTargetSince)
  global bedInTargetSince = -1
if !exists(global.bedTargetTemp)
  global bedTargetTemp = 0
var tgt = heat.heaters[0].active
var dev = abs(heat.heaters[0].current - var.tgt)
if heat.heaters[0].state != "active" || var.tgt != global.bedTargetTemp
  set global.bedInTargetSince = -1
  set global.bedTargetTemp = var.tgt
if global.bedInTargetSince < 0
  if heat.heaters[0].state == "active" && var.dev <= 1
    set global.bedInTargetSince = state.upTime
elif var.dev > 2
  set global.bedInTargetSince = -1
; --- 2026-10-22 (task 15): timers while the printer waits for the operator (op_wait.g; times in printinit_cfg.g) ---
; reminder (beep + line) every piWaitRemind min; after piWaitHeatOff min heaters off; piWaitMotorsOff min later motors off.
if exists(global.opWaitSince) && global.opWaitSince >= 0
  if !exists(global.piWaitHeatOff)
    M98 P"0:/sys/printinit_cfg.g"
  var w = state.upTime - global.opWaitSince
  var hOff = global.piWaitHeatOff * 60
  var mOff = var.hOff + global.piWaitMotorsOff * 60
  if !global.opHeatOff && var.w >= var.hOff
    set global.opBed = heat.heaters[0].active
    M140 S-273.15              ; bed heater off (target kept in global.opBed)
    M568 P0 A0                 ; nozzle heater off (active/standby temperatures kept)
    set global.opHeatOff = true
    M300 S2500 P300
    M98 P"0:/sys/msg.g" S{"Waited " ^ global.piWaitHeatOff ^ " min - heaters off"}
  elif global.opHeatOff && !global.opMotorsOff && var.w >= var.mOff
    M18                        ; everything off (positions lost - op_wait.g S0 stops the procedure)
    set global.opMotorsOff = true
    M300 S2500 P300
    M98 P"0:/sys/msg.g" S{"Waited " ^ floor(var.mOff / 60) ^ " min - motors off"}
  elif state.upTime - global.opRemind >= global.piWaitRemind * 60
    set global.opRemind = state.upTime
    M300 S2500 P300
    var next = !global.opHeatOff ? ("heaters off in " ^ floor((var.hOff - var.w) / 60 + 1) ^ " min") : ("motors off in " ^ floor((var.mOff - var.w) / 60 + 1) ^ " min")
    M98 P"0:/sys/msg.g" S{"Waiting for " ^ global.opWaitWhat ^ ": " ^ floor(var.w / 60) ^ " min"} L{"Waiting for " ^ global.opWaitWhat ^ ": " ^ floor(var.w / 60) ^ " min (" ^ var.next ^ ")"}
