#!/usr/bin/env python3
"""Usage: python record.py <label> [seconds=30] [port=/dev/ttyUSB0] [--raw]
--raw sends 'r' after the board boots (opening the port resets a NodeMCU,
which turns raw logging back off).
Logs either sketch mode:
  LOG_RAW 1 -> <label>_raw_<ts>.csv  (label,t_pc,t_ms,ax,ay,az,gx,gy,gz  raw LSB)
  LOG_RAW 0 -> <label>_band_<ts>.csv (label,elapsed_s,band_mg,on,off,motor,ratio,flag)
"""
import csv, sys, time
import serial

RAW = "--raw" in sys.argv
sys.argv = [a for a in sys.argv if a != "--raw"]
label = sys.argv[1] if len(sys.argv) > 1 else "normal_writing"
duration = float(sys.argv[2]) if len(sys.argv) > 2 else 30
port = sys.argv[3] if len(sys.argv) > 3 else "/dev/ttyUSB0"
ts = int(time.time())

RAW_HDR = ["label", "t_pc", "t_ms", "ax", "ay", "az", "gx", "gy", "gz"]
BAND_HDR = ["label", "elapsed_s", "band_mg", "on", "off", "motor", "ratio", "flag"]

with serial.Serial(port, 115200, timeout=0.2) as s:
    time.sleep(2)              # let the board settle after the port opens (keep the pen still)
    if RAW:
        s.write(b"r")          # switch the firmware to raw logging
        time.sleep(0.2)
    s.reset_input_buffer()     # drop backlog so t=0 is really t=0
    s.readline()               # discard a possibly partial line
    t0 = time.monotonic()
    next_status = 0.0
    f = writer = None
    n = 0
    try:
        while True:
            el = time.monotonic() - t0
            if el >= duration:
                break
            if el >= next_status:
                print(f"\rRecording {label}: {max(0, duration-el):4.1f}s left, {n} rows", end="", flush=True)
                next_status = el + 0.5
            line = s.readline().decode(errors="ignore").strip()
            row = None
            if line.startswith("raw,"):
                p = line.split(",")
                if len(p) == 8:
                    try:
                        [int(x) for x in p[1:]]
                    except ValueError:
                        continue
                    row = ("raw", [label, f"{el:.3f}"] + p[1:])
            elif line.startswith("band_mg:"):
                try:
                    d = dict(i.split(":", 1) for i in line.split(","))
                    row = ("band", [label, f"{el:.2f}", d["band_mg"], d["on"], d["off"], d["motor"], d.get("ratio", ""), d.get("flag", "")])
                except (ValueError, KeyError):
                    continue
            if row is None:
                if line:
                    print(f"\n[{line}]")   # surface 'i2c fail', 'frozen, reinit', 'bad WHO_AM_I'
                continue
            if writer is None:
                kind = row[0]
                fn = f"{label}_{kind}_{ts}.csv"
                f = open(fn, "w", newline="")
                writer = csv.writer(f)
                writer.writerow(RAW_HDR if kind == "raw" else BAND_HDR)
            writer.writerow(row[1]); n += 1
    except KeyboardInterrupt:
        print("\nInterrupted.")
    finally:
        if f:
            f.close()
print(f"\nSaved {fn if writer else '(nothing - no data lines seen)'}  ({n} rows)")
