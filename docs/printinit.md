# PrintInit – what the operator sees, screen by screen

**PrintInit** is everything the printer does between *Start print* and the first layer: `sys/start.g`, run
automatically by RRF before every print. It has **10 stages**. Each stage starts with one line `[n/10] …` on
PanelDue and in DWC, and each one ends with a short summary. When something goes wrong the print **pauses**
(it is never cancelled on its own). A window then explains what happened and what to check, and its buttons
are named after what they do.

The screens below are the console as the operator sees it. Most values come from real runs on the author's
Voron (22 Oct 2026, 24 Oct 2026). The X/Y homing lines, the heating/warm-up progress lines and the waiting
lines are illustrative: the text is the real one, the numbers are examples. Lines marked `DWC only` do not
appear on PanelDue.

- [How to read the screens](#how-to-read-the-screens)
- [Stage 1 – Heating](#stage-1--heating)
- [Stage 2 – Bed probe check](#stage-2--bed-probe-check)
- [Stage 3 – Homing X, Y, Z](#stage-3--homing-x-y-z)
- [Stage 4 – Leveling](#stage-4--leveling)
- [Stage 5 – Bed warm-up](#stage-5--bed-warm-up)
- [Stage 6 – Leveling check (bed warm)](#stage-6--leveling-check-bed-warm)
- [Stage 7 – Cleaning the nozzle](#stage-7--cleaning-the-nozzle)
- [Stage 8 – Nozzle calibration (HesCal2)](#stage-8--nozzle-calibration-hescal2)
- [Stage 9 – Bed map](#stage-9--bed-map)
- [Stage 10 – Purge line](#stage-10--purge-line)
- [Done](#done)
- [While the printer waits for the operator](#while-the-printer-waits-for-the-operator)
- [Step back (`< …` buttons)](#step-back---buttons)
- [Files](#files)

## How to read the screens

| Level | Where | Looks like | Meaning |
|---|---|---|---|
| INFO | PanelDue + DWC | `Pass 2: bed tilt 0.054 mm` | progress, values with unit and limit |
| WARNING | PanelDue + DWC | `WARNING …` + a 2nd line starting with a space | out of tolerance, the print goes on; the 2nd line says what to check **after** the print |
| ERROR | window (M291) | title, cause, *Check: …*, buttons | the printer stops and waits; heaters stay on |

- PanelDue has 12 rows of history and lines of at most 40 characters, so it gets the short text.
  DWC gets the same line with the parameter names written out, plus service values (`DWC only`).
- A stage that is already done is **skipped** with one line, e.g. `Homing skipped (already homed)`.
  The bed map (stage 9) is never skipped.
- Every window has *Cancel* (*Stop* when no print file is running). Most also have a step-back
  button `< …`, see [Step back](#step-back---buttons).

---

## Stage 1 – Heating

```
[1/10] Heating: bed 55 C, nozzle 165 C
```

The bed goes to the print temperature (PLA 55 °C). The nozzle goes to **165 °C**, warm enough to soften
filament residue for wiping but too cold to ooze. Both heat in the background while the next stages run.
There is no waiting here.

## Stage 2 – Bed probe check

```
[2/10] Checking bed probe
Open bed probe (needle on toolhead)        <- only if K0 is closed
Bed probe open - continuing
```

K0 (Zcythe, the bed probe on the toolhead) has a needle that you open by hand. If it is closed, a window
with no buttons appears and the printer beeps:

> **Open the bed probe**
> The bed probe (needle on the toolhead) is closed. First check the bed: PEI sheet in place, no print or
> tools on it. Then open the probe by hand. The printer continues by itself. To stop: pause the print.

The window has no buttons because opening the needle is the answer, and the printer goes on by itself.
For the first 2 minutes it beeps every 5 s and shows the window again every 60 s. After that the
[waiting timers](#while-the-printer-waits-for-the-operator) take over. If you open the probe after more than
a minute, the line reads `Bed probe open after n min`.

If K0 closes by itself later, while it is measuring (during leveling or the bed map), the same kind of
window appears: **Bed probe closed during leveling**. The measurement continues from that point.
After 3 such closures in one PrintInit you get:

```
WARNING bed probe closed 3x
 after print: check probe flag
```

## Stage 3 – Homing X, Y, Z

```
[3/10] Homing X, Y
X homed 9 s: +0.004 mm (max 0.3)
Y homed 8 s: -0.006 mm (max 0.3)
[3/10] Homing Z
-- Z HOMING DONE  147 s --
Z zero change: n/a (first homing)
Probe offset: 0.900 mm
```

- **X/Y line**: homing time and *check B*, the difference between two endstop hits. Limit `tolXY`
  (0.3 mm). A bigger value usually means a loose belt or pulley.
- **Z zero change** (*check C*): how far Z zero moved since the previous homing. `n/a` after a reset.
  If it is over `tolZ` (0.03 mm) you get `WARNING Z zero moved …` and ` max 0.030 - after print check Z drive`.
- **Probe offset**: the G31 Z currently in use. Stage 8 measures it again.

When every axis is already homed:

```
Homing skipped (already homed)
```

**Error windows** (`home_do.g`). The cause is in the title:

| Window | Cause | Buttons |
|---|---|---|
| **X endstop not reached** | the toolhead travelled the whole axis and the switch did not click | *Rehome* · *Test X* · *Cancel* · *< Probe* |
| **X endstop stays pressed** | 5 mm away from the switch it still reads pressed | same |
| **X endstop signal unstable** | it clicked on the fast approach but not on the slow one | same |
| **X endstop not repeatable** | two hits differ by more than `tolXY` | *Rehome* · *Continue* · *Set limit* · *Cancel* · *< Probe* |
| **Z cannot home yet** | X/Y not homed, so the probe position is unknown | *Home* · *Cancel* · *< Probe* |
| Z: **probe** problem | K0 did not trigger / was already triggered | *Rehome* · *Test* · *Cancel* · *< Probe* |

The same windows exist for Y. *Test X* / *Test* move nothing. You press the switch or the K0 needle by hand,
and the console and a 30 s window tell you whether the signal arrived (`endstop_test.g`, `probe_test.g`).
*Continue* keeps the result and adds a WARNING line (` after print: check X belt/pulley`).
*Set limit* opens the tolerance window (`tol_ask.g`).

## Stage 4 – Leveling

```
[4/10] Leveling bed
Pass 1: bed tilt 0.426 mm
Pass 2: bed tilt 0.054 mm
Pass 3: bed tilt 0.010 mm
-- BED LEVELING DONE  174 s --
Bed tilt: 0.426 -> 0.010 mm (max 0.020)
Passes: 3
```

`G32` probes the bed with K0 at the 4 leadscrews and corrects the 4 Z motors. It repeats until the tilt
measured before the correction is ≤ `tolBed` (0.02 mm). The first pass starts 15 mm up, because after
power-off the gantry may hang skewed by several mm.
DWC also shows `Leveling: Z +15 mm first …` and the RRF line `Leadscrew adjustments made: …`.

**Windows:**

| Window | Cause | Buttons |
|---|---|---|
| **Bed not level** | still above `tolBed` after the maximum number of passes; the tilt of each pass is listed | *Relevel* · *Continue* · *Set limit* · *Cancel* · *< Home* |
| **Bed probe failed at point n** | 6 dives at one leadscrew point gave no valid reading (e.g. *point 1 of 4 (X10 Y5)*) | *Retry* · *Test* · *Cancel* · *< Home* |

*Check:* lines in these windows: Z belts and couplers, a Z motor losing steps, loose bed screws, probe flag
closing too early, a dirty needle, something on the bed. If K0 touches before the point, Z goes up by itself
first (`Bed probe touched early - Z up 5 mm`).

## Stage 5 – Bed warm-up

```
[5/10] Bed warm-up
Bed at 55 C - settling 7 min
Bed warm-up: 6 min left
Bed warm-up: 5 min left
...
-- BED WARM-UP DONE  6 min --
```

Reaching 55 °C is not enough: the bed is still changing shape (dome ≈ 0.13 mm at 55 °C, edges last). So the
printer waits **8 min after the bed reached its target** (3 min if it was already within 5 °C at the start).
Time the bed already spent hot counts. After a long leveling the line is often just:

```
Bed warm-up not needed (hot 12 min)
```

During the wait a window shows the minutes left (refreshed every 60 s):

> **Bed warm-up 6 min** – Bed edges settle 6 min. Large print: Wait. Small print in the middle: Skip.
> No choice or Cancel = wait.
> *Wait* · *Skip* · *Cancel* · *< Level*

*Skip* is for small parts in the middle of the bed. It leaves a warning:
`WARNING warm-up skipped 4 min early`.

If the bed does not reach the target in 20 min:

> **Bed does not reach 55 C** – After 20 min the bed is at 48 C. Check: bed heater cable and connector,
> mains/SSR, room draught. Heaters stay on.
> *+10 min* · *Continue* · *Cancel* · *< Level*

## Stage 6 – Leveling check (bed warm)

```
[6/10] Leveling check (bed warm)
Pass 1: bed tilt 0.006 mm
Pass 2: bed tilt 0.003 mm
-- BED LEVELING DONE  131 s --
Bed tilt: 0.006 -> 0.003 mm (max 0.020)
Passes: 2
```

The same `G32` as in stage 4, now on a warm bed. The gantry and the Z screws drift while the bed warms up.
It is skipped when the bed was level before the warm-up and nobody had to wait:

```
Leveling check skipped (bed level, warm)
```

Same windows as stage 4, with the step-back button *< Warm*.

## Stage 7 – Cleaning the nozzle

```
[7/10] Cleaning nozzle
Nozzle heating: 158 C / 165 C              <- every 30 s, only if still heating
```

Macro `wipe`: it waits for 165 °C, retracts the filament a little and wipes the nozzle on the wiper
(a strip of sheet metal bent at 90°, see [installation](installation.md#nozzle-wiper)).
A clean nozzle is needed for the next stage, where the nozzle tip touches the sensor – filament left on the tip
would add to the measured offset.

## Stage 8 – Nozzle calibration (HesCal2)

```
[8/10] Nozzle calibration
Z re-homed with new offset
-- NOZZLE CALIBRATION DONE  70 s --
Probe offset: 0.757 mm (last 0.751)
```

This is the core of Zcythe Field (see [How it works](how-it-works.md)). K0 measures the bed and the tip
of K1 (Zcythe Stone, the nozzle sensor on the bed frame). Then the nozzle presses the K1 tip. From these
three dives the printer computes **G31 Z**, the nozzle height above the bed when K0 triggers, with no paper
and no feeler gauge. Z is homed again with the new offset.

DWC only – the service values behind the result:

```
K1 tip/bed (K1 tip above bed, by K0): 1.1363 mm, R1 reference 1.1650 mm
dz (Z: nozzle on K1 minus K0 on K1 tip): 0.9438 mm; K1 margin (...target 0.2): 0.1925 mm
K1 screw: OK
G31 (nozzle above bed at K0 trigger): tip method 0.7568 mm, bed method 0.7855 mm
G31 SET 0.7568 (measured)
```

Possible warnings: `WARNING calibration check off …` (the tip and bed methods differ by more than 0.05 mm,
so watch the 1st layer), `WARNING nozzle sensor margin …` (after the print, turn the K1 screw by the fraction
shown), `WARNING sensor tip off centre`.

When G31 was already measured since the last homing:
`Calibration skipped (done before)`.

**Windows:**

| Window | Cause | Buttons |
|---|---|---|
| **Nozzle calibration failed** | e.g. *Probe readings on the sensor tip disagree. Check: sensor tip clean, sensor lever not loose.* | *Measure* · *< Clean* · *Use last* · *Cancel* |
| **Probe offset changed** | the new G31 differs from the last good one by more than `tolG31Live` (0.05 mm) | *Accept* · *Measure* · *Set limit* · *Cancel* |

*Use last* prints with the last good offset, which the window shows, e.g. `0.751 mm`. On the console:
`Probe offset: 0.751 mm (last good)`. *< Clean* wipes the nozzle again and repeats the measurement.
*Accept* is the right answer if you really changed the PEI sheet, the nozzle or the sensor.

## Stage 9 – Bed map

```
[9/10] Bed map (49 points, about 3 min)
-- BED MAP DONE  139 s --
Bed map range: 0.266 mm (mean -0.070)
Map check: +0.009 mm (max 0.030)
```

A fresh 7 × 7 map at print temperature, before **every** print. Afterwards one point is measured again with
the map switched off and compared with the map (`tolCheck` 0.03 mm). This catches dirt, a loose sheet or
a bad dive.

DWC only – the map in µm while it is being measured:

```
[um]    X5   70  135  200  265  330  395
Y10   -149 -173 -201 -169 -176 -189 -191
Y69      3  -28  -58  -83  -72 -119  -57
Y128    58   43   -1   -7  -27  -41  -14
Y187    66   33   18   13  -17  -47  -27
Y246    -9  -14  -39  -61  -49  -88  -71
Y305   -61  -72  -51  -33  -62  -83 -112
Y364  -169 -187 -176  -94  -93 -153 -166
```

**Windows:**

| Window | Cause | Buttons |
|---|---|---|
| **Bed map point failed** | at X… Y… the probe did not touch the bed, or two dives disagree | *Retry* · *Test* · *Cancel* |
| **Bed map check failed** | the re-measured point differs from the map by more than `tolCheck`; *Usually dirt or a loose PEI sheet* | *Remap* · *Continue* · *Set limit* · *Cancel* · *< Calib* |

## Stage 10 – Purge line

```
[10/10] Purge line (nozzle 220 C)
Nozzle heating: 214 C / 220 C
```

The nozzle heats to 220 °C (the print file does not exist yet, so this is a fixed value in `start.g`). Macro
`prime` gives back the filament retracted in stage 7, extrudes 20 mm and wipes the nozzle on the wiper.

## Done

```
-- PRINT INIT DONE  16 min --
```

The acceleration and jerk from `config.g` are restored, and the print file takes over (its own
temperatures, first layer).
A clean run took 16 min (22 Oct 2026). A run with two error windows answered by the operator took 20 min
(24 Oct 2026).

---

## While the printer waits for the operator

Each window and the closed bed probe start the waiting timers (`op_wait.g`, counted by `daemon.g`,
times in `printinit_cfg.g`):

```
Waiting for bed probe: 5 min               <- every 5 min, with a beep
Waited 30 min - heaters off
Waited 60 min - motors off
```

| After | What happens | When you come back |
|---|---|---|
| every 5 min | beep + reminder line | – |
| 30 min | bed and nozzle heaters off | `Heaters back on - warming up`: heating, and the bed warm-up again |
| +30 min | motors off, positions lost | `Motors were off - start again`: start the print again |

## Step back (`< …` buttons)

Every error window during PrintInit has a button that returns to the stage the problem most likely comes
from. You do not have to cancel and start over:

| Window in stage | Button | Goes back to |
|---|---|---|
| 3 Homing | `< Probe` | 2 – bed probe check |
| 4 Leveling | `< Home` | 3 – homing |
| 5 Warm-up | `< Level` | 4 – leveling |
| 6 Leveling check | `< Warm` | 5 – warm-up |
| 8 Calibration | `< Clean` | 7 – wipe, then measure again |
| 9 Bed map | `< Calib` | 8 – calibration |

The console confirms it with `Operator: back to step 4/10`. Every stage from that point on runs again.

## Files

| File | Role |
|---|---|
| `sys/start.g` | the 10 stages in a loop, skipping, step back, `-- PRINT INIT DONE --` |
| `sys/msg.g` | one console line: `S` PanelDue, `L` long DWC text, `D` DWC only |
| `sys/deployprobe0.g` | stage 2, K0 window and beeps |
| `sys/homex.g`, `homey.g`, `homez.g`, `home_do.g`, `home_sum.g`, `home_xy.g`, `home_z.g` | stage 3 |
| `sys/endstop_test.g`, `sys/probe_test.g` | *Test* buttons – manual signal test, no motion |
| `sys/bed.g`, `bed_pass.g`, `k0g30.g` | stages 4 and 6 |
| `sys/bedsoak.g` | stage 5 |
| `macros/wipe` | stage 7 |
| `macros/HesCal2`, `sys/hescal2_m.g` and `hes_*.g` | stage 8 |
| `macros/Mesh`, `sys/mesh_ask.g` | stage 9 |
| `macros/prime` | stage 10 |
| `sys/op_wait.g`, `sys/daemon.g`, `sys/printinit_cfg.g` | waiting timers |
| `sys/tolerances.g`, `tol_ask.g` | limits, *Set limit* buttons |
| `macros/Legend` | glossary of the parameter names, printed to DWC |
