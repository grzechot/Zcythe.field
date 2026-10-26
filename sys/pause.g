; pause.g - wywolywane przy pauzie wydruku z karty SD
; Parkuje przy ParkCoord.X+3, ParkCoord.Y - stala stacja, ta sama co "wipe"/"prime", NIE wzgledem
; chwilowej pozycji karetki w momencie pauzy (to byl blad poprzedniej wersji: X+5 Y-10 od pauzy).
; WiperCoord (global.wiperX/wiperY/parkYOffset) jest zdefiniowany TYLKO w wipe.g - tutaj tylko odczyt.
; ParkCoord = wiperX, wiperY+parkYOffset - liczone na biezaco, nie cache'owane (patrz komentarz w wipe.g).
; Bezpieczne, bo start.g zawsze wywoluje "wipe" na poczatku kazdego wydruku, wiec te globalne sa juz
; ustawione zanim moglaby wystapic pierwsza pauza.
; --- dane startowe ---
; retract przy pauzie: 20 mm / F3600 + stygniecie do 160 C zostawialo rozciagnieta koncowke filamentu w zimnej
; strefie i ekstruder nie mogl jej potem wcisnac (2026-10-05). Krotszy i wolniejszy. resume.g doladowuje dokladnie
; tyle, ile tu cofnieto (przez global.pauseRetract -> prime L) - zmieniasz TYLKO tu.
var pauseRetract = 2       ; retract filamentu przy pauzie [mm]. 2026-10-20: 5 -> 2 (zaciecie po 4 h pauzy przy 160 C)
var pauseRetractF = 900    ; predkosc retractu [mm/min]
var pauseXOffset = 3       ; przesuniecie od ParkCoord.X (zeby nie stac dokladnie w tym samym punkcie co wipe/prime)
var heater = 1              ; grzalka narzedzia 0
var holdTemp = 160          ; [C] temperatura na czas pauzy, gdy standby jest bezuzyteczny (== active albo 0)
; global.pauseTemp = temperatura DRUKU sprzed obnizenia na czas pauzy (0 = nic do przywrocenia).
; M104 ustawia temperature ACTIVE narzedzia, wiec bez zapamietania tracilibysmy temp. druku - resume.g
; (wipe/prime) widzialy wtedy active=standby, nic nie czekalo, dysza ruszala na 160 ("tool zbyt zimny").
if !exists(global.pauseTemp)
  global pauseTemp = 0
; 2026-10-22 (zaciecia): cofniecie DO glebokosci pauseRetract (wspolny licznik global.eRetr z wipe/HesCal2/prime),
; resume.g -> prime oddaje global.eRetr. global.pauseRetract juz nieuzywany.
if !exists(global.eRetr)
  global eRetr = 0

M83                            ; ekstruder wzgledny
if global.eRetr < var.pauseRetract
  G1 E{-(var.pauseRetract - global.eRetr)} F{var.pauseRetractF}  ; retract filamentu
  set global.eRetr = var.pauseRetract
G91                             ; pozycjonowanie wzgledne
G1 Z5 F360                      ; podniesienie Z o 5mm
G90                             ; powrot do pozycjonowania bezwzglednego
G1 X{global.wiperX + var.pauseXOffset} Y{global.wiperY + global.parkYOffset} F6000  ; parkowanie przy stacji ParkCoord
; obnizenie temperatury na czas pauzy (bez czekania - M104 nie M109). Cel = standby, ale TYLKO gdy jest sensowny
; (0 < standby < active). Gdy standby == active albo 0 (bylo 220/220 - warunek "active > standby" nie zadzialal
; i dysza zostala na 220), spadamy do holdTemp. Temp. druku zapamietujemy tylko gdy faktycznie obnizamy, wiec
; ponowne wywolanie (juz obnizona active) nie nadpisze zapamietanej wartosci.
var target = var.holdTemp
if heat.heaters[var.heater].standby > 0 && heat.heaters[var.heater].standby < heat.heaters[var.heater].active
  set var.target = heat.heaters[var.heater].standby
if heat.heaters[var.heater].active > var.target
  set global.pauseTemp = heat.heaters[var.heater].active
  M568 P0 S{var.target}   ; tylko active (M104 nadpisywalo tez standby)
;M98 P"0:/macros/CapE0"         ; makro nie istnieje na tej drukarce (martwe odwolanie z szablonu)
