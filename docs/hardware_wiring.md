# Sonic Shield — Hardware Wiring Guide

## Bill of Materials

### Master Node (1×)
| Component | Part | Qty | Purpose |
|-----------|------|-----|---------|
| FPGA Board | UPduino v3.x | 1 | Main controller |
| Microphone | LM393 sound sensor module | 1 | Detects bird flock noise |
| PIR Sensor | HC-SR501 | 1 | Detects bird movement |
| Transistor | 2N2222 NPN | 1 | Drives local master piezo |
| Resistor | 1kΩ 1/4W | 1 | Transistor base current limiter |
| Diode | 1N4148 | 1 | Flyback protection across piezo |
| 433MHz TX | FS1000A transmitter module | 1 | Wireless trigger to satellite nodes |
| Piezo Tweeter | 12V piezoelectric disk tweeter | 1 | Master node acoustic deterrent |
| Solar panel | 5–10W, 12V | 1 | Field power |
| Battery | 12V 4Ah sealed lead-acid | 1 | 3-day cloudy reserve |
| Voltage reg | AMS1117-3.3 or USB buck | 1 | 12V → 3.3V/5V for UPduino |

### Each Satellite Node (4×, one per corner)
| Component | Part | Qty | Purpose |
|-----------|------|-----|---------|
| 433MHz RX | XY-MK-5V receiver module | 1 | Receives trigger from master |
| 555 Timer | NE555 or LM555 | 1 | Local 18kHz oscillator |
| Transistor | 2N2222 NPN | 1 | Drives piezo |
| Resistor | 1kΩ | 1 | Transistor base |
| Resistor | 4.7kΩ | 1 | 555 timer timing (R1) |
| Resistor | 4.7kΩ | 1 | 555 timer timing (R2) |
| Capacitor | 10nF ceramic | 1 | 555 timer timing (C) |
| Diode | 1N4148 | 1 | Flyback across piezo |
| Piezo Tweeter | 12V piezoelectric disk tweeter | 1 | Satellite acoustic deterrent |
| Solar cell | 1–2W, 12V mini panel | 1 | Node self-power |
| Battery | 12V 1.2Ah sealed lead-acid | 1 | Overnight/cloudy reserve |

---

## Why Wireless? (Rice Farm Constraint)

Running wires across a flooded paddy field is dangerous (electrical shock risk) and impractical (wires corrode, get submerged). Each satellite node is self-powered and receives only a wireless trigger signal from the master.

The 433MHz link carries a simple binary signal:
- `rf_tx = HIGH` → deterrent active, satellites fire their speakers
- `rf_tx = LOW` → silent

433MHz at this power level travels 50–150m in open field with no obstacles — more than enough for a 1-acre (~64m × 64m) plot.

---

## Master Node — Transistor Driver Circuit

`speaker_out` (FPGA pin 26) drives the local master node piezo via a 2N2222:

```
        12V (+)
           │
        Piezo (+)
        Piezo (−) ─────────────────────────────┐
                                               │
        12V (+) ──[cathode]─[1N4148]─[anode]──┤  ← flyback clamp
                                               │
                                          Collector
                                          2N2222 NPN
        FPGA pin 26 ──[1kΩ]──────────── Base
                                          Emitter
                                               │
                                              GND
```

---

## Master Node — 433MHz Transmitter (FS1000A)

The FS1000A module has 3 pins: VCC, GND, DATA.

```
FS1000A        UPduino
VCC       →    5V (from USB buck or battery regulator)
GND       →    GND
DATA      →    pin 31 (rf_tx)
```

When `rf_tx` goes HIGH, the FS1000A broadcasts a 433MHz carrier. Satellites detect this and fire. When `rf_tx` goes LOW, carrier stops, satellites go silent.

**Antenna:** Solder a 17.3cm wire to the ANT pad on the FS1000A for ~433MHz quarter-wave. Without it, range drops to <10m.

---

## Satellite Node — Complete Circuit

Each satellite is self-contained. No MCU needed — a 555 timer generates the 18kHz tone locally.

### 555 Timer — 18kHz Oscillator

The NE555 in astable mode generates a ~18kHz square wave when the XY-MK-5V receiver asserts its output HIGH.

**Frequency formula:** `f = 1.44 / ((R1 + 2×R2) × C)`
With R1=4.7kΩ, R2=4.7kΩ, C=10nF:
`f = 1.44 / ((4700 + 9400) × 0.000000010) = 1.44 / 0.000141 ≈ 10.2kHz`

To get closer to 18kHz, use R1=2.2kΩ, R2=2.2kΩ, C=10nF:
`f = 1.44 / ((2200 + 4400) × 0.000000010) ≈ 21.8kHz`

Fine-tune with a trimmer pot (5kΩ) in place of R2 to dial in 17–18kHz.

```
   12V (+)
      │
      ├──────────────────────── pin 8 (VCC)
      │                              │
      │                        [R1 = 2.2kΩ]
      │                              │
      │                        pin 7 (DISCHARGE)
      │                              │
      │                        [R2 = 5kΩ trimmer]
      │                              │
      │                    ┌──── pin 6 (THRESHOLD)
      │                    │    pin 2 (TRIGGER)
      │                    │         │
      │                 [C = 10nF]   │
      │                    │         │
     GND ──────────────────┴─────────┘

   pin 4 (RESET) ─── 12V (tie HIGH = always enabled in standalone test)
                      └── XY-MK-5V DATA in satellite (see below)
   pin 1 (GND)  ─── GND
   pin 3 (OUT)  ──[1kΩ]── 2N2222 Base → Piezo driver (same circuit as master)
```

### Gating the 555 with the 433MHz Receiver

The XY-MK-5V receiver outputs HIGH on its DATA pin when it detects a 433MHz carrier. Use this to gate the 555 RESET pin:

```
XY-MK-5V DATA ──────────── 555 pin 4 (RESET)
```

When DATA=HIGH → 555 oscillates → piezo fires.
When DATA=LOW → 555 held in reset → output LOW → silence.

**Full satellite schematic:**
```
   12V (+)
      │
      ├──[5V regulator]────── XY-MK-5V VCC
      │                       XY-MK-5V GND ─── GND
      │                       XY-MK-5V DATA ── 555 pin 4 (RESET)
      │
      ├────────────────────── 555 pin 8 (VCC)   ← 555 oscillator
      │                            │                (R1/R2/C as above)
      │                       555 pin 3 (OUT)
      │                            │
      │                          [1kΩ]
      │                            │
      │                        2N2222 Base
      │                        2N2222 Collector ────── Piezo (−)
      │
      └───────────────────────────────────────── Piezo (+)

   12V (+) ──[cathode]─[1N4148]─[anode]──── Piezo (−) / Collector  ← flyback
   2N2222 Emitter ─── GND
   Piezo GND (−) implicitly via Collector → Emitter → GND when transistor ON
```

**Antenna on XY-MK-5V:** Solder a 17.3cm wire to the ANT pin. Required for reliable range across the field.

---

## Sensor Wiring (Master Node)

### LM393 Microphone Module
```
LM393          UPduino
VCC       →    3.3V
GND       →    GND
DO        →    pin 23 (mic_in)
```
Adjust the trimmer until the LED blinks when you clap near it.

### HC-SR501 PIR Sensor
```
HC-SR501       UPduino
VCC       →    5V
GND       →    GND
OUT       →    pin 25 (pir_in)
```
HC-SR501 output is 3.3V logic even on 5V supply — safe to connect directly.

### Reset Button
```
3.3V ──[10kΩ]── pin 34 (rst_n)
                     │
                 [Button]
                     │
                    GND
```
No button? Tie pin 34 directly to 3.3V.

---

## UPduino v3.x Pin Reference

| Ball # (PCF) | Header Label | Connected to |
|--------------|--------------|--------------|
| 23 | GPIO_0 | mic_in — LM393 DO |
| 25 | GPIO_2 | pir_in — HC-SR501 OUT |
| 26 | GPIO_3 | speaker_out — master node transistor |
| 28 | GPIO_5 | uart_tx — GSM RX (Phase 4) |
| 31 | GPIO_8 | rf_tx — FS1000A DATA |
| 34 | GPIO_11 | rst_n — pull-up + button |

**Verify header labels** against your board's silkscreen — minor UPduino revisions may differ.

---

## Field Layout (1-Acre Plot, Wireless)

```
  Satellite A (NW) ──────────────────────── Satellite B (NE)
        [*]          )))  433MHz  (((            [*]
         │                                        │
         │               ┌──────────┐             │
         │    )))        │  Master  │       (((   │
         │               │   Node   │             │
         │               │ FS1000A  │             │
         │               └──────────┘             │
         │                                        │
        [*]          )))  433MHz  (((            [*]
  Satellite C (SW) ──────────────────────── Satellite D (SE)
```

- Master at plot center, all 4 satellites receive the same 433MHz broadcast simultaneously.
- 1-acre ≈ 64m × 64m. Corner distance from center ≈ 45m. Well within 433MHz range.
- Each satellite is weatherproofed (IP65 enclosure) and self-powered.

---

## Power Budget

### Master Node
| Load | Current | Daily energy |
|------|---------|-------------|
| UPduino idle | 15mA @ 3.3V | 1.2Wh |
| LM393 + HC-SR501 | 5mA | 0.4Wh |
| FS1000A TX (active 10% of day) | 35mA @ 5V × 10% | 0.4Wh |
| Master piezo (active 10%) | 200mA @ 12V × 10% | 2.4Wh |
| **Total** | | **~4.4Wh/day** |

3-day reserve: 13.2Wh → **12V 2Ah battery (24Wh)** is sufficient with margin.

### Each Satellite Node
| Load | Current | Daily energy |
|------|---------|-------------|
| XY-MK-5V receiver | 4mA @ 5V | 0.5Wh |
| 555 + piezo (active 10%) | 200mA @ 12V × 10% | 2.4Wh |
| **Total** | | **~2.9Wh/day** |

3-day reserve: 8.7Wh → **12V 1.2Ah battery (14.4Wh)** per satellite.
