; start.g - przygotowanie do wydruku, uruchamiane automatycznie przed kazdym wydrukiem
; recznie: M98 P"0:/sys/start.g" (od poczatku) albo M98 P"0:/sys/start.g" S<numer kroku> (wznowienie)
; Kroki: 1=grzanie, 2=otwarcie K0 + bazowanie + poziomowanie, 3=wipe, 4=HesCal, 5=siatka (mesh), 6=prime
; Kazdy etap robiony RAZ - pomijany, jesli juz wykonany (np. recznie przed startem wydruku):
;   - bazowanie XYZ     : pomijane, gdy wszystkie osie sa zbazowane (RRF samo czysci "homed" po M18/M84/resecie)
;   - poziomowanie (G32): pomijane, gdy global.levelDone = true (bed.g ustawia je na koncu, home*.g/cancel.g
;                         kasuja po bazowaniu)
;   - HesCal            : pomijany, gdy global.skipCal = true (HesCal ustawia je po udanym zapisie G31, home*.g
;                         kasuja po bazowaniu; start.g kasuje je tez po swiezym poziomowaniu)
;   - siatka (mesh)     : ZAWSZE (obowiazkowa przed kazdym wydrukiem)
; STOL (PLA, 55 C): wygrzewanie wg testu termicznego 2026-10-12 (docs/thermal_test_2026-10-12.md): po bazowaniu i PRZED G32 i pomiarami
;   0:/sys/bedsoak.g czeka 8 min od wejscia stolu w cel (daemon.g; stol w celu dluzej = bez czekania; 3 min, gdy na starcie byl w 5 C od celu); G32 po nagrzaniu
;   (dryf bramy/srub Z), siatka w temperaturze druku (kopula stolu 0.13 mm przy 55 C). Wyzsze temperatury (PETG/ABS) - osobny test.
; HOTEND: krok 1 ustawia 165 C (standby = active) i wlacza grzanie; wipe/HesCal/pauza uzywaja standby (165).
; PRIME (krok 6) idzie w ARBITRALNEJ temperaturze primeTemp (220 C, nizej w kodzie) - start.g biegnie przed plikiem
; wydruku, wiec nie zna temperatury druku. Dotyczy TYLKO tego jednego prime; wszystkie inne wipe/prime (resume,
; pauza) biora temperatury z ustawien filamentu (standby/active). Plik wydruku i tak ustawi swoje G10 S... potem.
; Po nieudanym kroku (abort) global.lastInitStep zostaje ustawiony na ten krok - "0:/macros/RetryLastStep"
; wznawia STAD. Dziala tylko dopoki osie XYZ sa zbazowane.
; Jawne S<numer> to swiadomy wybor operatora - wtedy od kroku S wykonuje sie WSZYSTKO (poziomowanie i HesCal
; tez, mimo flag), z wyjatkiem bazowania, ktore nadal tylko gdy osie nie sa zbazowane.
if !exists(global.skipCal)
  global skipCal = false
if !exists(global.levelDone)
  global levelDone = false
if !exists(global.lastInitStep)
  global lastInitStep = 0
; hopZ = wysokosc Z przejazdow po poziomowaniu: G31 + 0.8 (K0 0.8 mm nad stolem, dysza ok. 1.6 mm), min. 1.5 dla dyszy.
; 5 = przed poziomowaniem / poza start.g. Makra (wipe, prime, Mesh, HesCal2) czytaja ja z wartoscia domyslna 5.
if !exists(global.hopZ)
  global hopZ = 5
; eOwed = ile mm filamentu jest CZASOWO cofniete przez kalibracje (HesCal2 ustawia, oddaje na koncu; przy przerwaniu
; oddaje cancel.g albo krok 3 ponizej, gdy hotend jest gorący)
if !exists(global.eOwed)
  global eOwed = 0
; dynamika sprzed procedury startowej (z config.g) - przywracana na koncu; zapamietywana RAZ na uruchomienie
if !exists(global.dynAx)
  global dynAx = move.axes[0].acceleration
  global dynAy = move.axes[1].acceleration
  global dynJx = move.axes[0].jerk
  global dynJy = move.axes[1].jerk
var bedTemp = 55            ; [C] temperatura stolu druku (PLA); mesh i wygrzewanie w tej temperaturze
var bedAtStart = heat.heaters[0].current   ; temperatura stolu w chwili startu start.g (przed M140)
var tHeat0 = state.upTime    ; [s] moment startu grzania (dla bedsoak.g)
var primeTemp = 220          ; [C] temperatura TYLKO dla prime w start.g (patrz wyzej) - zmien tu przy innym filamencie
var manualResume = exists(param.S)
var fromStep = var.manualResume ? param.S : 1

if var.fromStep <= 1
  M140 S{var.bedTemp}        ; stol: temperatura druku (PLA 55 C)
  ; hotend: ARBITRALNA bezpieczna temperatura 165 C na samym poczatku - grzanie rusza zawsze, zanim zaczna sie
  ; bazowania/poziomowanie, wiec do wipe/HesCal/prime dysza jest juz goraca. Ustawia active i standby (165 = granica
  ; min. temp. ekstruzji 160 + 5) i wlacza grzalke (A2) - niezaleznie od stanu po poprzednim wydruku. Temp. druku
  ; ustawia potem plik (G10 S...), a prime czeka na nia.
  if state.currentTool != 0
    T0 P0
  M568 P0 R165 S165 A2
if var.fromStep <= 2
  set global.lastInitStep = 2
  ; K0 (reczna igla) musi byc otwarta PRZED wszystkim, co sondowanie wymaga (bazowanie Z, G32, HesCal, Mesh) -
  ; jawne wywolanie, bo samo M401 przy deployedByUser=true nie wola makra, a pominiete G32/homing nie pytaja wcale.
  ; Szybkie wyjscie, gdy sonda juz otwarta; inaczej komunikat "Manual Deploy" i czekanie.
  M98 P"0:/sys/deployprobe0.g"
  if fileexists("0:/sys/k0offset.g")
    M98 P"0:/sys/k0offset.g"   ; zmierzone przesuniecie K0->dysza (G31 X Y) zamiast domyslnego z config.g
  if !move.axes[0].homed || !move.axes[1].homed || !move.axes[2].homed
    G28 XYZ                  ; bazowanie (homex/homey/homez.g) - kasuje levelDone i skipCal
  else
    M118 P2 S"start.g: osie zbazowane - pomijam bazowanie"
  if !var.manualResume
    M98 P"0:/sys/bedsoak.g" B{var.bedTemp} A{var.bedAtStart} T{var.tHeat0}   ; wygrzanie stolu przed G32 i pomiarami
  if var.manualResume || !global.levelDone
    set global.skipCal = false   ; po swiezym poziomowaniu kalibracje G31 robimy na nowo
    G32                      ; poziomowanie stolu (bed.g, bez bazowania) - ustawia levelDone
  else
    M118 P2 S"start.g: poziomowanie juz wykonane - pomijam G32"
; --- od tego miejsca stol jest wypoziomowany: nizszy hop i szybkie przejazdy ---
; hop: K0 0.8 mm nad stolem (min. 1.5 mm dla dyszy). Dynamika jak w mesh.g (M201 2000 / M566 300), zeby przyspieszenie
; nie wyzwalalo K0; przejazdy w makrach jada wtedy F24000 (jak sonda w Mesh).
set global.hopZ = max(1.5, sensors.probes[0].triggerHeight + 0.8)
M201 X2000 Y2000
M566 X300 Y300
if var.fromStep <= 3
  set global.lastInitStep = 3
  ; filament czasowo cofniety przez przerwana kalibracje - oddaj (hotend gorący; M116 czeka na 165 C)
  if global.eOwed > 0
    M116 P0
    M83
    G1 E{global.eOwed} F600
    set global.eOwed = 0
  M98 P"0:/macros/wipe"      ; kontrola temperatury, cofniecie filamentu, wytarcie dyszy
if var.fromStep <= 4
  set global.lastInitStep = 4
  if !var.manualResume && global.skipCal && move.axes[0].homed && move.axes[1].homed && move.axes[2].homed
    M118 P2 S"start.g: HesCal juz wykonany - pomijam"
  else
    M98 P"0:/macros/HesCal2"  ; kalibracja G31 - nowy, krotszy algorytm (kula R~7.5); stary: M98 P"0:/macros/HesCal"
if var.fromStep <= 5
  set global.lastInitStep = 5
  M98 P"0:/macros/Mesh"      ; swieza siatka 7x7 + rozszerzenie o wiersz 8 (obowiazkowo przed kazdym wydrukiem)
if var.fromStep <= 6
  set global.lastInitStep = 6
  M568 P0 S{var.primeTemp} A2    ; tylko active (standby bez zmian); prime sam poczeka na te temperature
  M98 P"0:/macros/prime"       ; doladowanie + purge + szczotka (bez wipe i bez powrotu do ParkCoord)
M201 X{global.dynAx} Y{global.dynAy}   ; przywroc dynamike z config.g (druk)
M566 X{global.dynJx} Y{global.dynJy}
set global.hopZ = 5
set global.lastInitStep = 0   ; wszystkie kroki OK - nic do wznowienia
