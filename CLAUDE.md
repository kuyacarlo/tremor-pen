# Tremor Cue Pen — CPE306 final project (handoff)

Pen-mounted pod that detects hand tremor (4–12 Hz) with an IMU and gives a
haptic cue with a coin motor. CPE306 Fundamentals of Mixed Signals and Sensors,
BulSU. **Deadline: Tue 2026-11-03, 1 PM.** Owner: Karlo. Direct, casual tone;
English only.

## Detector (same in all firmware)
- LSM6DS3 accel, 104 Hz, ±2 g, I²C addr 0x6A (SDO→GND, CS→VCC).
- Two band-passes per axis (2nd-order HP + 2nd-order LP biquads, Q 0.707):
  stroke 0.5–3 Hz, tremor 4–12 Hz. Gravity measured at boot and subtracted
  (hold still ~1 s after reset).
- Power smoothed with EMA α = 0.01 (~1 s).
- **Start:** tremor/stroke power ratio > 3 AND tremor RMS > 30 mg for 0.5 s.
  **Stop:** ratio < 1.5 OR RMS < 20 mg for 0.5 s.
- Offline replay on the 5 recordings in `data/`: idle 0%, normal writing 2.5%,
  drawing 0%, simulated tremor 100%, tremor while writing 82% (energy-only
  baseline: 0 / 40 / 20 / 90 / 40%). See `analysis/results.json`.
- Large slow arm shakes give ratio ~2 (stroke band) — by design; small fast
  wrist shiver triggers it.

## Hardware
- Final: ESP32-S3 SuperMini, TP4056 (17.2 × 27.5 × 3.3, micro-USB, protected,
  OUT± pads), DRV8833, LSM6DS3, 1027 coin motor, slide switch, FL902030
  560 mAh LiPo. Bench test: NodeMCU (ESP8266).
- Power: battery → TP4056 B± ; OUT+ → switch → S3 **5V** pin + DRV VM ;
  OUT− → common GND. Never battery on 3V3. Switch OFF while USB is in the S3.
- Battery-sense divider is NOT fitted → S3 firmware must have `VBAT_LOW = 0`.
- TP4056 charge resistor not swapped (1 A ≈ 1.8C): charge with cover off,
  supervised.
- Wire: 28 AWG stranded inside the pod (22 AWG only fits v4/v5).
- S3 pins: GPIO8 SDA, GPIO9 SCL, GPIO4 motor (DRV AIN1; AIN2→GND), GPIO1 vbat (unused).
- NodeMCU pins: D2 SDA, D1 SCL, D5 motor. Currently tested with a
  **transistor vibration module (IN/VCC/GND)** on D5 — needs 1 kHz PWM and
  high duty (it did nothing useful at 20 kHz / 39%). Module VCC on VIN (5 V)
  for a stronger buzz.

## Firmware
- `firmware/nodemcu/tremor_cue_nodemcu.ino` — current bench firmware.
  Serial 115200 commands: `r` raw log, `m` motor forced on (coupling test),
  `o` forced off, `a` auto, `1/2/3` motor level {600, 800, 1023}/1023 (boots
  at 3), `?` settings. PWM 1 kHz, `analogWriteRange(1023)`.
  Only syntax-checked here (no ESP8266 toolchain in the cloud sandbox) — the
  user compiles in Arduino IDE.
- `firmware/esp32s3/tremor_cue_pen.ino` — final-board firmware. **Behind the
  NodeMCU one:** still `VBAT_LOW = 3.40` (set to 0), no motor levels, PWM
  20 kHz / 350 (fine for DRV8833; use 1 kHz + high duty if the vibration
  module is used). Board "ESP32S3 Dev Module", USB CDC On Boot enabled.
  Never compiled yet.
- `tools/record.py <label> [secs] [port] [--raw]` logs 30 s CSVs; `--raw`
  sends `r` after the NodeMCU's auto-reset. Band CSV includes ratio + flag.

## CAD (OpenSCAD) — `cad/tremor_pen_pod_v5.scad` is current
- Base + cover. Base (Bambu PLA Basic) holds everything; cover (matte PETG)
  drops over it, 2 × M2×4–5 front screws into M2 heat-set inserts
  (3.2 mm hole), plus snap ridges at the back posts.
- 30.7 × 38.55 × 40 mm + 8 mm pen sleeve. Pen: Panda ballpen with its rubber
  grip as a sleeve, friction fit (no clamp screw since v5).
- Layout: battery on floor; ESP32-S3 middle shelf, TP4056 top shelf (both slide
  in from the back, USB at back wall, front stops); DRV8833 upright behind the
  front bulkhead; IMU in the left channel (3.6 mm wide, foam-tape it rigid,
  wires up through a 3 mm floor opening); coin motor in the right round pocket;
  switch right-rear, handle pointing at the back wall, flicked through a poke
  slot (3.8 × 7.9) with a pin; stop tab behind it.
- Printer: Bambu A1 mini, 0.4 nozzle, 0.2 layers, 3 walls, 30% gyroid,
  supports off, brim 4 mm on the base, elephant foot comp 0. STLs in
  `cad/stl/` are already in print orientation (base on its front face, cover on
  its top). This printer prints round holes small and slots ~0.4 mm wide.
- The v5 base and cover are **printed**. Assembly guide: `cad/guide/assembly_v5.png`
  (renders made with `cad/guide/steps.scad` + xvfb-run openscad).
- Model has asserts for every fit and `clash_*` parts proving each removal
  path; it was verified with the `3d-print-designer` skill's gate
  (`verify-model.py`, 16/16 pass) and Sonnet design reviews (v3, v4, v5).
- Older versions in `cad/archive/` (v3.1 was printed earlier; v4 = 22 AWG backup).

## Report
- `report/Tremor_Cue_Pen_Final_Project.docx` — filled CPE306 template (A–F),
  built by `report/build.py` from the analysis figures. TC6–TC11 still
  "Pending" (yellow). Out of date on: final board pins/power (no vbat divider,
  battery into 5V), switch/clamp changes, PLA+PETG materials, rubber-sleeved
  Panda pen. `analysis/analyze.py` reads CSVs from /mnt/user-data/uploads —
  repoint to `data/`.

## Open items (in order)
1. Bench test on NodeMCU: shake → buzz; `m` coupling test at level 3 (pen
   still: band_mg < 30, ratio < 3); held-out runs (2 new writing, 1 weak
   shake) with record.py → fill TC6–TC8.
2. Update S3 firmware: `VBAT_LOW = 0`, port motor levels; if using the
   vibration module, 1 kHz + duty {600, 800, 1023}.
3. Solder harness outside the case (see Hardware), test on battery, then
   assemble per the guide; repeat coupling test closed up (TC9).
4. If the vibration module replaces DRV8833 + bare motor, the DRV slot/motor
   pocket may need resizing — get its dimensions first.
5. Update the report (sections B, D, E, F) and re-export.
