import json, copy
import docx
from docx.shared import Pt, Inches, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_COLOR_INDEX
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.oxml.ns import qn
from docx.oxml import OxmlElement

R = json.load(open('results.json'))
def ins(parent, el, before):
    for c in parent:
        if c.tag.split('}')[1] in before:
            c.addprevious(el); return
    parent.append(el)
PPR_AFTER_SHD=('tabs','suppressAutoHyphens','kinsoku','wordWrap','overflowPunct','topLinePunct','autoSpaceDE','autoSpaceDN','bidi','adjustRightInd','snapToGrid','spacing','ind','contextualSpacing','mirrorIndents','suppressOverlap','jc','textDirection','textAlignment','textboxTightWrap','outlineLvl','divId','cnfStyle','rPr','sectPr','pPrChange')
PPR_AFTER_NUM=('suppressLineNumbers','pBdr','shd')+PPR_AFTER_SHD

d = docx.Document('tpl.docx')
ST = {s.name: s for s in d.styles}
H1, H2 = ST['Heading 1'], ST['Heading 2']
body = d.element.body
paras = list(body.iterchildren(qn('w:p')))

def set_text(p_el, text, highlight=False):
    p = docx.text.paragraph.Paragraph(p_el, d._body)
    runs = p.runs
    if runs:
        runs[0].text = text
        for r in runs[1:]: r.text = ''
        if highlight: runs[0].font.highlight_color = WD_COLOR_INDEX.YELLOW
    else:
        r = p.add_run(text)
        if highlight: r.font.highlight_color = WD_COLOR_INDEX.YELLOW

# ---------- cover + headers ----------
for p in d.paragraphs:
    t = p.text
    if t == '<Project Title>': set_text(p._p, 'Tremor Cue Pen: A Tremor-Detecting Pen Attachment with Haptic Feedback')
    elif t.startswith('Final Requirements in'): set_text(p._p, 'Final Requirements in CPE306: Fundamentals of Mixed Signals and Sensors')
    elif t == '<Your Name>': set_text(p._p, '<Your Name>', highlight=True)
    elif t == '<LOGO>': set_text(p._p, '<LOGO>', highlight=True)
for s in d.sections:
    for part in (s.header, s.first_page_header, s.even_page_header):
        for p in part.paragraphs:
            if '<Project Name>' in p.text: set_text(p._p, 'Tremor Cue Pen')

# trim cover spacing so 'Submitted to' block stays on page 1
ps=d.paragraphs; i=[k for k,p in enumerate(ps) if p.text=='<Your Name>'][0]
for p in ps[i+1:i+5]:
    if not p.text.strip(): p._p.getparent().remove(p._p)
# the template's empty Heading 1 after the TOC becomes section A
anchor = [p for p in d.paragraphs if p.style.name == 'Heading 1' and not p.text.strip()][-1]
anchor.text = 'A. Purpose and Overview'

def para(text='', style=None, bold_lead=None, size=None, italic=False, align=None, space_after=6):
    p = d.add_paragraph(style=style)
    if bold_lead:
        r = p.add_run(bold_lead); r.bold = True
        if size: r.font.size = Pt(size)
    if text:
        r = p.add_run(text); r.italic = italic
        if size: r.font.size = Pt(size)
    p.paragraph_format.space_after = Pt(space_after)
    if align: p.alignment = align
    return p

def h1(t):
    p = d.add_paragraph(style=H1)
    p.add_run(t)
    p.paragraph_format.page_break_before = True
    return p

def h2(t): return d.add_paragraph(t, style=H2)

# bullets via a simple numbering definition
numbering = d.part.numbering_part.element
abs_id, num_id = 90, 90
an = OxmlElement('w:abstractNum'); an.set(qn('w:abstractNumId'), str(abs_id))
for lvl, (fmt, txt) in enumerate([('bullet', '•')]):
    l = OxmlElement('w:lvl'); l.set(qn('w:ilvl'), str(lvl))
    for tag, val in [('w:start', '1'), ('w:numFmt', fmt), ('w:lvlText', txt), ('w:lvlJc', 'left')]:
        e = OxmlElement(tag); e.set(qn('w:val'), val); l.append(e)
    ppr = OxmlElement('w:pPr'); ind = OxmlElement('w:ind'); ind.set(qn('w:left'), '540'); ind.set(qn('w:hanging'), '270'); ppr.append(ind); l.append(ppr)
    an.append(l)
first_num = numbering.find(qn('w:num'))
if first_num is not None: first_num.addprevious(an)
else: numbering.append(an)
n = OxmlElement('w:num'); n.set(qn('w:numId'), str(num_id)); a = OxmlElement('w:abstractNumId'); a.set(qn('w:val'), str(abs_id)); n.append(a); numbering.append(n)

def bullet(text, lead=None):
    p = para(text, bold_lead=lead, space_after=3)
    pPr = p._p.get_or_add_pPr(); np_ = OxmlElement('w:numPr')
    il = OxmlElement('w:ilvl'); il.set(qn('w:val'), '0'); ni = OxmlElement('w:numId'); ni.set(qn('w:val'), str(num_id))
    np_.append(il); np_.append(ni); ins(pPr, np_, PPR_AFTER_NUM)
    return p

def shade(cell, hexcolor):
    tcPr = cell._tc.get_or_add_tcPr(); sh = OxmlElement('w:shd')
    sh.set(qn('w:val'), 'clear'); sh.set(qn('w:color'), 'auto'); sh.set(qn('w:fill'), hexcolor); tcPr.append(sh)

def table(rows, widths, header=True, size=9, pending_col=None):
    t = d.add_table(rows=len(rows), cols=len(rows[0]))
    t.style = None
    t.alignment = WD_TABLE_ALIGNMENT.CENTER
    tblPr = t._tbl.tblPr
    borders = OxmlElement('w:tblBorders')
    for side in ('top', 'left', 'bottom', 'right', 'insideH', 'insideV'):
        b = OxmlElement(f'w:{side}'); b.set(qn('w:val'), 'single'); b.set(qn('w:sz'), '4'); b.set(qn('w:color'), '999999'); borders.append(b)
    ins(tblPr, borders, ('shd','tblLayout','tblCellMar','tblLook','tblCaption','tblDescription','tblPrChange'))
    for i, row in enumerate(rows):
        for j, val in enumerate(row):
            c = t.cell(i, j); c.width = Inches(widths[j])
            p = c.paragraphs[0]; p.paragraph_format.space_after = Pt(0)
            r = p.add_run(str(val)); r.font.size = Pt(size)
            if header and i == 0: r.bold = True; shade(c, 'E7E6E6')
            elif pending_col is not None and j == pending_col and str(val).startswith('Pending'):
                r.font.highlight_color = WD_COLOR_INDEX.YELLOW
    d.add_paragraph().paragraph_format.space_after = Pt(2)
    return t

def figure(path, caption, width=6.3):
    p = d.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.add_run().add_picture(path, width=Inches(width))
    c = para(caption, italic=True, size=9, align=WD_ALIGN_PARAGRAPH.CENTER, space_after=10)

def code(path, title):
    para(title, bold_lead=None, size=10, space_after=2).runs[0].bold = True
    for line in open(path).read().rstrip('\n').split('\n'):
        p = d.add_paragraph(); pf = p.paragraph_format
        pf.space_after = Pt(0); pf.space_before = Pt(0); pf.line_spacing = 1.0
        r = p.add_run(line if line else ' '); r.font.name = 'Consolas'; r.font.size = Pt(7.5)
        r._element.rPr.rFonts.set(qn('w:eastAsia'), 'Consolas')
        pPr = p._p.get_or_add_pPr(); sh = OxmlElement('w:shd'); sh.set(qn('w:val'), 'clear'); sh.set(qn('w:fill'), 'F3F3F3'); ins(pPr, sh, PPR_AFTER_SHD)
    d.add_paragraph()

# =================== A ===================
para('Hand tremor makes handwriting shaky and hard to read. Parkinsonian rest tremor usually sits around 4–6 Hz, and essential tremor, the more common cause of shaky handwriting, runs from about 4 to 12 Hz. The writer often cannot tell exactly when the tremor starts while they are concentrating on the words.')
para('The Tremor Cue Pen is a 3D-printed cylinder that slides over an ordinary ballpen. Inside it, a motion sensor near the tip measures how the pen moves, firmware separates the slow movement of normal writing from the faster shaking of tremor, and a small vibration motor gives the writer a gentle buzz while tremor is present. The cue tells the writer to pause, slow down, or brace the hand.')
para('The pen detects and cues; it does not cancel tremor. A coin vibration motor shakes at roughly 150–250 Hz and cannot push back against a 4–6 Hz movement, so active cancellation would need a different actuator and is outside this project.', bold_lead='What it does not do. ')
h2('How it works')
figure('fig/block.png', 'Figure 1. System block diagram')
bullet('The LSM6DS3 measures acceleration on three axes. Its internal converter samples at 104 Hz with a ±2 g range, and its built-in 50 Hz anti-aliasing filter removes fast vibration before the samples are read over I²C.', 'Sense. ')
bullet('The ESP32-S3 removes gravity, then runs every axis through two band-pass filters: a stroke band (0.5–3 Hz) for writing movement and a tremor band (4–12 Hz).', 'Filter. ')
bullet('The power in each band is averaged over about 1 s. Tremor is flagged when the tremor-band power is more than 3 times the stroke-band power and the tremor-band level is above 30 mg for half a second.', 'Decide. ')
bullet('While tremor is flagged, the ESP32-S3 sends PWM to the DRV8833 motor driver, which runs the coin motor at about one third power.', 'Cue. ')
bullet('A voltage divider feeds the battery voltage to the ESP32-S3 ADC. Below 3.4 V the pen gives a three-pulse low-battery pattern.', 'Monitor. ')
h2('Hardware')
table([
    ['Part', 'Role', 'Notes'],
    ['ESP32-S3 SuperMini', 'Sampling, filtering, decision, PWM', 'Wi-Fi and Bluetooth off, CPU at 80 MHz to cut heat and current'],
    ['LSM6DS3 6-axis IMU', 'Acceleration sensing', 'I²C address 0x6A; gyroscope used only for logging'],
    ['DRV8833 dual H-bridge', 'Motor driver', 'AIN1 from PWM, AIN2 to GND, nSLEEP to 3V3'],
    ['Coin ERM vibration motor', 'Haptic cue', '3 V; run at 350 of 1023 PWM because full power is too strong'],
    ['LiPo 1S cell', 'Power', 'With protection PCB'],
    ['TP4056 charger module', 'Charging and protection', 'USB-C input; overcharge and overdischarge cut-off'],
    ['Slide switch', 'Power on/off', 'Between the charger output and the board'],
    ['2 × 100 kΩ resistors, 100 nF capacitor', 'Battery sense divider and filter', 'Halves the battery voltage into the ADC range'],
    ['3D-printed cylinder', 'Enclosure', 'Slides over a ballpen; IMU at the tip end, motor in foam'],
], [1.7, 1.8, 2.8])
h2('Wiring')
table([
    ['From', 'To', 'ESP32-S3 GPIO'],
    ['LSM6DS3 SDA', 'I²C data', 'GPIO8'],
    ['LSM6DS3 SCL', 'I²C clock', 'GPIO9'],
    ['LSM6DS3 SDO, CS', 'GND and 3V3 (selects I²C, address 0x6A)', '—'],
    ['DRV8833 AIN1', 'Motor PWM', 'GPIO4'],
    ['Battery divider midpoint', 'ADC1 channel 0', 'GPIO1'],
], [1.9, 2.9, 1.5])

# =================== B ===================
h1('B. Scope and Limitations')
h2('Scope')
bullet('Detects hand tremor in the 4–12 Hz band in real time while the pen is used, with about 1 s of smoothing and 0.5 s of confirmation.')
bullet('Tells tremor apart from normal handwriting and drawing using the ratio of tremor-band to stroke-band power.')
bullet('Gives a haptic cue through a coin motor and a low-battery warning pattern.')
bullet('Runs on a rechargeable LiPo cell inside a cylinder attachment for a standard ballpen.')
bullet('Streams detector values or raw sensor data over USB for logging and analysis.')
h2('Limitations')
bullet('Tremor was simulated by deliberately shaking the hand at about 7 Hz. No recordings come from people with Parkinson’s disease or essential tremor, and the device makes no clinical claim.', 'Simulated tremor only. ')
bullet('Thresholds were chosen on the same five recordings used to report the results, so those results are optimistic until checked on new recordings.', 'Tuned and tested on the same data. ')
bullet('The detection recordings were made with the sensor strapped to the wrist on the NodeMCU prototype. The final ESP32-S3 pen uses the same sensor settings and algorithm, but the recordings must be repeated with the sensor in the pen.', 'Prototype rig. ')
bullet('The pen cues the writer and does not reduce the tremor itself.', 'No cancellation. ')
bullet('Fast strokes and pen-lift jerks can still produce occasional false cues (about 2.5% of normal writing time).', 'False cues. ')
bullet('The motor vibrates at 150–250 Hz, above the sensor’s 52 Hz Nyquist limit. Any vibration that passes the sensor’s anti-aliasing filter could fold back into the tremor band and keep the motor on. This must be checked with the motor coupling test (Section F).', 'Motor feedback risk. ')
h2('Future work')
bullet('Counting tremor cues and their total duration over days or weeks could show whether tremor is frequent or getting worse. Above a set level, the pen could suggest that the user consult a physician, who can refer to a neurologist if needed. This would be a prompt to seek care, not a diagnosis, and its threshold would need validation on real users so that fast writers are not flagged. It is outside the scope of this study.', 'Cue frequency as a check-up prompt. ')

# =================== C ===================
h1('C. Relevance in Fundamentals of Mixed Signals and Sensors')
para('The project follows one physical quantity, hand acceleration, from a sensor to a digital decision and back out to a physical actuator. Each stage maps to a CPE306 topic.')
table([
    ['CPE306 topic', 'Where it appears in the project'],
    ['Sensors and transducers', 'MEMS capacitive accelerometer: a proof mass moves between fixed plates, changing capacitance with acceleration'],
    ['Signal conditioning', 'Inside the IMU: charge amplifier, internal ADC, 50 Hz anti-aliasing low-pass; outside: RC filter on the battery divider'],
    ['Sampling theorem', '104 Hz sampling gives a 52 Hz Nyquist limit, well above the 12 Hz tremor band edge'],
    ['A/D conversion', 'IMU 16-bit output (±2 g, 0.061 mg per count); ESP32-S3 12-bit ADC for battery voltage with 16× averaging'],
    ['D/A conversion', 'PWM duty cycle sets the average motor voltage (PWM acting as a 1-bit DAC with the motor as the low-pass load)'],
    ['Digital signal processing', 'Second-order IIR biquad high-pass and low-pass filters, exponential averaging, ratio decision with hysteresis'],
    ['Power switching devices', 'DRV8833 MOSFET H-bridge switched at 20 kHz'],
    ['Measurement theory and calibration', 'Gravity reference at start-up, noise floor and 1 g magnitude check, threshold selection from recorded data'],
], [1.9, 4.4])
h2('Sensor and signal chain')
para('The LSM6DS3 is a MEMS accelerometer. Acceleration moves a tiny suspended mass, the change in capacitance is converted to a voltage by an internal charge amplifier, filtered by an internal anti-aliasing low-pass, and digitised by the sensor’s own converter. The ESP32-S3 reads the result as 16-bit numbers over I²C, so all analog conditioning for the motion signal happens on the sensor chip. With the ±2 g range, one count is 0.061 mg.')
para(f'The sensor was set to 104 samples per second. By the sampling theorem the highest frequency it can represent is 52 Hz, about four times the 12 Hz top of the tremor band. The internal 50 Hz anti-aliasing filter attenuates motion above that limit before it can fold back into the band of interest.')
h2('Filtering')
para('Each band-pass is a second-order high-pass followed by a second-order low-pass (Butterworth-like, Q = 0.707), computed from the bilinear-transform biquad formulas at fs = 104 Hz. The stroke band (0.5–3 Hz) holds the slow movement of writing; the tremor band (4–12 Hz) holds the shaking. Gravity is measured at start-up and subtracted from every sample so the filters do not ring at power-on.')
figure('fig/filters.png', 'Figure 2. Frequency response of the two firmware band-pass filters')
h2('Why a ratio and not a threshold')
para('The first version of the firmware turned the motor on whenever the tremor-band level passed a fixed threshold. The recordings showed that normal handwriting itself puts energy in the 4–6 Hz range, so that version fired during 40% of normal writing. Tremor raises the tremor band relative to the stroke band, while writing raises the stroke band. The ratio of the two separates them even when their absolute levels overlap.')
figure('fig/spectra.png', 'Figure 3. Acceleration spectrum per recording. Writing peaks inside the stroke band; simulated tremor peaks at about 7 Hz inside the tremor band.')
h2('Analog-to-digital and digital-to-analog stages')
para('Battery voltage (3.0–4.2 V) is above the ESP32-S3 ADC range, so two 100 kΩ resistors halve it and a 100 nF capacitor across the lower resistor filters switching noise. The firmware averages 16 readings, which lowers random noise by a factor of about 4 (2 bits), and reads calibrated millivolts with analogReadMilliVolts(). The divider draws about 21 µA at 4.2 V.')
para('The ESP32-S3 has no DAC. Instead, the motor is driven with a 20 kHz PWM signal. The motor’s winding inductance and rotor inertia average the pulses, so the duty cycle acts as the output level: 350 of 1023 gives an average of about 34% of the supply voltage.')
h2('Calibration and measurement')
sx, sy, sz = R['idle_std_mg']
para(f'With the sensor still, the measured acceleration magnitude was {R["idle_mag_g"]:.3f} g against the expected 1 g, an error of about {abs(1-R["idle_mag_g"])*100:.1f}%. The noise standard deviation was {sx:.1f}, {sy:.1f} and {sz:.1f} mg on the three axes, and the tremor-band level at rest was below 1 mg, far under the 30 mg detection gate. Because the detector uses band-pass filtered signals, a constant offset or a gain error of a few percent does not change the decision. A six-orientation calibration (±1 g on each axis) can be added to measure offset and gain per axis.')
h2('Alternatives considered')
table([
    ['Decision', 'Options', 'Chosen and why'],
    ['Motion sensor', 'Analog accelerometer (ADXL335) with external op-amp filter; digital IMU (LSM6DS3)', 'Digital IMU: built-in anti-aliasing and converter, low noise, I²C with two wires'],
    ['Detection method', 'Tremor-band energy threshold; FFT peak frequency; tremor/stroke ratio; gyroscope energy', 'Ratio: fewest false cues on writing (2.5% vs 40%) and best detection while writing'],
    ['Actuator', 'Coin ERM motor; linear resonant actuator (LRA); piezo buzzer', 'ERM: on hand, strong, simple to drive; LRA needs a dedicated driver'],
    ['Controller', 'NodeMCU (ESP8266); ESP32-S3 SuperMini', 'ESP32-S3 for the final pen: smaller, more ADC channels, native USB; NodeMCU used for the prototype'],
], [1.3, 2.6, 2.4])
para('Comparison of detection methods on the five recordings (percentage of time flagged after a 2.5 s warm-up):', space_after=3)
table([['Detector', 'Idle', 'Writing', 'Drawing', 'Tremor', 'Tremor + writing']] +
      [['Energy only (>170 mg)'] + [f"{R[k]['energy']:.0f}%" for k in ['idle','normal_writing','drawing','fake_tremor','fake_tremor_writing']],
       ['Ratio detector'] + [f"{R[k]['flagged']:.0f}%" for k in ['idle','normal_writing','drawing','fake_tremor','fake_tremor_writing']]],
      [1.6, 0.8, 0.9, 0.9, 0.9, 1.2])

# =================== D ===================
h1('D. User Interfaces')
h2('Writer')
para('The writer uses the pen like any ballpen. The only controls are the power switch and the USB-C charging port; all feedback is through vibration.')
table([
    ['Event', 'What the writer feels', 'Condition'],
    ['Power on', 'Nothing for about 1 s while the pen measures gravity', 'Hold the pen still at switch-on'],
    ['Tremor detected', 'Continuous gentle buzz', 'Ratio > 3 and level > 30 mg for 0.5 s'],
    ['Tremor stops', 'Buzz stops', 'Ratio < 1.5 or level < 20 mg for 0.5 s'],
    ['Low battery', 'Three short pulses about every 10 s', 'Battery below 3.4 V'],
    ['Charging', 'Charger LED on', 'USB-C connected'],
], [1.4, 2.6, 2.3])
h2('Developer and tester')
para('Over USB, the pen streams one line every 5 samples (about 20 lines per second). The Arduino Serial Plotter draws these as live graphs, and the Python logger saves them as labelled CSV files.')
table([
    ['Field', 'Meaning'],
    ['band_mg', 'Tremor-band level (smoothed RMS, mg)'],
    ['on, off', 'Start and stop level gates (30 and 20 mg), drawn as reference lines'],
    ['motor', '20 while the cue is on, 0 otherwise'],
    ['ratio', 'Tremor-band ÷ stroke-band power'],
    ['vbat', 'Battery voltage (V)'],
], [1.4, 4.9])
para('Setting LOG_RAW to 1 switches the stream to raw accelerometer and gyroscope counts for recording new data:', space_after=3)
p = para('python record.py normal_writing 30 /dev/ttyACM0', space_after=8)
p.runs[0].font.name = 'Consolas'; p.runs[0].font.size = Pt(9)

# =================== E ===================
h1('E. Code')
para('Firmware for the ESP32-S3 SuperMini, written for the Arduino-ESP32 core 3.x (board “ESP32S3 Dev Module”, USB CDC On Boot enabled).')
table([
    ['Setting', 'Value', 'Reason'],
    ['Sample rate', '104 Hz', 'Sensor output rate, above twice the 12 Hz band edge'],
    ['Stroke band', '0.5–3 Hz', 'Writing and arm movement'],
    ['Tremor band', '4–12 Hz', 'Parkinsonian and essential tremor'],
    ['Smoothing', 'α = 0.01 (about 1 s)', 'Longer smoothing reduced false cues'],
    ['Start rule', 'Ratio > 3 and level > 30 mg for 0.5 s', 'Ratio rejects writing; level gate rejects sensor noise'],
    ['Stop rule', 'Ratio < 1.5 or level < 20 mg for 0.5 s', 'Hysteresis prevents on/off chatter'],
    ['Motor PWM', '350 of 1023 at 20 kHz', 'Full power is too strong; 20 kHz is silent'],
], [1.3, 2.2, 2.8])
code('tremor_cue_pen.ino', 'tremor_cue_pen.ino')
code('/mnt/user-data/uploads/record.py', 'record.py (data logger)')

# =================== F ===================
h1('F. Use/Test Cases (Testing)')
para('Five 30 s recordings were made with the sensor strapped to the wrist (NodeMCU prototype, same sensor settings). The firmware’s filters and decision rules were then replayed on the raw data. Percentages are the share of time the cue was on, after a 2.5 s warm-up.')
k = R
table([
    ['ID', 'Test case', 'Expected', 'Result', 'Status'],
    ['TC1', 'Pen at rest on the table', 'No cue (0%)', f"{k['idle']['flagged']:.0f}%", 'Pass'],
    ['TC2', 'Normal handwriting', 'Cue ≤ 5% of the time', f"{k['normal_writing']['flagged']:.1f}%", 'Pass'],
    ['TC3', 'Drawing shapes', 'Cue ≤ 5% of the time', f"{k['drawing']['flagged']:.0f}%", 'Pass'],
    ['TC4', 'Simulated tremor, no writing', 'Cue ≥ 90% of the time', f"{k['fake_tremor']['flagged']:.0f}%", 'Pass'],
    ['TC5', 'Simulated tremor while writing', 'Cue ≥ 70% of the time', f"{k['fake_tremor_writing']['flagged']:.0f}%", 'Pass'],
    ['TC6', 'Two new writing runs (new words), held out', 'Cue ≤ 5%', 'Pending', 'Pending'],
    ['TC7', 'Weak simulated tremor, held out', 'Cue ≥ 50%', 'Pending', 'Pending'],
    ['TC8', 'Motor forced on, pen still', 'Ratio and level stay below start rule', 'Pending', 'Pending'],
    ['TC9', 'TC1–TC5 repeated with sensor in the pen cylinder', 'Same limits as TC1–TC5', 'Pending', 'Pending'],
    ['TC10', 'Battery below 3.4 V (bench supply)', 'Three-pulse pattern', 'Pending', 'Pending'],
    ['TC11', 'Unplug IMU while running, then reconnect', 'Motor off, sensor re-initialised', 'Pending', 'Pending'],
], [0.5, 2.3, 1.6, 0.9, 1.0], pending_col=3)
for row in d.tables[-1].rows[1:]:
    c = row.cells[4]; r = c.paragraphs[0].runs[0]
    if r.text == 'Pending': r.font.highlight_color = WD_COLOR_INDEX.YELLOW
figure('fig/compare.png', 'Figure 4. Share of time flagged: energy-only threshold against the ratio detector')
figure('fig/ratio.png', 'Figure 5. Detector ratio over each 30 s recording. Simulated tremor stays above the start line; writing and drawing stay below it.')
h2('Signal summary per recording')
table([['Recording', 'Dominant frequency', 'Median ratio', 'Median tremor-band level']] +
      [[R[x]['name'], f"{R[x]['peak']:.1f} Hz", f"{R[x]['ratio_med']:.2f}", f"{R[x]['rms_med']:.1f} mg"] for x in ['idle','normal_writing','drawing','fake_tremor','fake_tremor_writing']],
      [2.0, 1.4, 1.2, 1.7])
para('At rest the ratio is around 2–3 because both bands contain only sensor noise, which is why the 30 mg level gate is part of the start rule: the tremor-band level at rest is under 1 mg, so the pen never cues while idle.')
para('The simulated tremor peaks at about 7 Hz, the shaking rate used during recording, while normal writing peaks at 2 Hz inside the stroke band. All recordings ran at about 104 Hz with no lost samples.')

# ask Word to refresh the table of contents on open
settings = d.settings.element


d.save('Tremor_Cue_Pen_Final_Project.docx')
print('saved')
