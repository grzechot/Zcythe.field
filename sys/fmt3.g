; fmt3.g - liczba V -> tekst z 3 miejscami po przecinku w global.fmt (RRF nie formatuje liczb, drukuje np. 0.6249998)
if !exists(global.fmt)
  global fmt = ""
var t = floor(abs(param.V) * 1000 + 0.5)
var f = mod(var.t, 1000)
set global.fmt = ((param.V < 0 && var.t > 0) ? "-" : "") ^ floor(var.t / 1000) ^ "." ^ (var.f < 100 ? "0" : "") ^ (var.f < 10 ? "0" : "") ^ var.f
