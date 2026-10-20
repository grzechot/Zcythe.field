; fmt4.g - number V -> text with 4 decimals in global.fmt (RRF does not format numbers, prints e.g. 0.6249998)
if !exists(global.fmt)
  global fmt = ""
var t = floor(abs(param.V) * 10000 + 0.5)
var f = mod(var.t, 10000)
set global.fmt = ((param.V < 0 && var.t > 0) ? "-" : "") ^ floor(var.t / 10000) ^ "." ^ (var.f < 1000 ? "0" : "") ^ (var.f < 100 ? "0" : "") ^ (var.f < 10 ? "0" : "") ^ var.f
