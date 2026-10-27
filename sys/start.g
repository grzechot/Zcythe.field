; start.g - przygotowanie do wydruku, uruchamiane automatycznie przed kazdym wydrukiem
; recznie: M98 P"0:/sys/start.g" (od poczatku) albo M98 P"0:/sys/start.g" S<numer kroku> (wznowienie)
; Kroki S (zgodnosc z RetryLastStep): 1=grzanie, 2=otwarcie K0 + bazowanie + poziomowanie, 3=wipe, 4=HesCal, 5=siatka, 6=prime
; 261024 (pliki_36, operator): 10 etapow PrintInit w petli, kazde okno bledu ma "krok wstecz" (< etap):
;   1 heating, 2 bed probe, 3 homing (< Probe), 4 leveling (< Home), 5 warm-up (< Level), 6 leveling check (< Warm),
;   7 cleaning, 8 calibration (< Clean = wipe + pomiar, w HesCal2), 9 bed map (< Calib), 10 purge.
;   Okno ustawia global.piBack = etap docelowy i makro wychodzi (M99); petla wraca do tego etapu.
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
; 2026-10-22 (zad. 15, PrintInit): linie etapow [n/9] dla operatora, global.piRun = trwa PrintInit (homing/deploy/bedsoak
;   pisza wtedy wlasne linie etapow), global.k0Closes = licznik zamkniec K0 w trakcie pomiarow. Kroki bez zmian.
if !exists(global.piRun)
  global piRun = false
if !exists(global.k0Closes)
  global k0Closes = 0
set global.piRun = true
set global.k0Closes = 0
var tPi0 = state.upTime
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
var oldS = var.manualResume ? param.S : 1
var stage = (var.oldS <= 2) ? var.oldS : ((var.oldS == 3) ? 7 : ((var.oldS == 4) ? 8 : ((var.oldS == 5) ? 9 : 10)))
if !exists(global.piStage)
  global piStage = 0
if !exists(global.piBack)
  global piBack = 0
if !exists(global.piBackLbl)
  global piBackLbl = ""
if !exists(global.soakWaited)
  global soakWaited = false
var lbl = {"", "", "", "< Probe", "< Home", "< Level", "< Warm", "", "", "< Calib", ""}
var forceHome = false
var forceLevel = var.manualResume
var lvlRan = false
var forceChk = false
while var.stage <= 10
  set global.piStage = var.stage
  set global.piBack = 0
  set global.piBackLbl = var.lbl[var.stage]
  if var.stage >= 7
    set global.hopZ = max(1.5, sensors.probes[0].triggerHeight + 0.8)
    M201 X2000 Y2000
    M566 X300 Y300
  if var.stage == 1
    M98 P"0:/sys/msg.g" S{"[1/10] Heating: bed " ^ var.bedTemp ^ " C, nozzle 165 C"}
    M140 S{var.bedTemp}        ; stol: temperatura druku (PLA 55 C)
    if state.currentTool != 0
      T0 P0
    M568 P0 R165 S165 A2       ; dysza: 165 C (active = standby), grzanie w tle
  elif var.stage == 2
    set global.lastInitStep = 2
    M98 P"0:/sys/msg.g" S"[2/10] Checking bed probe"
    M98 P"0:/sys/deployprobe0.g"
    if fileexists("0:/sys/k0offset.g")
      M98 P"0:/sys/k0offset.g"   ; zmierzone przesuniecie K0->dysza (G31 X Y) zamiast domyslnego z config.g
  elif var.stage == 3
    if var.forceHome || !move.axes[0].homed || !move.axes[1].homed || !move.axes[2].homed
      set var.forceHome = false
      G28 XYZ                  ; bazowanie (homex/homey/homez.g, linia [3/10]) - kasuje levelDone i skipCal
    else
      M98 P"0:/sys/msg.g" S"Homing skipped (already homed)" L"start.g: X/Y/Z already homed - homing (G28) skipped"
  elif var.stage == 4
    if var.forceLevel || !global.levelDone
      set var.forceLevel = false
      set global.skipCal = false   ; po swiezym poziomowaniu kalibracje G31 robimy na nowo
      M98 P"0:/sys/msg.g" S"[4/10] Leveling bed"
      G32                      ; poziomowanie stolu (bed.g) - ustawia levelDone
      set var.lvlRan = true
    else
      M98 P"0:/sys/msg.g" S"Leveling skipped (already level)" L"start.g: bed already levelled (levelDone) - G32 skipped"
  elif var.stage == 5
    set global.soakWaited = false
    if !var.manualResume
      M98 P"0:/sys/msg.g" S"[5/10] Bed warm-up"
      M98 P"0:/sys/bedsoak.g" B{var.bedTemp} A{var.bedAtStart} T{var.tHeat0}   ; wygrzanie stolu przed kontrola G32 i pomiarami
  elif var.stage == 6
    if var.forceChk || var.lvlRan || global.soakWaited || !global.levelDone
      set var.forceChk = false
      set global.skipCal = false
      M98 P"0:/sys/msg.g" S"[6/10] Leveling check (bed warm)"
      G32                      ; kontrola poziomowania po wygrzaniu (dryf bramy/srub Z w temperaturze)
    else
      M98 P"0:/sys/msg.g" S"Leveling check skipped (bed level, warm)" L"start.g: bed level before warm-up and no waiting - leveling check skipped"
  elif var.stage == 7
    set global.lastInitStep = 3
    if global.eOwed > 0
      M116 P0
      M83
      G1 E{global.eOwed} F600
      set global.eOwed = 0
    M98 P"0:/sys/msg.g" S"[7/10] Cleaning nozzle"
    M98 P"0:/macros/wipe"      ; kontrola temperatury, cofniecie filamentu, wytarcie dyszy
  elif var.stage == 8
    set global.lastInitStep = 4
    if !var.manualResume && global.skipCal && move.axes[0].homed && move.axes[1].homed && move.axes[2].homed
      M98 P"0:/sys/msg.g" S"Calibration skipped (done before)" L"start.g: G31 calibration HesCal2 already done (skipCal) - skipped"
    else
      M98 P"0:/sys/msg.g" S"[8/10] Nozzle calibration"
      M98 P"0:/macros/HesCal2"  ; kalibracja G31 (okno bledu: < Clean = wipe i pomiar od nowa)
  elif var.stage == 9
    set global.lastInitStep = 5
    M98 P"0:/sys/msg.g" S"[9/10] Bed map (49 points, about 3 min)"
    M98 P"0:/macros/Mesh"      ; swieza siatka 7x7 + rozszerzenie o wiersz 8 (obowiazkowo przed kazdym wydrukiem)
  else
    set global.lastInitStep = 6
    M98 P"0:/sys/msg.g" S{"[10/10] Purge line (nozzle " ^ var.primeTemp ^ " C)"}
    M568 P0 S{var.primeTemp} A2    ; tylko active (standby bez zmian); prime sam poczeka na te temperature
    M98 P"0:/macros/prime" P20   ; doladowanie global.eRetr + purge 20 mm + szczotka
  if global.piBack > 0 && global.piBack < var.stage
    var tgt = global.piBack
    M98 P"0:/sys/msg.g" S{"Operator: back to step " ^ var.tgt ^ "/10"} L{"start.g: operator step back from " ^ var.stage ^ " to " ^ var.tgt}
    if var.tgt <= 3
      set var.forceHome = true
    if var.tgt <= 4
      set var.forceLevel = true
    if var.tgt <= 6
      set var.forceChk = true
    if var.tgt <= 8
      set global.skipCal = false
    set var.stage = var.tgt
  else
    set var.stage = var.stage + 1
set global.piBack = 0
set global.piBackLbl = ""
set global.piStage = 0
M201 X{global.dynAx} Y{global.dynAy}   ; przywroc dynamike z config.g (druk)
M566 X{global.dynJx} Y{global.dynJy}
set global.hopZ = 5
set global.lastInitStep = 0   ; wszystkie kroki OK - nic do wznowienia
set global.piRun = false
var dPi = state.upTime - var.tPi0
M98 P"0:/sys/msg.g" S{"-- PRINT INIT DONE  " ^ (var.dPi >= 120 ? (floor(var.dPi / 60 + 0.5) ^ " min") : (var.dPi ^ " s")) ^ " --"}
