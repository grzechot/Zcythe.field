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
