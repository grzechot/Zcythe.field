; cancel.g - wywolywane gdy zadanie jest anulowane (bezposrednio albo po pauzie)
; 1) Log diagnostyczny do 0:/sys/cancel_log.csv - stan drukarki w momencie anulowania (temperatury,
;    zbazowanie, skipCal, aktualne G31).
; 2) Wplyw na kolejny start.g: jesli osie NIE sa juz zbazowane (np. cos zresetowalo silniki w trakcie)
;    - wylacza skipCal, wymuszajac pelna kalibracje przy nastepnym starcie (bezpieczny domysl). Jesli
;    osie SA zbazowane, skipCal zostaje jak bylo (nic tu nie psujemy - o wlaczeniu po udanej kalibracji
;    decyduje juz HesCal).
var homed = move.axes[0].homed && move.axes[1].homed && move.axes[2].homed
if !exists(global.skipCal)
  global skipCal = false
if !exists(global.levelDone)
  global levelDone = false
if !var.homed
  set global.skipCal = false
  set global.levelDone = false

if !fileexists("0:/sys/cancel_log.csv")
  echo >"0:/sys/cancel_log.csv" "czas,plik,pozycja,bedCurrent,bedStandby,bedActive,hotCurrent,hotStandby,hotActive,homedXYZ,skipCal,G31triggerHeight"
var row = state.time ^ "," ^ (exists(job.lastFileName) ? job.lastFileName : "-") ^ "," ^ (exists(job.filePosition) ? job.filePosition : "-")
set var.row = var.row ^ "," ^ heat.heaters[0].current ^ "," ^ heat.heaters[0].standby ^ "," ^ heat.heaters[0].active
set var.row = var.row ^ "," ^ heat.heaters[1].current ^ "," ^ heat.heaters[1].standby ^ "," ^ heat.heaters[1].active
set var.row = var.row ^ "," ^ var.homed ^ "," ^ global.skipCal ^ "," ^ sensors.probes[0].triggerHeight
echo >>"0:/sys/cancel_log.csv" var.row
; filament czasowo cofniety przez kalibracje (global.eOwed) - oddaj, jesli hotend jest wystarczajaco goracy; inaczej
; zostaje do oddania w kroku 3 start.g
if exists(global.eOwed) && global.eOwed > 0 && heat.heaters[1].current >= heat.coldExtrudeTemperature + 5
  M83
  G1 E{global.eOwed} F600
  set global.eOwed = 0
