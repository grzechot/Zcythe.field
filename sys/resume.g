; resume.g - wywolywane przed wznowieniem wydruku (M24) po pauzie
; Kolejnosc: PRZYWROCENIE TEMP. DRUKU (M109 - czeka, zanim ruszy cokolwiek) -> wipe (kontrola temp.,
; drobny retract 2mm, wytarcie dyszy) -> prime (doladowanie + purge + szczotka + retract 2mm) -> OD RAZU szybki
; dojazd do pozycji ostatniego ruchu druku (bez drugiego wipe - trwal za dlugo i robil przerwe).
; Bilans filamentu (2026-10-22, wspolny licznik global.eRetr = ile mm jest teraz cofniete): pause.g cofa DO 2 mm,
; wipe DO 2 mm (juz cofniete - nic), prime +eRetr (2) +10 purge -2 (Q2), na pozycji druku +2 (oddanie Q2) =
; netto +10 mm wzgledem stanu sprzed pauzy, druk rusza z pelna dysza (wczesniej rusza z -2 mm).
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
M98 P"0:/macros/prime" Q2    ; doladowanie global.eRetr, purge, szczotka, retract 2 (bez wipe i ParkCoord)
G1 R1 X0 Y0 Z5 F24000        ; SZYBKO (bez przerwy po prime) 5mm nad pozycja ostatniego ruchu druku
G1 R1 X0 Y0                  ; powrot do pozycji ostatniego ruchu druku
if global.eRetr > 0
  M83
  G1 E{global.eRetr} F1800   ; oddanie Q2 na pozycji druku (slicer nie wie o tym retract)
  set global.eRetr = 0
