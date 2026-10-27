; hes_h.g - wysokość zadziałania sondy K (domyślnie K0) w punkcie X/Y: przejazd XY na Z = S, wolny zjazd
; (0.5 mm/s) do L, potem odjazd w górę do odsłonięcia czujnika. K0 i K1 działają w trybie ciągłym - odsłaniają
; się po cofnięciu ruchu. Odsłanianie zwykłym G1 (G38.x woła deployprobe0.g, które przy zasłoniętym czujniku
; prosi o ręczne wysunięcie). Dla K1 wywołujący musi zdefiniować sondę (zwolnienie J2, M558 K1).
; Wynik: global.hSt (0 = zadziałała, 1 = brak zadziałania do L, 2 = zasłonięta już na wysokości S, 9 = zablokowana w druku), global.hZ
; (Z bywa ujemne - stanu nie wolno wnioskować ze znaku Z); wiersz w hes_h.csv
if !exists(global.hZ)
  global hZ = 0
if !exists(global.hSt)
  global hSt = 1
set global.hZ = 0
set global.hSt = 1
var k = exists(param.K) ? param.K : 0
var n = 0
var z = 0
var unblockCap = 150   ; limit podniesienia przy odslanianiu = unblockCap*0.01mm (dzis 1.5mm) - patrz nizej
var spd = exists(param.V) ? param.V : ((var.k == 0) ? 80 : 30)   ; dive speed [mm/min] (param V); K0 80 = homing fine speed (2026-10-16), K1 30
; OCHRONA STOLU: HesCal ustawia global.hesFloor (najnizsze bezpieczne Z dyszy = styk dyszy ze stolem + margines);
; dla K1 (dysza naciska K1) limit zjazdu nigdy nizej. K1 jest tylko ~0.3 mm nad stolem, a limity zjazdow (np.
; hb - 0.3 we wspinaczce) siegalyby pod stol.
var Lc = param.L
if var.k == 1 && exists(global.hesFloor)
  set var.Lc = max(param.L, global.hesFloor)
; K0 to recznie wysuwana igla (deployprobe0.g) - petla odslaniania nizej uzywa zwyklego G1, wiec (w
; odroznieniu od G38.3) NIE wywola sama deployprobe0.g, jesli igla jest w stanie cofnietym. Jawne
; wywolanie tutaj - ma szybkie wyjscie, gdy juz otwarta, wiec bezpieczne przy kazdym zjezdzie K0.
if var.k == 0
  M98 P"0:/sys/deployprobe0.g" C"calibration"   ; 2026-10-22: K0 closed during HesCal2 (task 15 window text)
M400
while sensors.probes[var.k].value[0] >= sensors.probes[var.k].threshold && var.n < var.unblockCap
  G91
  G1 Z0.01 F60
  G90
  M400
  set var.n = var.n + 1
G90
if sensors.probes[var.k].value[0] >= sensors.probes[var.k].threshold
  ; przekroczony limit podniesienia bez odslonięcia - dalsza jazda nie ma sensu (ani w kolejnych probach
  ; w innych punktach - stad "stol caly czas sie oddala" widziane wczesniej). abort (nie M99!) zatrzymuje
  ; cala kalibracje, ale NIE wylacza silnikow (M18/M84) - zasilanie i bazowanie zostaja zachowane.
  M98 P"0:/sys/hes_log.g" D{"ERROR K" ^ var.k ^ " stays triggered after " ^ (var.unblockCap * 0.01) ^ " mm lift"}
  if job.file.fileName != null || state.status == "processing"
    set global.hSt = 9          ; 2026-10-17: in a print no abort - caller (HesCal2) shows the operator window
    M99
  abort "hes_h.g: probe stays triggered after lifting - check lever/sensor (stuck mechanically or electrically). Which probe: see console. Motors NOT disabled."
; CLEARANCE K0: K0 wystaje pod dysza i do prawidlowego poczatku pomiaru oraz przejazdow potrzebuje >= 1 mm nad stolem.
; HesCal2/HesTip ustawiaja global.hesK0Clear = zBed + 1.0 (-999 = wylaczone). Dla K0 (kazdy zjazd) i dla kazdego
; wiekszego przejazdu XY (> 3 mm) Z przejazdu i poczatek zjazdu nie nizej niz hesK0Clear.
var zTravel = max(move.axes[2].machinePosition, param.S)
if exists(global.hesK0Clear)
  var dxy = abs(param.X - move.axes[0].machinePosition) + abs(param.Y - move.axes[1].machinePosition)
  if var.k == 0 || var.dxy > 3
    ; hop dokladnie na wysokosc clearance (moze byc NIZEJ niz biezace Z - nie podnosimy bez potrzeby), ale nie nizej niz start zjazdu
    set var.zTravel = max(param.S, global.hesK0Clear)
G1 Z{var.zTravel} F300
G1 X{param.X} Y{param.Y} F600
M400
if sensors.probes[var.k].value[0] >= sensors.probes[var.k].threshold
  set global.hSt = 2
  set global.hZ = param.S
elif var.Lc >= param.S - 0.005
  ; floor wypadl nad poczatkiem zjazdu - brak miejsca na zjazd, bez ruchu w dol (hSt zostaje 1 = brak zadzialania)
  M98 P"0:/sys/hes_log.g" D"hes_h: floor >= start - dive skipped"
else
  G38.3 K{var.k} Z{var.Lc} F{var.spd}
  M400
  set var.z = move.axes[2].machinePosition
  ; o zadziałaniu decyduje stan czujnika po zjeździe - pozycja Z jest zaokrąglana do mikrokroku (0.0025),
  ; więc porównanie z limitem myliło dojazd do limitu z zadziałaniem
  if sensors.probes[var.k].value[0] >= sensors.probes[var.k].threshold
    set global.hZ = var.z
    set global.hSt = 0
echo >>"0:/sys/hes_h.csv" state.time ^ ",K" ^ var.k ^ "," ^ param.X ^ "," ^ param.Y ^ "," ^ param.S ^ "," ^ param.L ^ "," ^ global.hZ ^ "," ^ global.hSt
set var.n = 0
while sensors.probes[var.k].value[0] >= sensors.probes[var.k].threshold && var.n < var.unblockCap
  G91
  G1 Z0.01 F60
  G90
  M400
  set var.n = var.n + 1
G90
if sensors.probes[var.k].value[0] >= sensors.probes[var.k].threshold
  M98 P"0:/sys/hes_log.g" D{"ERROR K" ^ var.k ^ " stays triggered after dive"}
  if job.file.fileName != null || state.status == "processing"
    set global.hSt = 9          ; 2026-10-17: in a print no abort - caller (HesCal2) shows the operator window
    M99
  abort "hes_h.g: probe stays triggered after the dive - check lever/sensor (stuck mechanically or electrically). Which probe: see console. Motors NOT disabled."
