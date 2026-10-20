# Tools

Python 3 (standard library only) and PowerShell helpers that talk to the Duet over the RRF HTTP API
(`rr_connect`, `rr_gcode` + `rr_reply`, `rr_model`, `rr_upload`, `rr_download`, `rr_filelist`).
No password is used (standalone Duet with an empty password).

```bash
export PRINTER_HOST=192.168.x.y      # or the printer's hostname; default "printer.local"
python tools/r1run.py S
```

Output: CSV in `data/`, logs in `data/logs/` (both git-ignored). Every script that moves the machine ends with a
line starting `PODSUMOWANIE` (= summary) so it can be run in the background and checked at the end.
Script help texts and some output are still in Polish.

**Scripts marked "moves" run motion and probing – only with an empty bed and the operator at the machine.**

## Shared

| Script | Purpose |
|---|---|
| `voron_api.py` | Shared helpers: `connect()`, `run(gcode, max_s)` (waits until the HTTP channel is free, returns the reply), `m(key)` (object model), `state()`, `status()`, `homed()`, `download(name)`, `hist_rows()` / `parse_hist()` (`hes_hist.csv`), `frac()` (screw turns as fractions), `set_log()` / `log()` with date and time. Retries on HTTP 503. |
| `sync.ps1` | Read-only backup of `0:/sys` and `0:/macros` into `firmware/` (CSV into `data/`). Skips WiFi/DWC settings, event log, binaries; warns on password keywords. `-Ip <host>` or `PRINTER_HOST`. |
| `sync_when_idle.sh` | Waits until the printer is idle, then runs `sync.ps1`. |

## Calibration

| Script | Moves | Purpose |
|---|---|---|
| `r1run.py S\|A\|B` | A, B | R1 sequence: S = state only; A = 165 °C, K0 deploy, `k0offset.g`, G32; B = `wipe` + `HesCal2 R1`. |
| `k1meas.py` | yes | K1 margin after a screw adjustment: N × HesCal2 with G31 writing blocked, table, screw suggestion, new `kThr` estimate. |
| `cykle.py` | yes | N full start cycles (G28, G32, wipe + HesCal2, Mesh) with optional upload of a prepared folder first; one CSV row per cycle. |
| `zspeed.py` | yes | K0 trigger height vs probing speed (one G28, then `G30 S-1` per speed). |

## Monitoring (read-only)

| Script | Purpose |
|---|---|
| `fetch_logs.py` | After a print: state, download `hes_hist.csv`, `mesh_log.csv`, `cancel_log.csv`, show the last rows. |
| `watch_start.py` | Follows the start sequence live (windows on the panel, HesCal2 values, G31, mesh) until layer 1. |
| `watch_init.py` | Same, one line per stage with comparison against reference values (`--ref-*`). |
| `pclog.py` | Logs the printer state every `--dt` s to CSV until the print ends. |

## Mechanics diagnostics

| Script | Moves | Purpose |
|---|---|---|
| `zstep.py` | yes | Lost Z steps: G32 as the measurement, N fast Z cycles between G32 runs → motor drift per leadscrew. |
| `zdrop.py` | yes | Gantry sag with Z motors off (`M18 Z`, wait, G28 Z, G32). |
| `zwatch.py` | yes | Watches K0 at the 4 G32 points without correction for an hour – detects a sagging bed frame / driver dropouts. |
| `bedstab.py` | yes | Bed stability map: 7 × 7 grid, N serpentine passes, drift-corrected spread per point. |
| `xdir.py` | yes | Approach-direction hysteresis of K0 (variants interleaved round-robin). |
| `adir.py` | yes | Approach direction −X vs +X in a chosen area. |
| `prof.py` | yes | Dense K0 profile along Y vs the interpolated Mesh (is the grid dense enough?). |
