; mesh.g - wywoływany przez G29 (bez S). Siatka z łagodniejszą dynamiką karetki:
; przy pełnym przyspieszeniu wstrząs po dojeździe do punktu fałszywie wyzwala sondę K0 (ZBed).
; Puste przejazdy i druk poza G29 zostają na wartościach z config.g.
var ax = move.axes[0].acceleration    ; mm/s^2
var ay = move.axes[1].acceleration
var jx = move.axes[0].jerk            ; mm/min (jak M566)
var jy = move.axes[1].jerk
M201 X2000 Y2000
M566 X300 Y300
G29 S0
; przy błędzie G29 S0 poniższe się nie wykona - zostaje łagodniejsza dynamika do restartu (bezpieczny kierunek)
M201 X{var.ax} Y{var.ay}
M566 X{var.jx} Y{var.jy}
