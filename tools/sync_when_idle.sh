#!/bin/bash
# czeka az drukarka bedzie idle (nie przeszkadza w druku), potem uruchamia sync.ps1 (tylko odczyt z drukarki)
IP=${PRINTER_HOST:-printer.local}   # IP or hostname of your Duet
st(){ curl -s -m 8 -G "http://$IP/rr_model" --data-urlencode "key=$1" --data-urlencode "flags=d3v" | grep -o '"result":[^}]*' | sed 's/"result"://;s/,"next":0//'; }
for i in $(seq 1 180); do
  case "$(st state.status)" in *idle*) break;; esac
  sleep 60
done
echo "status=$(st state.status) o $(date +%H:%M:%S)"
case "$(st state.status)" in *idle*) powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(dirname "$0")/sync.ps1" 2>&1 | tail -15;; *) echo "drukarka nadal zajeta - sync NIE uruchomiony";; esac
