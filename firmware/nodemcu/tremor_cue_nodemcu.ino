// Tremor Cue Pen - NodeMCU (ESP8266) test firmware
// LSM6DS3 accel (I2C) -> stroke band 0.5-3 Hz + tremor band 4-12 Hz
// -> tremor/stroke power ratio with hysteresis -> DRV8833 PWM -> coin motor
//
// Board: "NodeMCU 1.0 (ESP-12E Module)", ESP8266 Arduino core 3.x, 115200 baud.
// Wiring: LSM6DS3 SDA -> D2, SCL -> D1, SDO -> GND (addr 0x6A), CS -> 3V3
//         DRV8833 AIN1 -> D5, AIN2 -> GND, nSLEEP -> 3V3, VM -> 5V (USB) or battery
//
// Serial commands (type in the Serial Monitor, "No line ending" or "Newline"):
//   r  toggle raw logging (for record.py)       a  automatic motor (default)
//   m  motor forced ON  (coupling test, TC8)     o  motor forced OFF
//   ?  print settings  (motor is always full strength when on)

#include <Wire.h>
#include <ESP8266WiFi.h>

// ---------- pins ----------
const int PIN_SDA   = D2;
const int PIN_SCL   = D1;
const int PIN_MOTOR = D5;

// ---------- settings (same as the report) ----------
const uint8_t IMU      = 0x6A;
const float   FS       = 104.0f;
const float   ALPHA    = 0.01f;          // power smoothing, time constant ~1 s
const float   ON_RATIO = 3.0f,  ON_MG  = 30.0f;
const float   OFF_RATIO = 1.5f, OFF_MG = 20.0f;
const int     HOLD     = (int)(0.5f * FS);   // 0.5 s confirmation
const int     MOTOR_FULL = 1023;         // only level used: full on, or off (the transistor module needs high duty)
const int     PULSE_SAMPLES  = (int)(0.7f * FS);   // motor-on duration per cue
const int     REFRAC_SAMPLES = (int)(1.0f * FS);   // ignore retrigger after a pulse so motor ringing dies down
const unsigned long PERIOD_US = (unsigned long)(1e6f / FS);
const float   LSB_G    = 0.000061f;      // +/-2 g range

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
float g0[3];
float pTremor = 0, pStroke = 0;
// cueState: 0 = watching, 1 = pulsing (motor on), 2 = refractory (motor off,
// ignore retrigger so the motor's own vibration has time to die out before
// the next evaluation - otherwise the buzz looks like tremor to the IMU and
// never stops)
int   cueState = 0;
int   stateCount = 0;
int   holdCount = 0;
bool  logRaw = false;
char  motorMode = 'a';                   // a = auto, m = forced on, o = forced off
unsigned long nextT;
int16_t lastRaw[3];
int   frozenCount = 0;

// ---------- IMU ----------
void wr(uint8_t reg, uint8_t v) {
  Wire.beginTransmission(IMU); Wire.write(reg); Wire.write(v); Wire.endTransmission();
}
bool rd(uint8_t reg, uint8_t *buf, uint8_t n) {
  Wire.beginTransmission(IMU); Wire.write(reg);
  if (Wire.endTransmission(false) != 0) return false;
  if (Wire.requestFrom(IMU, n) != n) return false;
  for (uint8_t i = 0; i < n; i++) buf[i] = Wire.read();
  return true;
}
bool imuInit() {
  uint8_t id = 0;
  if (!rd(0x0F, &id, 1) || (id != 0x69 && id != 0x6A && id != 0x6C)) {
    Serial.printf("bad WHO_AM_I 0x%02X\n", id);
    return false;
  }
  wr(0x12, 0x44);   // CTRL3_C: auto-increment, block data update
  wr(0x10, 0x43);   // CTRL1_XL: 104 Hz, +/-2 g, 50 Hz anti-alias bandwidth
  wr(0x11, 0x40);   // CTRL2_G: gyro 104 Hz, 245 dps (logging only)
  return true;
}
bool readIMU(int16_t a[3], int16_t g[3]) {
  uint8_t b[12];
  if (!rd(0x22, b, 12)) return false;    // OUTX_L_G .. OUTZ_H_XL
  for (int i = 0; i < 3; i++) {
    g[i] = (int16_t)((b[2 * i + 1] << 8) | b[2 * i]);       // explicit byte order
    a[i] = (int16_t)((b[2 * i + 7] << 8) | b[2 * i + 6]);
  }
  return true;
}

void resetFilters() {
  for (int i = 0; i < 3; i++) { tremorBP[i].set(4.0f, 12.0f); strokeBP[i].set(0.5f, 3.0f); }
  float s[3] = {0, 0, 0}; int n = 0; int16_t a[3], g[3];
  while (n < 32) {                       // gravity reference: hold the pen still at start
    if (readIMU(a, g)) { for (int i = 0; i < 3; i++) s[i] += a[i] * LSB_G; n++; }
    delay(10);
  }
  for (int i = 0; i < 3; i++) g0[i] = s[i] / n;
  pTremor = pStroke = 0; cueState = 0; stateCount = 0; holdCount = 0;
}

void printSettings() {
  Serial.printf("# start ratio>%.1f & level>%.0f mg for 0.5 s | stop ratio<%.1f or level<%.0f mg | motor PWM %d/1023 | raw %s | motor %c\n",
                ON_RATIO, ON_MG, OFF_RATIO, OFF_MG, MOTOR_FULL, logRaw ? "on" : "off", motorMode);
}

void handleSerial() {
  while (Serial.available()) {
    char c = Serial.read();
    if (c == 'r') logRaw = !logRaw;
    else if (c == 'a' || c == 'm' || c == 'o') motorMode = c;
    else if (c != '?') continue;
    printSettings();
  }
}

void setup() {
  WiFi.mode(WIFI_OFF);                   // radio off: less heat, less noise
  WiFi.forceSleepBegin();
  Serial.begin(115200);
  delay(300);
  Wire.begin(PIN_SDA, PIN_SCL);
  Wire.setClock(400000);
  analogWriteRange(1023);                // core 3.x defaults to 255
  analogWriteFreq(1000);                 // 1 kHz: the vibration module's transistor can't follow 20 kHz
  pinMode(PIN_MOTOR, OUTPUT);
  analogWrite(PIN_MOTOR, 0);
  while (!imuInit()) delay(500);
  resetFilters();
  printSettings();
  nextT = micros();
}

void loop() {
  handleSerial();
  if ((long)(micros() - nextT) < 0) return;
  nextT += PERIOD_US;

  int16_t a[3], g[3];
  if (!readIMU(a, g)) {
    Serial.println("i2c fail");
    analogWrite(PIN_MOTOR, 0);
    delay(100); imuInit(); resetFilters(); nextT = micros();
    return;
  }
  bool same = a[0] == lastRaw[0] && a[1] == lastRaw[1] && a[2] == lastRaw[2];
  frozenCount = same ? frozenCount + 1 : 0;
  memcpy(lastRaw, a, sizeof(lastRaw));
  if (frozenCount > 50) {
    Serial.println("frozen, reinit");
    imuInit(); resetFilters(); frozenCount = 0; nextT = micros();
    return;
  }

  float eT = 0, eS = 0;
  for (int i = 0; i < 3; i++) {
    float x = a[i] * LSB_G - g0[i];
    float yt = tremorBP[i].run(x), ys = strokeBP[i].run(x);
    eT += yt * yt; eS += ys * ys;
  }
  pTremor += ALPHA * (eT - pTremor);
  pStroke += ALPHA * (eS - pStroke);
  float rmsMg = sqrtf(pTremor) * 1000.0f;
  float ratio = pTremor / (pStroke + 1e-12f);

  if (cueState == 0) {
    holdCount = (ratio > ON_RATIO && rmsMg > ON_MG) ? holdCount + 1 : 0;
    if (holdCount >= HOLD) { cueState = 1; stateCount = 0; holdCount = 0; }
  } else if (cueState == 1) {
    if (++stateCount >= PULSE_SAMPLES) { cueState = 2; stateCount = 0; }
  } else {
    if (++stateCount >= REFRAC_SAMPLES) { cueState = 0; stateCount = 0; }
  }

  bool motorOn = motorMode == 'm' || (motorMode == 'a' && cueState == 1);
  analogWrite(PIN_MOTOR, motorOn ? MOTOR_FULL : 0);

  static uint32_t n = 0; n++;
  if (logRaw) {
    Serial.printf("raw,%lu,%d,%d,%d,%d,%d,%d\n", millis(), a[0], a[1], a[2], g[0], g[1], g[2]);
  } else if (n % 5 == 0) {
    Serial.printf("band_mg:%.1f,on:%d,off:%d,motor:%d,ratio:%.2f,flag:%d\n",
                  rmsMg, (int)ON_MG, (int)OFF_MG, motorOn ? 20 : 0, ratio, cueState);
  }
}
