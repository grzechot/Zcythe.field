# sync.ps1 - pobiera aktualne pliki z drukarki (Duet/RRF) do firmware/ i data/. Tylko ODCZYT z drukarki.
# Uzycie: powershell -File tools\sync.ps1 [-Ip <printer IP or hostname>]
param([string]$Ip = $(if ($env:PRINTER_HOST) { $env:PRINTER_HOST } else { "printer.local" }))
$root = Split-Path -Parent $PSScriptRoot
$null = Invoke-WebRequest -UseBasicParsing "http://$Ip/rr_connect?password=" -TimeoutSec 10
function Get-Dir($remote, $local) {
  New-Item -ItemType Directory -Force $local | Out-Null
  $j = (Invoke-WebRequest -UseBasicParsing ("http://$Ip/rr_filelist?dir=" + [uri]::EscapeDataString($remote)) -TimeoutSec 20).Content | ConvertFrom-Json
  foreach ($f in $j.files) {
    if ($f.name -like "_archiwum*") { continue }
    # nie pobieramy: pliki z haslami WiFi/ustawieniami DWC, log zdarzen, binaria, kopie .bak
    if ($f.name -in @("config.json","configtool.json","dwc-plugins.json","dwc-settings.json","dwc2settings.json","eventlog.txt","eventlog.txt.part","iap4e.bin") -or $f.name -like "*.bak" -or $f.name -like "*.bin" -or $f.name -like "*.zip") { continue }
    if ($f.type -eq "d") { Get-Dir "$remote/$($f.name)" (Join-Path $local $f.name); continue }
    $dest = if ($f.name -like "*.csv") { Join-Path $root "data" } else { $local }
    New-Item -ItemType Directory -Force $dest | Out-Null
    Invoke-WebRequest -UseBasicParsing ("http://$Ip/rr_download?name=" + [uri]::EscapeDataString("$remote/$($f.name)")) -OutFile (Join-Path $dest $f.name) -TimeoutSec 60
    Write-Host ("pobrano {0}/{1}" -f $remote, $f.name)
  }
}
Get-Dir "0:/sys" (Join-Path $root "firmware\sys")
Get-Dir "0:/macros" (Join-Path $root "firmware\macros")
# ostrzezenie o sekretach
$hits = Get-ChildItem -Recurse -File (Join-Path $root "firmware") | Select-String -Pattern 'ssid_password|psk|M587|M551 P|password"' -ErrorAction SilentlyContinue
if ($hits) { Write-Warning "W plikach firmware sa slowa kluczowe (haslo/WiFi) - sprawdz przed publikacja:"; $hits | ForEach-Object { "  " + $_.Path + ":" + $_.LineNumber } }
