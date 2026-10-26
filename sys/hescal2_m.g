; ======================================================================================
; hescal2_m.g - HesCal2 MEASUREMENT (called by 0:/macros/HesCal2, which repeats it on request). All parameters are HERE.
; HesCal2 - kalibracja G31 (K0 / K1 / Bed / HotEndTip) dla K1 z koncowka kulista (R ok. 5 mm)
; ======================================================================================
; Nowe wzgledem HesCal: bez wspinaczki, bez skanow. Kula R ~7.5 mm (HesTip 2026-10-07): wysokosc styku spada jak d^2/(2R)
; zarowno dla K0 jak i dla dyszy (dysza: parabola, bez plateau pierscienia), wiec:
;   * K0: zjazd wstepny + 5 zjazdow (srodek i +-dK w X i Y) -> wierzcholek (XY) i jego wysokosc z krzywizny R,
;   * dysza: zjazd wstepny + 2 zgodne zjazdy w punkcie K0 + zapisane przesuniecie K0->dysza (k0offset.g).
;   * przesuniecie K0->dysza (G31 X Y) wyznaczane dokladnie z HesTip (17-21 zjazdow na sonde) + dopasowanie; O1 = szybka wersja.
; Okna zjazdow: dysza wzglednie od K0 (zK0v - (refK0v - refHEv) z ostatniego R1); ochrona global.hesFloor = oczekiwane
;   zadzialanie K1 (z K0 na czubku) - floorMargin, nie blizej niz 0.3 mm nad stolem obok K1 (od 2026-10-13).
; G31 Z (od 2026-10-13): GLOWNA metoda "od czubka" (tylko dz = K0 i dysza na tym samym czubku K1 + stale z R1) -
;   niezalezna od stolu obok K1, ktory "plywa" po duzym G32; "od stolu" tylko kontrola/ostrzezenie. R1 = kotwica od stolu.
; 2026-10-16: console in English via hes_log.g -> msg.g (PanelDue + DWC), max 4 decimals, final summary
; 2026-10-20: long DWC texts (L) with expanded parameter names; PanelDue short text + " >DWC"
; 2026-10-22 (task 15): operator texts: PanelDue = result (probe offset) + WARNING only out of limits; service values
;   (tip/bed, dz, margin, G31 tip/bed, K1 screw, R1, k0offset) DWC only; error window with the cause in words
;   (var.fc) Measure / Clean / Use last / Cancel; G31 change window Accept / Measure / Set limit / Cancel.
;   G28 Z inside HesCal2 with global.hesQuiet (one homing line). Measurement unchanged.
;   block (<= 8 lines). K0 dives = homing values (bed find 120 mm/min in hes_vdive.g, fine 80 mm/min in hes_h.g).
;   K1 (nozzle) dives unchanged 30 mm/min. hes_hist.csv labels unchanged (OK2 / OK2-STOL / KALIBRACJA2).
; Wywolanie: M98 P"0:/macros/HesCal2" [O1 = pelny pomiar przesuniecia K0->dysza (XY, +4 zjazdy dyszy)]
;                                    [A1 = zaakceptuj duza zmiane G31 X/Y (> tolOffAccept)] [R1 = zapisz jako odniesienie]
; WYMAGA: R kuli w 0:/sys/hes_cfg.g (global.hesR) po HesTip, ale dziala tez z domyslnym 5.0.
; Nazwy: K0 (igla K0Tip), K1 (HotEndSensor), Bed, HotEndTip (dysza). Wysokosci w Z maszyny; liczy sie roznica.
; --------------------------------------------------------------------------------------
; PARAMETRY
var kThr = 0.972        ; [mm] dysza nad Bed przy zadzialaniu K1 = G31 + zapas K1 nad K0. 261026: NOWA K1, 1.018 + (0.182 - 0.228) (k1meas 5x po wipe).
;                         261024: 0.978 + 0.04 (babystep -0.04 na wydruku -> G31 +0.04).
;                         2026-10-20: 1.088 - 0.11 (3 wydruki: babystep +0.12 przy G31 0.878 i 0.834, +0.10 przy 0.834 -> korekta -0.10...-0.12).
;                         (G31 0.816 z R1 11:59; zapasy z PIERWSZYCH przebiegow po wipe: 0.124 -> 0.210/0.215 - kolejne przebiegi daja ok. 0.01 mniej).
;                         Po regulacji sruby/wymianie dyszy/K1: kThr = stare kThr + zmiana zapasu (porownywac pierwsze przebiegi po wipe), potem R1.
var manualZTrim = 0     ; [mm] dodawane do G31 tuz przed zapisem
M98 P"0:/sys/tolerances.g"      ; tolG31Methods, tolG31Live (and the other tolerances) are in 0:/sys/tolerances.g
var tolG31Methods = global.tolG31Methods ; [mm] G31 from K1 tip vs from bed -> warning only
var tolG31Live = global.tolG31Live       ; [mm] new G31 vs lastGoodG31 -> window G31 REJECTED
var tolOffAccept = 0.5  ; [mm] najwieksza automatycznie przyjeta zmiana G31 X/Y (wieksza: parametr A1)
var bedOff = -20        ; [mm] o ile w X od K1 K0 mierzy Bed
var dK = 0.6            ; [mm] odsuniecie zjazdow K0 od srodka w X i Y (dopasowanie wierzcholka); dla R~7.5 spadek Z 0.024 mm
var dHE = 0.8           ; [mm] odsuniecie zjazdow dyszy od wierzcholka (pomiar XY po zboczach; HesTip: dysza = parabola jak K0)
var heYoff = 0          ; [mm] dysza mierzona w wierzcholku (HesTip 2026-10-07: odpowiedz Z dyszy to parabola bez plateau pierscienia)
var agree = 0.006       ; [mm] zgodnosc dwoch zjazdow (stol, wierzcholek K0, dysza); HesTip: sigma zjazdu ok. 0.0016, ale pojedynczy zjazd bywa o 0.02 obok
var floorMargin = 0.30  ; [mm] zapas dyszy pod oczekiwanym punktem zadzialania K1 (2026-10-13: 0.10 ucinalo zjazdy po duzym G32)
var k0Clear = 0.8       ; [mm] K0 nad stolem w przejazdach (hop); uzytkownik 2026-10-08: 0.8
var k0DiveStart = 1.0   ; [mm] K0 nad stolem na POCZATKU zjazdu pomiarowego na stol (K0 wymaga min. 1 mm)
var calRetract = 2      ; [mm] retract filamentu na czas kalibracji. 2026-10-20: 6 -> 2 (zaciecia PLA w heatbreaku przy wielu kalibracjach; operator). Bylo 6 (limit 9 z testu 2026-10-08)
var kMargin = 0.2      ; [mm] CEL: K1 zadziala tyle ponad poziomem, na ktorym K0 dotyka stolu (zHEv - zBed). K1 pierwsze, ale niski wierzcholek. 2026-10-09
var kMarginTol = 0.15   ; [mm] tolerancja celu - w jej obrebie brak sugestii regulacji
var screwMmPerTurn = 0.4 ; [mm/obr] zmiana progu K1 na 1 obrot sruby regulacji (zmierzone 2026-10-09: 0.5 obr = 0.20 mm); dokrecanie obniza K1
; --------------------------------------------------------------------------------------
if !move.axes[0].homed || !move.axes[1].homed || !move.axes[2].homed
  abort "HesCal2: axes not homed"
if !exists(global.wiperX) || !exists(global.wiperY) || !exists(global.parkYOffset)
  abort "HesCal2: no WiperCoord - run wipe first"
if heat.heaters[1].standby <= 0
  abort "HesCal2: no standby temperature set (M568 P0 R165)"
var hcTemp = max(heat.heaters[1].standby, heat.coldExtrudeTemperature + 5)
if heat.heaters[1].current < var.hcTemp
  M568 P0 S{var.hcTemp} A2
  M116 P0
if !exists(global.refK0X)
  M98 P"0:/sys/hes_refdata.g"
if fileexists("0:/sys/hes_last.g")
  M98 P"0:/sys/hes_last.g"
if !exists(global.hesR) && fileexists("0:/sys/hes_cfg.g")
  M98 P"0:/sys/hes_cfg.g"
if !exists(global.k0OffX) && fileexists("0:/sys/k0offset.g")
  M98 P"0:/sys/k0offset.g"
if !exists(global.lastGoodG31)
  global lastGoodG31 = global.refG31Z
if !exists(global.hesFloor)
  global hesFloor = -999
if !exists(global.hesK0Clear)
  global hesK0Clear = -999
if !exists(global.eOwed)
  global eOwed = 0
var R = exists(global.hesR) ? global.hesR : 5.0
var hdX = exists(global.k0OffX) ? global.k0OffX : global.refHEX - global.refK0X
var hdY = exists(global.k0OffY) ? global.k0OffY : global.refHEY - global.refK0Y
var cX = exists(global.lastK0X) ? global.lastK0X : global.refK0X
var cY = exists(global.lastK0Y) ? global.lastK0Y : global.refK0Y
var fullXY = exists(param.O) && param.O == 1
var acceptBig = exists(param.A) && param.A == 1
var saveRef = exists(param.R) && param.R == 1
var fail = ""
var fc = 0               ; 2026-10-22: cause for the operator window (1 bed, 2 missed sensor, 3 apex, 4 nozzle no signal, 5 nozzle unstable, 6 stays pressed)
var cancelled = false    ; 2026-10-22: Cancel print in the G31 change window (stop after mesh/filament restore)
var meshWas = move.compensation.type == "mesh"
var meshPath = "" ^ move.compensation.file     ; KOPIA nazwy siatki (samo "= move.compensation.file" sledzi zywy obiekt i po G29 S2 robi sie puste)
var hop = exists(global.hopZ) ? global.hopZ : 5
var fastF = (exists(global.hopZ) && global.hopZ < 5) ? 24000 : 6000
var lvlWas = exists(global.levelDone) ? global.levelDone : false
; zmienne pomiarowe (deklarowane raz, poza petlami)
var zBed = 0
var rBed = 0
var zK0v = 0
var x0 = var.cX
var y0 = var.cY
var it = 0
var i = 0
var k1On = false
var px = 0
var py = 0
var lo = 0
var zz = vector(5, 0)
var dxs = {0, 1, -1, 0, 0}
var dys = {0, 0, 0, 1, -1}
var axf = 0
var ayf = 0
var settled = false
var manK1 = false        ; 2026-10-19: K0 start point set by hand (0:/sys/hes_manual.g) - wider dive windows
var settled2 = false
var settledB = false
var settledK = false
var zk = 0
var zHEv = 0
var xN = 0
var yN = 0
var xa = 0
var ya = 0
var offX = 0
var offY = 0
var prev = 0
var havePrev = false
var nd = 0
var zWin = 0
var zHEtop = 0
var ez = vector(4, 0)
var exs = {1, -1, 0, 0}
var eys = {0, 0, 1, -1}
var edgeOk = true
var Rest = 0
var den = 0
var t0 = state.upTime
; K0Tip samoczynnie sie zamyka po pomiarach, a hes_vdive.g (stol) nie wola deployprobe0.g - jawne otwarcie
; (szybkie wyjscie, gdy otwarta; inaczej komunikat "Manual Deploy" i czekanie na Ciebie)
M98 P"0:/sys/deployprobe0.g"
M83
; zaleglosc po przerwanej kalibracji (abort w hes_h.g nie oddaje filamentu) - oddaj PRZED nowym retractem, inaczej cofniecia
; sie sumuja (>= 9 mm i K1 gubi sygnal)
if global.eOwed > 0
  G1 E{global.eOwed} F600
  set global.eOwed = 0
G1 E{-var.calRetract} F900     ; retract na czas kalibracji (6 mm; 20 mm blokowalo K1)
set global.eOwed = var.calRetract   ; do oddania (przy przerwaniu oddaje cancel.g albo start.g)
G29 S2

; ---------- 0) Bed obok K1 ----------
; zjazd zgrubny z Z5.5 (1 mm/s, ok. 5 s) tylko do znalezienia stolu, potem zjazdy w waskim oknie (kilka sekund)
M98 P"0:/sys/hes_vdive.g" K0 X{var.cX + var.bedOff} Y{var.cY} S5.5 L0.3 N1 Q1
if !global.vdOk
  set var.fail = "HesCal2: K0 did not find the bed"
  set var.fc = 1
else
  set var.zBed = global.vdZ
  set var.nd = 0
  set var.havePrev = false
  while var.nd < 5 && !var.settledB
    M98 P"0:/sys/hes_h.g" K0 X{var.cX + var.bedOff} Y{var.cY} S{var.zBed + var.k0DiveStart} L{var.zBed - 0.25}
    if global.hSt == 2
      M98 P"0:/sys/hes_h.g" K0 X{var.cX + var.bedOff} Y{var.cY} S{var.zBed + var.k0DiveStart + 0.3} L{var.zBed - 0.25}
    set var.nd = var.nd + 1
    if global.hSt != 0
      set var.fail = "HesCal2: K0 bed dive failed (hSt " ^ global.hSt ^ ")"
      set var.fc = 1
      set var.nd = 99
    elif var.havePrev && abs(global.hZ - var.prev) <= var.agree
      set var.zBed = (global.hZ + var.prev) / 2
      set var.rBed = abs(global.hZ - var.prev)
      set var.settledB = true
    else
      set var.prev = global.hZ
      set var.havePrev = true
      set var.zBed = global.hZ
  if var.fail == "" && !var.settledB
    set var.fail = "HesCal2: bed dives disagree (agree " ^ var.agree ^ ")"
    set var.fc = 1
if var.fail == ""
  set global.hesK0Clear = var.zBed + var.k0Clear   ; od tej chwili zjazdy K0 startuja >= k0Clear nad stolem (hes_h.g)
  ; ochrona stolu dla dyszy ustawiana w kroku 2 (od czubka K1, po pomiarze K0 na czubku)

; ---------- 1) K0 na K1: 5 zjazdow, wierzcholek z krzywizny ----------
set var.zk = var.zBed + global.refTipBed   ; oczekiwana wysokosc wierzcholka dla K0
var zk0 = var.zk         ; expected apex height - start again from it after a manual K0 position
var redo = false
; 2026-10-19: every K0 dive that misses K1 (first or cross dive, hSt 1) opens 0:/sys/hes_manual.g: Manual = operator sets
; the K0 needle over the K1 tip by hand, HesCal2 starts this step again from there (loop until Stop); Stop = error as before
while var.fail == "" && !var.settled && var.it < 2
  ; wstepny zjazd w srodku (wynik NIE jest uzywany): pierwszy zjazd serii bywa ok. 0.04 mm nizej (HesTip 2026-10-07);
  ; ustawia tez okno kolejnych zjazdow tuz nad stykiem
  set var.redo = false
  set var.lo = max(var.zk - (var.manK1 ? 0.9 : 0.35), var.zBed + 0.03)   ; manual: within ~1-2 mm, contact up to ~0.3+ lower
  M98 P"0:/sys/hes_h.g" K0 X{var.cX} Y{var.cY} S{var.zk + 0.3} L{var.lo}
  if global.hSt == 2
    M98 P"0:/sys/hes_h.g" K0 X{var.cX} Y{var.cY} S{var.zk + 0.7} L{var.lo}
  if global.hSt == 1
    M98 P"0:/sys/hes_manual.g" Z{var.zk0 + 3}
    if global.hesManOk
      set var.cX = global.hesManX
      set var.cY = global.hesManY
      set var.manK1 = true
      set var.zk = var.zk0
      set var.it = 0
      set var.redo = true
    else
      set var.fail = "HesCal2: K0 missed K1 (first dive, hSt 1) - run HesFind"
      set var.fc = 2
  elif global.hSt != 0
    set var.fail = "HesCal2: K0 missed K1 (first dive, hSt " ^ global.hSt ^ ") - run HesFind"
    set var.fc = 2
  else
    set var.zk = global.hZ
  set var.i = 1
  while var.i < 5 && var.fail == "" && !var.redo
    set var.px = var.cX + var.dxs[var.i] * var.dK
    set var.py = var.cY + var.dys[var.i] * var.dK
    set var.lo = max(var.zk - (var.manK1 ? 0.6 : 0.25), var.zBed + 0.03)   ; manual start may be on the dome slope (13:50 test: +X missed with 0.25)
    M98 P"0:/sys/hes_h.g" K0 X{var.px} Y{var.py} S{var.zk + 0.12} L{var.lo}
    if global.hSt == 2
      M98 P"0:/sys/hes_h.g" K0 X{var.px} Y{var.py} S{var.zk + 0.45} L{var.lo}
    if global.hSt == 1
      M98 P"0:/sys/hes_manual.g" Z{var.zk0 + 3}
      if global.hesManOk
        set var.cX = global.hesManX
        set var.cY = global.hesManY
        set var.manK1 = true
        set var.zk = var.zk0
        set var.it = 0
        set var.redo = true
      else
        set var.fail = "HesCal2: K0 missed K1 (dive " ^ var.i ^ ", hSt 1) - run HesFind"
        set var.fc = 2
    elif global.hSt != 0
      set var.fail = "HesCal2: K0 missed K1 (dive " ^ var.i ^ ", hSt " ^ global.hSt ^ ") - run HesFind"
      set var.fc = 2
    else
      set var.zz[var.i] = global.hZ
    set var.i = var.i + 1
  if var.fail == "" && !var.redo
    ; wierzcholek: a = R (z(+d) - z(-d)) / (2d)
    set var.axf = var.R * (var.zz[1] - var.zz[2]) / (2 * var.dK)
    set var.ayf = var.R * (var.zz[3] - var.zz[4]) / (2 * var.dK)
    set var.x0 = var.cX + var.axf
    set var.y0 = var.cY + var.ayf
    if abs(var.axf) > 0.35 || abs(var.ayf) > 0.35
      ; wierzcholek daleko od srodka krzyza - powtorz wokol niego (okno wokol zmierzonej wysokosci)
      set var.cX = var.x0
      set var.cY = var.y0
      set var.it = var.it + 1
    else
      set var.settled = true
if var.fail == "" && !var.settled
  ; po 2 iteracjach nadal przesuniety - przyjmij ostatni wynik, ale ostrzez
  M98 P"0:/sys/hes_log.g" S"WARNING sensor tip off centre" L"WARNING HesCal2: K1 apex (nozzle sensor tip) still far from the K0 cross centre after 2 iterations - last result used, check K1 position"
  M98 P"0:/sys/hes_log.g" S" result used; check sensor position"
; wysokosc wierzcholka: zjazdy W wierzcholku (x0, y0) - pierwszy w nowym punkcie nieuzywany, potem dwa zgodne w agree
set var.nd = 0
set var.havePrev = false
set var.zWin = var.zk
while var.fail == "" && var.nd < 5 && !var.settledK
  M98 P"0:/sys/hes_h.g" K0 X{var.x0} Y{var.y0} S{var.zWin + 0.1} L{max(var.zWin - 0.2, var.zBed + 0.03)}
  if global.hSt == 2
    M98 P"0:/sys/hes_h.g" K0 X{var.x0} Y{var.y0} S{var.zWin + 0.4} L{max(var.zWin - 0.2, var.zBed + 0.03)}
  set var.nd = var.nd + 1
  if global.hSt != 0
    set var.fail = "HesCal2: K0 missed K1 apex (hSt " ^ global.hSt ^ ")"
    set var.fc = 3
  elif var.nd == 1
    set var.zWin = global.hZ
  elif var.havePrev && abs(global.hZ - var.prev) <= var.agree
    set var.zK0v = (global.hZ + var.prev) / 2
    set var.settledK = true
  else
    set var.prev = global.hZ
    set var.havePrev = true
    set var.zWin = global.hZ
if var.fail == "" && !var.settledK
  set var.fail = "HesCal2: K0 apex dives disagree (agree " ^ var.agree ^ ")"
  set var.fc = 3

; ---------- 2) dysza na K1 ----------
if var.fail == ""
  set var.xN = var.x0 + var.hdX     ; oczekiwany wierzcholek we wspolrzednych dyszy: K0 + zapisane przesuniecie
  set var.yN = var.y0 + var.hdY
  ; dysza styka wierzcholek na Z = zK0v - G31 (dysza opuszczona o G31 wzgledem K0); K1 zadziala nieco nizej
  set var.zHEtop = var.zK0v - (global.refK0v - global.refHEv)   ; oczekiwana wysokosc dyszy przy zadzialaniu K1 (wzgledna, niezalezna od kThr/G31)
  ; ochrona: nie nizej niz floorMargin pod oczekiwanym zadzialaniem K1 i nie blizej niz 0.3 mm nad stolem obok K1 (styk ~ zBed - G31).
  ; Do 2026-10-13 floor liczony od stolu obok K1 ucinal zjazd, gdy tipBed spadl o >= floorMargin pod refTipBed.
  set global.hesFloor = max(var.zHEtop - var.floorMargin, var.zBed - sensors.probes[0].triggerHeight + 0.3)
  M400   ; K1 jest stala sonda (config.g) - bez przelaczania J2
  M400   ; K1 jest stala sonda (config.g) - bez przelaczania J2
  M400   ; K1 jest stala sonda (config.g) - bez przelaczania J2
  set var.k1On = true

; --- pelny pomiar XY po zboczach pierscienia: 4 zjazdy +-dHE od oczekiwanego wierzcholka ---
if var.fail == "" && var.fullXY
  set var.i = 0
  while var.i < 4 && var.fail == "" && var.edgeOk
    set var.px = var.xN + var.exs[var.i] * var.dHE
    set var.py = var.yN + var.eys[var.i] * var.dHE
    M98 P"0:/sys/hes_h.g" K1 X{var.px} Y{var.py} S{var.zHEtop + 0.3} L{var.zHEtop - 0.3}
    if global.hSt == 2
      M98 P"0:/sys/hes_h.g" K1 X{var.px} Y{var.py} S{var.zHEtop + 0.8} L{var.zHEtop - 0.3}
    if global.hSt != 0
      set var.edgeOk = false
    else
      set var.ez[var.i] = global.hZ
    set var.i = var.i + 1
  if var.edgeOk
    ; a = R dz / (2 dHE), dz = z(+) - z(-)  (parabola jak K0)
    set var.xa = var.xN + var.R * (var.ez[0] - var.ez[1]) / (2 * var.dHE)
    set var.ya = var.yN + var.R * (var.ez[2] - var.ez[3]) / (2 * var.dHE)
    set var.offX = var.xa - var.x0
    set var.offY = var.ya - var.y0
    set var.xN = var.xa
    set var.yN = var.ya
  else
    M98 P"0:/sys/hes_log.g" S"WARNING nozzle X/Y not measured" L"WARNING HesCal2: nozzle XY over K1 not found - K0->nozzle offset (G31 X/Y, k0offset.g) kept unchanged"
    M98 P"0:/sys/hes_log.g" S" old offset kept"
    set var.fullXY = false

; --- Z dyszy: do 4 zjazdow w srodku pierscienia, dwa kolejne zgodne w agree ---
set var.nd = 0
set var.havePrev = false
set var.zWin = var.zHEtop
while var.fail == "" && var.nd < 5 && !var.settled2
  M98 P"0:/sys/hes_h.g" K1 X{var.xN} Y{var.yN + var.heYoff} S{var.zWin + (var.nd == 0 ? 0.3 : 0.1)} L{var.zWin - (var.nd == 0 ? 0.3 : 0.2)}
  if global.hSt == 2
    M98 P"0:/sys/hes_h.g" K1 X{var.xN} Y{var.yN + var.heYoff} S{var.zWin + 0.8} L{var.zWin - 0.3}
  set var.nd = var.nd + 1
  if global.hSt != 0
    set var.fail = "HesCal2: nozzle gave no K1 reading (hSt " ^ global.hSt ^ ", floor " ^ global.hesFloor ^ ", expected " ^ var.zHEtop ^ ")"
    set var.fc = 4
    set var.fail = var.fail ^ "; K1 over bed " ^ (var.zK0v - var.zBed) ^ " (ref " ^ global.refTipBed ^ ") - check K1 signal/lever and nozzle position"
  elif var.nd == 1
    set var.zWin = global.hZ    ; zjazd wstepny (pierwszy w nowym punkcie wypada ok. 0.02 nizej) - tylko ustawia okno
  elif var.havePrev && abs(global.hZ - var.prev) <= var.agree
    set var.zHEv = (global.hZ + var.prev) / 2
    set var.settled2 = true
  else
    set var.prev = global.hZ
    set var.havePrev = true
    set var.zWin = global.hZ
if var.fail == "" && !var.settled2
  set var.fail = "HesCal2: nozzle dives disagree (agree " ^ var.agree ^ ") - check K1/nozzle"
  set var.fc = 5
; sprzatanie K1
if var.k1On
  M400   ; K1 jest stala sonda (config.g) - bez przelaczania J2
  M400   ; K1 jest stala sonda (config.g) - bez przelaczania J2
set global.hesFloor = -999
set global.hesK0Clear = -999
if var.k1On
  G1 Z{var.hop} F600
  G1 X{global.wiperX} Y{global.wiperY + global.parkYOffset} F{var.fastF}
  G1 Z{var.hop} F600
else
  G1 Z{var.hop} F600
M400
if var.fail != ""
  if var.meshWas
    G29 S1 P{var.meshPath}
  M83
  G1 E{var.calRetract} F600
  set global.eOwed = 0
  if exists(global.hSt) && global.hSt == 9
    set var.fc = 6
  var cs = "The probe or sensor stays pressed after lifting."
  var ck = "lever stuck, dirt."
  var sl = "ERROR sensor stays pressed"
  if var.fc == 1
    set var.cs = "The bed probe could not measure the bed next to the sensor."
    set var.ck = "nothing on the bed beside the sensor; probe needle clean."
    set var.sl = "ERROR probe: bed next to sensor"
  elif var.fc == 2
    set var.cs = "The bed probe did not hit the sensor tip."
    set var.ck = "sensor position and lever (service: HesFind)."
    set var.sl = "ERROR probe missed sensor"
  elif var.fc == 3
    set var.cs = "Probe readings on the sensor tip disagree."
    set var.ck = "sensor tip clean, sensor lever not loose."
    set var.sl = "ERROR probe on sensor: unstable"
  elif var.fc == 4
    set var.cs = "The nozzle did not trigger the nozzle sensor."
    set var.ck = "plastic blob on the nozzle (button < Clean), sensor cable/lever."
    set var.sl = "ERROR nozzle did not trigger sensor"
  elif var.fc == 5
    set var.cs = "Nozzle readings on the sensor disagree."
    set var.ck = "plastic on the nozzle or sensor tip."
    set var.sl = "ERROR nozzle on sensor: unstable"
  M98 P"0:/sys/hes_log.g" S{var.sl} L{"ERROR HesCal2 calibration failed: " ^ var.fail}
  ; 2026-10-17: in a print (start.g) do NOT cancel - window, operator fixes K0/K1 and decides (heating stays on).
  ; 2026-10-22: Measure / Clean (wipe, then measure) / Use last (good G31) / Cancel (print). 261022: labels <= 8 chars (PanelDue 125 px).
  if job.file.fileName != null || state.status == "processing"
    var lgOk = exists(global.lastGoodG31) && global.lastGoodG31 > 0.3 && global.lastGoodG31 < 2
    M300 S2500 P300
    M300 S1800 P300
    var m = var.cs ^ " Check: " ^ var.ck
    var sLg = ""
    if var.lgOk
      M98 P"0:/sys/fmt3.g" V{global.lastGoodG31}
      set var.sLg = global.fmt
      set var.m = var.m ^ " Use last = print with the last good offset " ^ var.sLg ^ " mm."
    set var.m = var.m ^ " Heaters and motors stay on."
    M98 P"0:/sys/op_wait.g" S1 W"operator"
    G4 P400
    if var.lgOk
      M291 P{var.m} R"Nozzle calibration failed" S4 K{"Measure", "< Clean", "Use last", "Cancel"}
    else
      M291 P{var.m} R"Nozzle calibration failed" S4 K{"Measure", "< Clean", "Cancel"}
    var ch = input
    M98 P"0:/sys/op_wait.g" S0
    if var.ch == 0 || var.ch == 1
      if exists(global.hesRepeat)
        set global.hesRepeat = true
      if var.ch == 1 && exists(global.hesBackWipe)
        set global.hesBackWipe = true
      M99
    if var.ch == 2 && var.lgOk
      if abs(sensors.probes[0].triggerHeight - global.lastGoodG31) > 0.001
        G31 K0 Z{global.lastGoodG31}
        if !exists(global.hesQuiet)
          global hesQuiet = false
        set global.hesQuiet = true
        G28 Z                   ; homez.g clears skipCal and levelDone - levelDone restored below
        M400
        set global.hesQuiet = false
        if !exists(global.levelDone)
          global levelDone = false
        set global.levelDone = var.lvlWas
      M98 P"0:/sys/hes_log.g" S{"Probe offset: " ^ var.sLg ^ " mm (last good)"} L{"Operator: print with the last good G31 " ^ var.sLg ^ " mm (HesCal2 failed)"}
      M99
    abort "Calibration stopped by operator"
  abort "Calibration stopped - cause in the console; filament and mesh restored"

; ---------- 3) wyniki ----------
var g31bed = var.zBed - (var.zHEv - var.kThr)    ; "od stolu" - zalezy od stolu obok K1 (plywa po duzym G32): kontrola i kotwica R1
var dz = var.zK0v - var.zHEv
var tipBed = var.zK0v - var.zBed
var g31tip = var.dz - global.refTipBed + var.kThr ; "od czubka" - tylko dz i stale z R1, niezalezne od stolu
var g31 = var.g31tip                               ; metoda glowna (od 2026-10-13; kolumna G31Z w hes_hist = ta wartosc)
if !var.fullXY
  set var.offX = var.xN - var.x0
  set var.offY = var.yN - var.y0
var okMethods = abs(var.g31bed - var.g31tip) <= var.tolG31Methods   ; tylko ostrzezenie
var okVsLastGood = abs(var.g31 - global.lastGoodG31) < var.tolG31Live
; sugestia regulacji sruby K1 (zapas K1 nad K0 wzgledem celu)
var kMarg = var.zHEv - var.zBed
var turns = (var.kMarg - var.kMargin) / var.screwMmPerTurn
var tw = floor(abs(var.turns) * 12 + 0.5)   ; obroty w dwunastych czesciach
var tWhole = floor(var.tw / 12)
var tRem = mod(var.tw, 12)
; ulamki zwykle (czytelne dla czlowieka): 1/6 1/4 1/3 1/2 2/3 3/4 5/6
var tFrac = (var.tRem < 1 ? "" : (var.tRem < 3 ? "1/6" : (var.tRem < 4 ? "1/4" : (var.tRem < 6 ? "1/3" : (var.tRem < 8 ? "1/2" : (var.tRem < 9 ? "2/3" : (var.tRem < 10 ? "3/4" : "5/6")))))))
var turnsTxt = (var.tWhole > 0 ? var.tWhole ^ (var.tFrac != "" ? " " : "") : "") ^ var.tFrac
var sugg = "K1 screw: OK"
if abs(var.kMarg - var.kMargin) > var.kMarginTol
  set var.sugg = "K1 screw: " ^ (var.kMarg > var.kMargin ? "tighten " : "loosen ") ^ var.turnsTxt ^ " turn"
; historia (ten sam format co HesCal)
if !fileexists("0:/sys/hes_hist.csv")
  echo >"0:/sys/hes_hist.csv" "czas,zBed,x0,y0,zK0v,k1Stol,xHE,yHE,zHEv,dzK0HE,offX,offY,G31Z,wynik"
var row = state.time ^ "," ^ var.zBed ^ "," ^ var.x0 ^ "," ^ var.y0 ^ "," ^ var.zK0v ^ "," ^ var.tipBed
set var.row = var.row ^ "," ^ var.xN ^ "," ^ var.yN ^ "," ^ var.zHEv ^ "," ^ var.dz
set var.row = var.row ^ "," ^ var.offX ^ "," ^ var.offY ^ "," ^ var.g31 ^ "," ^ (var.okVsLastGood ? (var.okMethods ? "OK2" : "OK2-STOL") : "KALIBRACJA2")
echo >>"0:/sys/hes_hist.csv" var.row
; ostatnie polozenia - srodek szukania nastepnym razem
echo >"0:/sys/hes_last.g" "; hes_last.g - HesCal2 " ^ state.time
echo >>"0:/sys/hes_last.g" "if !exists(global.lastK0X)"
echo >>"0:/sys/hes_last.g" "  global lastK0X = 0"
echo >>"0:/sys/hes_last.g" "  global lastK0Y = 0"
echo >>"0:/sys/hes_last.g" "  global lastHEX = 0"
echo >>"0:/sys/hes_last.g" "  global lastHEY = 0"
echo >>"0:/sys/hes_last.g" "set global.lastK0X = " ^ var.x0
echo >>"0:/sys/hes_last.g" "set global.lastK0Y = " ^ var.y0
echo >>"0:/sys/hes_last.g" "set global.lastHEX = " ^ var.xN
echo >>"0:/sys/hes_last.g" "set global.lastHEY = " ^ var.yN
if var.saveRef
  set var.g31 = var.g31bed     ; R1: kotwica bezwzgledna = metoda od stolu (stol obok K1 reprezentatywny); od czubka dopasowuje sie przez refTipBed
  echo >"0:/sys/hes_refdata.g" "; hes_refdata.g - dane odniesienia (HesCal2 R1, " ^ state.time ^ ")"
  echo >>"0:/sys/hes_refdata.g" "if !exists(global.refK0X)"
  echo >>"0:/sys/hes_refdata.g" "  global refK0X = 0"
  echo >>"0:/sys/hes_refdata.g" "  global refK0Y = 0"
  echo >>"0:/sys/hes_refdata.g" "  global refHEX = 0"
  echo >>"0:/sys/hes_refdata.g" "  global refHEY = 0"
  echo >>"0:/sys/hes_refdata.g" "  global refTipBed = 0"
  echo >>"0:/sys/hes_refdata.g" "  global refK0v = 0"
  echo >>"0:/sys/hes_refdata.g" "  global refHEv = 0"
  echo >>"0:/sys/hes_refdata.g" "  global refG31Z = 0"
  echo >>"0:/sys/hes_refdata.g" "set global.refK0X = " ^ var.x0
  echo >>"0:/sys/hes_refdata.g" "set global.refK0Y = " ^ var.y0
  echo >>"0:/sys/hes_refdata.g" "set global.refHEX = " ^ var.xN
  echo >>"0:/sys/hes_refdata.g" "set global.refHEY = " ^ var.yN
  echo >>"0:/sys/hes_refdata.g" "set global.refTipBed = " ^ var.tipBed
  echo >>"0:/sys/hes_refdata.g" "set global.refK0v = " ^ var.zK0v
  echo >>"0:/sys/hes_refdata.g" "set global.refHEv = " ^ var.zHEv
  echo >>"0:/sys/hes_refdata.g" "set global.refG31Z = " ^ var.g31
  set global.refK0X = var.x0
  set global.refK0Y = var.y0
  set global.refHEX = var.xN
  set global.refHEY = var.yN
  set global.refTipBed = var.tipBed
  set global.refK0v = var.zK0v
  set global.refHEv = var.zHEv
  set global.refG31Z = var.g31
  set global.lastGoodG31 = var.g31
  M98 P"0:/sys/hes_log.g" D"HesCal2 R1: this run saved as the new reference (hes_refdata.g: refTipBed, refG31Z, K0/K1 positions)"
  ; bramki liczone wczesniej uzywaly STAREGO refTipBed/lastGoodG31 - po R1 licz je od nowa (nowe odniesienie = ten pomiar)
  set var.g31tip = var.dz - global.refTipBed + var.kThr
  set var.okMethods = abs(var.g31bed - var.g31tip) <= var.tolG31Methods
  set var.okVsLastGood = abs(var.g31 - global.lastGoodG31) < var.tolG31Live

; ---------- przesuniecie K0 -> dysza (G31 X/Y): zapis tylko po pelnym pomiarze O1 ----------
var offWritten = false
if var.fullXY
  var curX = sensors.probes[0].offsets[0]
  var curY = sensors.probes[0].offsets[1]
  var bigChange = abs(var.offX - var.curX) > var.tolOffAccept || abs(var.offY - var.curY) > var.tolOffAccept
  if var.bigChange && !var.acceptBig
    M98 P"0:/sys/hes_log.g" D{"K0 offset change > " ^ var.tolOffAccept ^ " - NOT saved (O1 A1)"}
  else
    echo >"0:/sys/k0offset.g" "; k0offset.g - przesuniecie K0 wzgledem dyszy = G31 X Y (HesCal2 O1, " ^ state.time ^ ")"
    echo >>"0:/sys/k0offset.g" "if !exists(global.k0OffX)"
    echo >>"0:/sys/k0offset.g" "  global k0OffX = 0"
    echo >>"0:/sys/k0offset.g" "  global k0OffY = 0"
    echo >>"0:/sys/k0offset.g" "set global.k0OffX = " ^ var.offX
    echo >>"0:/sys/k0offset.g" "set global.k0OffY = " ^ var.offY
    echo >>"0:/sys/k0offset.g" "G31 K0 X" ^ var.offX ^ " Y" ^ var.offY
    if !exists(global.k0OffX)
      global k0OffX = 0
      global k0OffY = 0
    set global.k0OffX = var.offX
    set global.k0OffY = var.offY
    set var.offWritten = true
    M98 P"0:/sys/hes_log.g" D"K0 offset X/Y saved (k0offset.g)"

; ---------- G31 Z ----------
; ZABEZPIECZENIE: kThr <= 0 = "nie zmierzone" - nie zapisujemy G31 (ani nie robimy G28 Z), tylko raportujemy
var lastBefore = exists(global.lastGoodG31) ? global.lastGoodG31 : 0   ; for the summary (lastGoodG31 may change below)
var res = ""                ; result line of the summary
var resK = ""               ; 2026-10-22: result kind for the operator line (measured/operator/lastgood/repeat/notset/blocked)
var rej = false             ; measured G31 rejected (KALIBRACJA2)
if var.kThr <= 0
  set var.res = "G31 NOT SET: kThr not measured"
  set var.resK = "notset"
elif var.okVsLastGood
  set var.g31 = var.g31 + var.manualZTrim
  if var.offWritten
    G31 K0 X{var.offX} Y{var.offY} Z{var.g31}
  else
    G31 K0 Z{var.g31}
  if !exists(global.hesQuiet)
    global hesQuiet = false
  set global.hesQuiet = true
  G28 Z                       ; homez.g zeruje skipCal i levelDone - levelDone przywracamy (G28 Z nie rusza srub)
  M400
  set global.hesQuiet = false
  if !exists(global.levelDone)
    global levelDone = false
  set global.levelDone = var.lvlWas
  set global.lastGoodG31 = var.g31
  if !exists(global.skipCal)
    global skipCal = false
  set global.skipCal = true
  M98 P"0:/sys/fmt4.g" V{var.g31}
  set var.res = "G31 SET " ^ global.fmt ^ " (measured)"
  set var.resK = "measured"
else
  set var.rej = true
  ; 2026-10-16: operator decides (window) - Use measured / Repeat. No window for R1 and for test runs (lastGoodG31 = 99).
  var ask = exists(global.lastGoodG31) && global.lastGoodG31 > 0.3 && global.lastGoodG31 < 2 && !var.saveRef && var.kThr > 0
  var choice = -1
  if var.ask
    M98 P"0:/sys/fmt3.g" V{var.g31}
    var sMeas = global.fmt
    M98 P"0:/sys/fmt3.g" V{global.lastGoodG31}
    var sLast = global.fmt
    M98 P"0:/sys/fmt3.g" V{abs(var.g31 - global.lastGoodG31)}
    var sDiff = global.fmt
    M98 P"0:/sys/hes_log.g" S{"ERROR probe offset changed " ^ var.sDiff ^ " mm"} L{"G31 (K0 trigger height) measured " ^ var.sMeas ^ " mm vs last good " ^ var.sLast ^ " mm, difference " ^ var.sDiff ^ " mm > tolG31Live " ^ var.tolG31Live ^ " mm"}
    M98 P"0:/sys/op_wait.g" S1 W"operator"
    M300 S2500 P300
    M300 S1800 P300
    while var.choice < 0
      M98 P"0:/sys/fmt3.g" V{var.tolG31Live}
      var m = "New offset " ^ var.sMeas ^ " mm, last good " ^ var.sLast ^ " mm: change " ^ var.sDiff ^ " mm (max " ^ global.fmt ^ ")."
      set var.m = var.m ^ " If you adjusted the bed sheet, nozzle or sensor, Accept the new value. Otherwise Measure again. Heaters and motors stay on."
      G4 P400
      M291 P{var.m} R"Probe offset changed" S4 K{"Accept", "Measure", "Set limit", "Cancel"}
      var k = input
      if var.k < 2
        set var.choice = var.k
      elif var.k == 3
        set var.choice = 3
        set var.cancelled = true
      else
        var oldTol = var.tolG31Live
        M98 P"0:/sys/tol_ask.g" S"tolG31Live" V{var.tolG31Live} A{global.tolG31LiveR[0]} B{global.tolG31LiveR[1]} L{global.tolG31LiveR[2]} H{global.tolG31LiveR[3]} T"HESCAL2 - CHANGE TOL"
        if global.tolAskVal >= 0
          set var.tolG31Live = global.tolAskVal
          set global.tolG31Live = global.tolAskVal
          M98 P"0:/sys/tol_save.g" S"tolG31Live" V{var.oldTol} N{global.tolG31Live}
          if abs(var.g31 - global.lastGoodG31) < var.tolG31Live
            set var.choice = 0          ; within the new tolerance = accepted measurement
  if var.ask
    M98 P"0:/sys/op_wait.g" S0
  if var.choice == 0
    ; operator: continue with the measured G31 (same as an accepted measurement)
    set var.g31 = var.g31 + var.manualZTrim
    if var.offWritten
      G31 K0 X{var.offX} Y{var.offY} Z{var.g31}
    else
      G31 K0 Z{var.g31}
    if !exists(global.hesQuiet)
      global hesQuiet = false
    set global.hesQuiet = true
    G28 Z
    M400
    set global.hesQuiet = false
    if !exists(global.levelDone)
      global levelDone = false
    set global.levelDone = var.lvlWas
    set global.lastGoodG31 = var.g31
    if !exists(global.skipCal)
      global skipCal = false
    set global.skipCal = true
    M98 P"0:/sys/fmt4.g" V{var.g31}
    set var.res = "G31 SET " ^ global.fmt ^ " (operator)"
    set var.resK = "operator"
  elif var.choice == 1
    ; operator: repeat - G31 unchanged, 0:/macros/HesCal2 runs the measurement again
    if exists(global.hesRepeat)
      set global.hesRepeat = true
    set var.res = "REPEAT requested - G31 unchanged"
    set var.resK = "repeat"
  ; awaryjnie ostatnie przyjete G31 zamiast wartosci z config.g (2026-10-13: 0.9 z config = warstwa ok. 0.09 mm za nisko).
  ; Zakres 0.3..2: lastGoodG31 = 99 sluzy jako blokada zapisu G31 przy testach. Bez skipCal - nastepny start mierzy ponownie.
  if var.choice >= 0
    M400                        ; decided by the operator above
  elif exists(global.lastGoodG31) && global.lastGoodG31 > 0.3 && global.lastGoodG31 < 2
    if abs(sensors.probes[0].triggerHeight - global.lastGoodG31) > 0.001
      if var.offWritten
        G31 K0 X{var.offX} Y{var.offY} Z{global.lastGoodG31}
      else
        G31 K0 Z{global.lastGoodG31}
      if !exists(global.hesQuiet)
        global hesQuiet = false
      set global.hesQuiet = true
      G28 Z                     ; jak wyzej: homez.g zeruje skipCal i levelDone - levelDone przywracamy
      M400
      set global.hesQuiet = false
      if !exists(global.levelDone)
        global levelDone = false
      set global.levelDone = var.lvlWas
    M98 P"0:/sys/fmt4.g" V{global.lastGoodG31}
    set var.res = "G31 SET " ^ global.fmt ^ " (last good)"
    set var.resK = "lastgood"
  else
    set var.res = "G31 unchanged (lastGoodG31 blocked)"
    set var.resK = "blocked"

; ---------- siatka i filament ----------
if var.meshWas
  G29 S1 P{var.meshPath}      ; przywroc siatke sprzed kalibracji (np. z Mesh)
else
  G29 S1 P"HMInterpolated.csv"
M400
M83
G1 E{var.calRetract} F600                ; kompensacja retractu sprzed kalibracji
set global.eOwed = 0
; ---------- summary ----------
; 2026-10-22 (task 15): PanelDue = DONE + probe offset (+ WARNING out of limits, 2 lines); service values DWC only.
M98 P"0:/sys/fmt4.g" V{var.tipBed}
var sTip = global.fmt
M98 P"0:/sys/fmt4.g" V{global.refTipBed}
var sRef = global.fmt
M98 P"0:/sys/fmt4.g" V{var.dz}
var sDz = global.fmt
M98 P"0:/sys/fmt4.g" V{var.kMarg}
var sMarg = global.fmt
M98 P"0:/sys/fmt4.g" V{var.g31tip}
var sTipG = global.fmt
M98 P"0:/sys/fmt4.g" V{var.g31bed}
var sBedG = global.fmt
M98 P"0:/sys/hes_log.g" D{"K1 tip/bed (K1 tip above bed, by K0): " ^ var.sTip ^ " mm, R1 reference " ^ var.sRef ^ " mm"}
M98 P"0:/sys/hes_log.g" D{"dz (Z: nozzle on K1 minus K0 on K1 tip): " ^ var.sDz ^ " mm; K1 margin (K1 trigger above K0, target " ^ var.kMargin ^ "): " ^ var.sMarg ^ " mm"}
M98 P"0:/sys/hes_log.g" D{var.sugg}
M98 P"0:/sys/hes_log.g" D{"G31 (nozzle above bed at K0 trigger): tip method " ^ var.sTipG ^ " mm, bed method " ^ var.sBedG ^ " mm"}
if var.rej
  M98 P"0:/sys/fmt4.g" V{var.lastBefore}
  M98 P"0:/sys/hes_log.g" D{"G31 REJECTED: change vs last good " ^ global.fmt ^ " mm > tolG31Live " ^ var.tolG31Live ^ " mm"}
M98 P"0:/sys/hes_log.g" D{var.res}
if var.cancelled
  abort "Calibration stopped by operator"
if var.resK == "repeat"
  M99                           ; wrapper 0:/macros/HesCal2 prints "Measuring again" and measures again
M98 P"0:/sys/hes_log.g" S{"-- NOZZLE CALIBRATION DONE  " ^ (state.upTime - var.t0) ^ " s --"}
M98 P"0:/sys/fmt3.g" V{sensors.probes[0].triggerHeight}
var sNow = global.fmt
M98 P"0:/sys/fmt3.g" V{var.lastBefore}
if var.resK == "measured"
  M98 P"0:/sys/hes_log.g" S{"Probe offset: " ^ var.sNow ^ " mm (last " ^ global.fmt ^ ")"}
elif var.resK == "operator"
  M98 P"0:/sys/hes_log.g" S{"Probe offset: " ^ var.sNow ^ " mm (your choice)"}
elif var.resK == "lastgood"
  M98 P"0:/sys/hes_log.g" S{"Probe offset: " ^ var.sNow ^ " mm (last good)"}
elif var.resK == "notset"
  M98 P"0:/sys/hes_log.g" S"WARNING probe offset not set" L"WARNING G31 not set: kThr not measured (hescal2_m.g)"
  M98 P"0:/sys/hes_log.g" S" kThr not measured (service)"
else
  M98 P"0:/sys/hes_log.g" S{"Probe offset: " ^ var.sNow ^ " mm (unchanged)"}
if !var.okMethods
  M98 P"0:/sys/fmt3.g" V{abs(var.g31bed - var.g31tip)}
  var sMd = global.fmt
  M98 P"0:/sys/fmt3.g" V{var.tolG31Methods}
  M98 P"0:/sys/hes_log.g" S{"WARNING calibration check off " ^ var.sMd ^ " mm"} L{"WARNING G31 methods differ: tip-bed " ^ var.sMd ^ " mm > tolG31Methods " ^ global.fmt ^ " mm"}
  M98 P"0:/sys/hes_log.g" S{" max " ^ global.fmt ^ " - check 1st layer"}
if abs(var.kMarg - var.kMargin) > var.kMarginTol
  M98 P"0:/sys/fmt3.g" V{var.kMarg}
  M98 P"0:/sys/hes_log.g" S{"WARNING nozzle sensor margin " ^ global.fmt ^ " mm"} L{"WARNING K1 margin " ^ global.fmt ^ " mm (target " ^ var.kMargin ^ " +- " ^ var.kMarginTol ^ ") - " ^ var.sugg}
  M98 P"0:/sys/hes_log.g" S{" after print: " ^ (var.kMarg > var.kMargin ? "tighten" : "loosen") ^ " K1 " ^ var.turnsTxt ^ " turn"}
