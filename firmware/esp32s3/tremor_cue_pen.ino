// Tremor Cue Pen - ESP32-S3 SuperMini firmware
// LSM6DS3 accel (I2C) -> two band-pass chains -> tremor/stroke ratio -> DRV8833 PWM -> coin motor
// Arduino-ESP32 core 3.x. Board: "ESP32S3 Dev Module", USB CDC On Boot: Enabled.

#include <Wire.h>
#include <WiFi.h>

// ---------- pins (GPIO numbers, ESP32-S3 SuperMini) ----------
const int PIN_SDA   = 8;
const int PIN_SCL   = 9;
const int PIN_MOTOR = 4;     // DRV8833 AIN1 (AIN2 -> GND, nSLEEP -> 3V3)
const int PIN_VBAT  = 1;     // ADC1_CH0, battery through 100k/100k divider + 100 nF
const int PIN_RGB   = 48;    // onboard WS2812 (SuperMini) - off, it's just current draw/heat

// ---------- settings ----------
#define LOG_RAW 0            // 1: stream raw accel/gyro for record.py, 0: stream detector values
const int   IMU     = 0x6A;
const float FS      = 104.0f;
const float ALPHA   = 0.01f;             // power smoothing, time constant ~1 s
const float ON_RATIO = 3.0f, ON_MG = 30.0f;
const float OFF_RATIO = 1.5f, OFF_MG = 20.0f;
const int   HOLD    = (int)(0.5f * FS);  // 0.5 s confirmation
const int   MOTOR_PWM = 350;             // of 1023
const float VBAT_LOW = 0.0f;             // volts (battery-sense divider not fitted; disabled)
const unsigned long PERIOD_US = (unsigned long)(1e6f / FS);

// ---------- 2nd-order biquad (RBJ, Q = 0.707) ----------
struct Biquad {
  float b0, b1, b2, a1, a2, z1 = 0, z2 = 0;
  void set(bool hp, float f) {
    float w = 2 * PI * f / FS, c = cosf(w), al = sinf(w) / (2 * 0.707f), a0 = 1 + al;
    if (hp) { b0 = (1 + c) / 2; b1 = -(1 + c); } else { b0 = (1 - c) / 2; b1 = 1 - c; }
    b2 = b0; b0 /= a0; b1 /= a0; b2 /= a0; a1 = -2 * c / a0; a2 = (1 - al) / a0;
    z1 = z2 = 0;
  }
  float run(float x) {
    float y = b0 * x + z1;
    z1 = b1 * x - a1 * y + z2;
    z2 = b2 * x - a2 * y;
    return y;
  }
};

struct BandPass {
  Biquad hp, lp;
  void set(float lo, float hi) { hp.set(true, lo); lp.set(false, hi); }
  float run(float x) { return lp.run(hp.run(x)); }
};

BandPass tremorBP[3], strokeBP[3];
float g0[3];                 // gravity reference, removed before filtering (primes the filters)
float pTremor = 0, pStroke = 0;
bool  flagged = false;
int   holdCount = 0;
unsigned long nextT;
int16_t lastRaw[3]; int frozenCount = 0;

// ---------- IMU ----------
void wr(uint8_t reg, uint8_t v) {
  Wire.beginTransmission(IMU); Wire.write(reg); Wire.write(v); Wire.endTransmission();
}
bool rd(uint8_t reg, uint8_t *buf, int n) {
  Wire.beginTransmission(IMU); Wire.write(reg);
  if (Wire.endTransmission(false) != 0) return false;
  if (Wire.requestFrom(IMU, n) != n) return false;
  for (int i = 0; i < n; i++) buf[i] = Wire.read();
  return true;
}
bool imuInit() {
  uint8_t id = 0;
  if (!rd(0x0F, &id, 1) || (id != 0x69 && id != 0x6A)) { Serial.printf("bad WHO_AM_I 0x%02X\n", id); return false; }
  wr(0x12, 0x44);            // CTRL3_C: auto-increment, block data update
  wr(0x10, 0x43);            // CTRL1_XL: 104 Hz, +/-2 g, 50 Hz anti-alias bandwidth
  wr(0x11, 0x40);            // CTRL2_G: gyro 104 Hz, 245 dps (logging only)
  return true;
}
bool readIMU(int16_t a[3], int16_t g[3]) {
  uint8_t b[12];
  if (!rd(0x22, b, 12)) return false;          // OUTX_L_G .. OUTZ_H_XL
  for (int i = 0; i < 3; i++) {
    g[i] = (int16_t)((b[2 * i + 1] << 8) | b[2 * i]);
    a[i] = (int16_t)((b[2 * i + 7] << 8) | b[2 * i + 6]);
  }
  return true;
}

void resetFilters() {
  for (int i = 0; i < 3; i++) { tremorBP[i].set(4.0f, 12.0f); strokeBP[i].set(0.5f, 3.0f); }
  // average 32 samples to get the gravity reference
  float s[3] = {0, 0, 0}; int n = 0; int16_t a[3], g[3];
  while (n < 32) { if (readIMU(a, g)) { for (int i = 0; i < 3; i++) s[i] += a[i] * 0.000061f; n++; } delay(10); }
  for (int i = 0; i < 3; i++) g0[i] = s[i] / n;
  pTremor = pStroke = 0; flagged = false; holdCount = 0;
}

// ---------- battery (ADC) ----------
float readVbat() {
  uint32_t mv = 0;
  for (int i = 0; i < 16; i++) mv += analogReadMilliVolts(PIN_VBAT);   // 16x averaging
  return (mv / 16.0f) * 2.0f / 1000.0f;                              // undo 1:2 divider
}

void setup() {
  WiFi.mode(WIFI_OFF);
  btStop();
  setCpuFrequencyMhz(80);
  rgbLedWrite(PIN_RGB, 0, 0, 0);   // onboard RGB LED off
  Serial.begin(115200);
  delay(500);
  Wire.begin(PIN_SDA, PIN_SCL);
  Wire.setClock(400000);
  analogReadResolution(12);
  analogWriteResolution(PIN_MOTOR, 10);
  analogWriteFrequency(PIN_MOTOR, 20000);       // above hearing
  analogWrite(PIN_MOTOR, 0);
  while (!imuInit()) delay(500);
  resetFilters();
  nextT = micros();
}

void loop() {
  if ((long)(micros() - nextT) < 0) return;
  nextT += PERIOD_US;

  int16_t a[3], g[3];
  if (!readIMU(a, g)) { Serial.println("i2c fail"); analogWrite(PIN_MOTOR, 0); delay(100); imuInit(); resetFilters(); nextT = micros(); return; }

  bool same = a[0] == lastRaw[0] && a[1] == lastRaw[1] && a[2] == lastRaw[2];
  frozenCount = same ? frozenCount + 1 : 0;
  memcpy(lastRaw, a, sizeof(lastRaw));
  if (frozenCount > 50) { Serial.println("frozen, reinit"); imuInit(); resetFilters(); frozenCount = 0; nextT = micros(); return; }

#if LOG_RAW
  Serial.printf("raw,%lu,%d,%d,%d,%d,%d,%d\n", millis(), a[0], a[1], a[2], g[0], g[1], g[2]);
#endif

  float eT = 0, eS = 0;
  for (int i = 0; i < 3; i++) {
    float x = a[i] * 0.000061f - g0[i];        // g, gravity removed
    float yt = tremorBP[i].run(x), ys = strokeBP[i].run(x);
    eT += yt * yt; eS += ys * ys;
  }
  pTremor += ALPHA * (eT - pTremor);
  pStroke += ALPHA * (eS - pStroke);
  float rmsMg = sqrtf(pTremor) * 1000.0f;
  float ratio = pTremor / (pStroke + 1e-12f);

  if (!flagged) {
    holdCount = (ratio > ON_RATIO && rmsMg > ON_MG) ? holdCount + 1 : 0;
    if (holdCount >= HOLD) { flagged = true; holdCount = 0; }
  } else {
    holdCount = (ratio < OFF_RATIO || rmsMg < OFF_MG) ? holdCount + 1 : 0;
    if (holdCount >= HOLD) { flagged = false; holdCount = 0; }
  }

  static uint32_t n = 0; n++;
  static float vbat = 4.0f;
  if (n % 104 == 0) vbat = readVbat();          // once per second
  bool low = vbat < VBAT_LOW;
  // low battery: three short pulses every ~10 s instead of tremor cues
  int duty = 0;
  if (low) { uint32_t k = n % 1040; duty = (k < 10 || (k > 20 && k < 30) || (k > 40 && k < 50)) ? MOTOR_PWM : 0; }
  else duty = flagged ? MOTOR_PWM : 0;
  analogWrite(PIN_MOTOR, duty);

#if !LOG_RAW
  if (n % 5 == 0)
    Serial.printf("band_mg:%.1f,on:%d,off:%d,motor:%d,ratio:%.2f,vbat:%.2f\n", rmsMg, (int)ON_MG, (int)OFF_MG, flagged ? 20 : 0, ratio, vbat);
#endif
}
