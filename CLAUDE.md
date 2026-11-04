# Tremor Cue Pen — CPE306 final project (handoff)

Pen-mounted pod that detects hand tremor (4–12 Hz) with an IMU and gives a
haptic cue with a coin vibration motor module. CPE306 Fundamentals of Mixed
Signals and Sensors, BulSU. Owner: Karlo. Direct, casual tone; English only.

## Detector (same in all firmware)
- LSM6DS3 accel, 104 Hz, ±2 g, I²C addr 0x6A (SDO→GND, CS→VCC).
- Two band-passes per axis (2nd-order HP + 2nd-order LP biquads, Q 0.707):
  stroke 0.5–3 Hz, tremor 4–12 Hz. Gravity measured at boot and subtracted
  (hold still ~1 s after reset).
- Power smoothed with EMA α = 0.01 (~1 s).
- **Start:** tremor/stroke power ratio > 3 AND tremor RMS > 30 mg for 0.5 s.
- **Cue:** once started, full-strength 0.7 s pulse (`PULSE_SAMPLES`), then a
  1.0 s refractory window (`REFRAC_SAMPLES`) where retriggering is ignored —
  not a simple on/off latch. This exists because the motor's own vibration
  sits in the same 4–12 Hz band as tremor and was observed to retrigger the
  detector continuously when driven without a cooldown (coupling bug, fixed).
- Offline replay on the 5 recordings in `data/`: idle 0%, normal writing 2.5%,
  drawing 0%, simulated tremor 100%, tremor while writing 82% (energy-only
  baseline: 0 / 40 / 20 / 90 / 40%). See `analysis/results.json`.
- Large slow arm shakes give ratio ~2 (stroke band) — by design; small fast
  wrist shiver triggers it.

## Hardware
- **Final board: NodeMCU (ESP8266), not the ESP32-S3** — the S3 plan was
  dropped. No DRV8833 motor driver either: the coin vibration motor is a
  module with its own drive transistor, PWM'd directly from a GPIO.
- IMU wiring: SDA → D7 (GPIO13), SCL → D6 (GPIO12), SDO → GND (addr 0x6A),
  CS → 3V3. **Do not use D1/D2 or D8** — D8/GPIO15 is a boot-strapping pin
  and caused boot failures once an I²C pull-up was on it.
- Motor: vibration module IN → D5, VCC → 5V (USB or battery), GND → GND.
  1 kHz PWM, full duty (1023/1023) only — no variable strength. 20 kHz did
  nothing useful on this module; it needs 1 kHz + high duty.
- Power: battery → TP4056 → switch → NodeMCU 5V pin / Vin, common GND.
  No battery-sense divider fitted — no low-battery feature on this board.
- Radios off in firmware (`WIFI_OFF`, `forceSleepBegin`, `LIGHT_SLEEP_T`
  during idle sampling gaps) — the dev board's own CH340/regulator draws far
  more (~70-80 mA) than the ESP8266 itself, so this mostly matters if/when
  the design ever moves to a bare module.
- The ESP32-S3 SuperMini firmware (`firmware/esp32s3/`) and ESP32-WROOM-32
  firmware (`firmware/esp32-wroom32/`) are **not used** — kept for reference/
  design history only. WROOM-32 was never actually gotten working (upload
  kept failing — likely wiring/power on that bench setup, unresolved).

## Firmware
- `firmware/nodemcu/tremor_cue_nodemcu.ino` — **the final firmware.**
  Serial 115200 commands: `r` raw log, `m` motor forced on (coupling test),
  `o` forced off, `a` auto (default), `?` settings. Motor is full-strength
  pulse+refractory only (no levels).
- `firmware/esp32s3/tremor_cue_pen.ino`, `firmware/esp32-wroom32/*.ino` —
  superseded, not the final hardware. Don't update these further.
- `tools/record.py <label> [secs] [port] [--raw]` logs 30 s CSVs; `--raw`
  sends `r` after the NodeMCU's auto-reset. Band CSV includes ratio + flag
  (flag is actually `cueState`: 0 watching / 1 pulsing / 2 refractory).

## CAD (OpenSCAD) — `cad/tremor_pen_pod_v7.scad` is current
- NodeMCU + IMU + vibration module stack, tall/narrow form factor (built
  from reference photos). Base + cap, both slide-in from the back; 2×M2
  screws on the diagonal. No DRV8833 slot (not needed).
- v7 base/cap STLs validated (OpenSCAD render, manifold, "Simple: yes") and
  copied into `cad/stl/tremor_pen_pod_v7-{base,cap}.stl`.
- v5 and v6 moved to `cad/archive/` — v7 supersedes them.

## Report
- **`report/Tremor_Cue_Pen_Final_Project.docx` is stale** — built around the
  ESP32-S3 + DRV8833 design, which is no longer what was built.
- A separately-supplied final report (`~/Downloads/FMSS.docx`, CPE306 FMSS
  template) was edited in this session to reflect the actual final hardware
  — saved as `~/Downloads/FMSS_updated.docx`. Changes made: Scope/DSP/PWM/
  Haptic-Motor-Control prose rewritten off DRV8833+S3 wording; Appendix 1
  Stage 2 rewritten for NodeMCU-as-final; Appendix 2 (S3 firmware) relabeled
  superseded; Appendix 3 (NodeMCU firmware) and Appendix 4 (record.py) code
  blocks replaced with the actual current source; pin tables corrected
  (D7/D6, no DRV8833 rows); **TC8 status downgraded to "needs
  re-verification"** (the recorded 0.0% false-trigger pass predates/doesn't
  match the motor-coupling bug found and fixed this session — it needs a
  real re-run on the current vibration-module hardware before it can be
  trusted); **TC10 marked "not implemented in final hardware"** (no
  battery-sense divider on the NodeMCU board, feature doesn't exist in
  `tremor_cue_nodemcu.ino`).
- `analysis/analyze.py` reads CSVs from `/mnt/user-data/uploads` — repoint
  to `data/` if it's rerun.

## Open items (in order)
1. **Re-run TC8** (motor coupling test) on the actual final vibration-module
   hardware with the pulse+refractory firmware — the FMSS doc now flags this
   as unverified, don't let it stand as "Pass" without a real re-test.
2. Decide on TC10 (battery monitoring): either implement it on the NodeMCU
   board (needs a sense divider + ADC code) or leave it as a stated
   limitation/future-work item — don't leave the doc claiming a feature that
   doesn't exist.
3. Finish assembling pod v7 (base+cap already printed/validated) with the
   NodeMCU+IMU+vibration-module stack; confirm fit against the real boards.
4. `report/Tremor_Cue_Pen_Final_Project.docx` and `report/build.py` are now
   out of sync with both the hardware and with `FMSS_updated.docx` — pick
   one report as canonical and retire/update the other.
