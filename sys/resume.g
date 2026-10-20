; resume.g - wywolywane przed wznowieniem wydruku (M24) po pauzie
; Kolejnosc: PRZYWROCENIE TEMP. DRUKU (M109 - czeka, zanim ruszy cokolwiek) -> wipe (kontrola temp.,
; drobny retract 2mm, wytarcie dyszy) -> prime (doladowanie + purge + szczotka + retract 2mm) -> OD RAZU szybki
; dojazd do pozycji ostatniego ruchu druku (bez drugiego wipe - trwal za dlugo i robil przerwe).
; Bilans filamentu do powrotu na pozycje: pause.g retract R (global.pauseRetract, teraz 7mm), wipe -2mm, prime +R (reload,
; parametr L) +10mm (purge) -2mm (Q2) = netto +6mm wzgledem stanu sprzed pauzy - bez drugiego wipe, tu retract Q2 go zastepuje.
; UnCapE0 z oryginalnego szablonu nie istnieje na tej drukarce - zakomentowane (jak CapE0 w pause.g).
;M98 P"0:/macros/UnCapE0"
; pause.g obnizyl temperature (M104 nadpisuje ACTIVE) i zapamietal temp. druku w global.pauseTemp - tu ja
; przywracamy i CZEKAMY. Bez tego active=standby, wipe/prime nic nie czekaly, a plik wydruku nie powtarza
; G10 po wznowieniu, wiec dysza ruszala na standby ("tool zbyt zimny").
if exists(global.pauseTemp) && global.pauseTemp > 0
  M568 P0 S{global.pauseTemp} A2   ; przywroc temp. druku jako active, standby bez zmian (M109 nadpisywalo tez standby)
  M116 P0                          ; czekaj na narzedzie 0
  set global.pauseTemp = 0
M98 P"0:/macros/wipe"        ; kontrola temperatury, drobny retract, wytarcie dyszy
var reload = 7                ; awaryjnie, gdyby pause.g nie ustawil global.pauseRetract
if exists(global.pauseRetract)
  if global.pauseRetract > 0
    set var.reload = global.pauseRetract
M98 P"0:/macros/prime" L{var.reload} Q2   ; doladowanie = retract z pause.g, purge, szczotka, retract 2 (bez wipe i ParkCoord)
G1 R1 X0 Y0 Z5 F24000        ; SZYBKO (bez przerwy po prime) 5mm nad pozycja ostatniego ruchu druku
G1 R1 X0 Y0                  ; powrot do pozycji ostatniego ruchu druku
