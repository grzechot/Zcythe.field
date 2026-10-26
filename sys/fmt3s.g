; fmt3s.g - jak fmt3.g, ale z "+" dla wartości >= 0 (odchyłki w tabeli wyników)
M98 P"0:/sys/fmt3.g" V{param.V}
if param.V > 0 || floor(abs(param.V) * 1000 + 0.5) == 0
  set global.fmt = "+" ^ global.fmt
