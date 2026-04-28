# Sonic Shield

FPGA-based acoustic bird deterrent for rice farms. Detects bird activity via microphone and PIR sensor, responds with a pseudo-random ultrasonic sweep (17–18kHz) to prevent habituation. Wireless satellite nodes extend coverage across the plot without running wires through flooded paddy fields.

Built on the **iCE40UP5K** (UPduino v3.x) using the fully open-source toolchain: Yosys + nextpnr + IceStorm.

---

## Architecture

```
                    ┌─────────────────────────────┐
                    │        Master Node           │
                    │                              │
  LM393 mic ───────►│ mic_in                       │
  HC-SR501 PIR ────►│ pir_in    iCE40UP5K          │──► speaker_out → piezo (local)
  Reset button ────►│ rst_n                        │
                    │           heartbeat (1Hz)    │──► rf_tx → FS1000A 433MHz TX
                    │           PRNG (LFSR)        │
                    │           PWM (17–18kHz)     │──► uart_tx → GSM (Phase 4)
                    │           UART (stub)        │
                    │                              │──► RGB LED (heartbeat blink)
                    └─────────────────────────────┘
                                  │ 433MHz
              ┌───────────────────┼───────────────────┐
              ▼                   ▼                   ▼
       Satellite A          Satellite B          Satellite C/D
    XY-MK-5V + 555       XY-MK-5V + 555       XY-MK-5V + 555
    + piezo tweeter       + piezo tweeter       + piezo tweeter
    (NW corner)           (NE corner)           (SW/SE corners)
```

**Why wireless satellites?** Rice paddy fields are flooded — running wires is a safety hazard and causes corrosion. Each satellite is self-powered (solar + battery) and receives only a binary trigger over 433MHz.

**Why 17–18kHz?** Effective against *Quelea* flocks. Capped at 18kHz to reduce discomfort for neighbors and livestock within 50m.

---

## Repository Structure

```
sonic-shield/
├── rtl/
│   ├── sonic_shield_board.v    # Synthesis top: SB_HFOSC + SB_RGBA_DRV wrappers
│   ├── sonic_shield_top.v      # Core logic (simulatable — takes explicit clk)
│   ├── bird_deterrent_pwm.v    # Countdown PWM generator
│   ├── prng.v                  # 16-bit Fibonacci LFSR
│   ├── heartbeat.v             # 1Hz tick from 12MHz clock
│   └── uart_tx.v               # 8N1 UART stub (Phase 4 telemetry)
├── sim/
│   ├── tb_bird_deterrent_pwm.v # PWM testbench (4 tests)
│   ├── tb_sonic_shield_top.v   # Top-level testbench (5 tests)
│   └── Makefile
├── pcf/
│   └── upduino_v3.pcf          # iCE40UP5K SG48 pin constraints
├── scripts/
│   └── bootstrap_toolchain.sh  # Install Yosys/nextpnr/IceStorm/iverilog
├── docs/
│   └── hardware_wiring.md      # BOM, circuit diagrams, field layout
└── Makefile                    # synth → pnr → pack → flash
```

---

## Quickstart

### 1. Install toolchain (once)
```bash
chmod +x scripts/bootstrap_toolchain.sh
./scripts/bootstrap_toolchain.sh
```
Installs: `yosys`, `nextpnr-ice40`, `IceStorm`, `iverilog`, `gtkwave`.

### 2. Run simulations (no hardware needed)
```bash
make sim
```
Expected output: all 9 tests `PASS`.

### 3. Synthesize and check resource usage
```bash
make synth
```
Check yosys report — design uses <1000 LUTs on UP5K (5280 available).

### 4. Flash to UPduino (USB-C connected)
```bash
make pnr && make pack && make flash
```

---

## Key Parameters

| Parameter | File | Default | Description |
|-----------|------|---------|-------------|
| `SHADOW_MODE` | `sonic_shield_board.v:40` | `0` | Set `1` for first 3 field days — listens without firing |
| `tone_val` range | `sonic_shield_top.v:50` | 333–353 | Half-period divisor → 17–18kHz |
| LFSR seed | `prng.v:21` | `0xACE1` | Any non-zero value |
| Baud rate | `uart_tx.v:28` | 115200 | 12MHz / 104 cycles per bit |

---

## Deployment Phases

| Phase | Goal | Status |
|-------|------|--------|
| 1 — Newton Bench | Logic verified in simulation | ✅ Done |
| 2 — Sentinel Prototype | Hardware assembly + power test | ⬜ Next |
| 3 — Ahero Field Test | 1-acre deployment, shadow → active | ⬜ Pending |
| 4 — Digital Ag Integration | GSM telemetry → Django dashboard | ⬜ Pending |

---

## Hardware (Master Node)

- **FPGA:** UPduino v3.x (iCE40UP5K, 12MHz internal oscillator)
- **Mic:** LM393 sound sensor module → pin 23
- **PIR:** HC-SR501 → pin 25
- **Speaker driver:** 2N2222 + 1kΩ + 1N4148 → 12V piezo tweeter
- **Wireless TX:** FS1000A 433MHz → pin 31 (17.3cm wire antenna)
- **Power:** 12V solar + 2Ah battery (3-day cloudy reserve)

Each satellite node: `XY-MK-5V receiver` + `NE555 astable ~18kHz` + `2N2222` + `12V piezo` + `1–2W solar`.

See [`docs/hardware_wiring.md`](docs/hardware_wiring.md) for full circuit diagrams and BOM.

---

## License

MIT
