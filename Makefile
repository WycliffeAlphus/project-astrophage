# Sonic Shield — Root Makefile
# Targets: synth | pnr | pack | flash | sim | clean
#
# Flow: RTL (.v) → yosys (synth) → netlist (.json)
#                → nextpnr (place & route) → routed (.asc)
#                → icepack (bitstream) → (.bin)
#                → iceprog (flash to UPduino via USB)

BOARD    := upduino_v3
TOP      := sonic_shield_board
PCF      := pcf/$(BOARD).pcf
BUILD    := build

RTL_SRCS := rtl/sonic_shield_board.v \
            rtl/sonic_shield_top.v   \
            rtl/heartbeat.v          \
            rtl/prng.v               \
            rtl/bird_deterrent_pwm.v \
            rtl/uart_tx.v

JSON  := $(BUILD)/$(TOP).json
ASC   := $(BUILD)/$(TOP).asc
BIN   := $(BUILD)/$(TOP).bin

.PHONY: all synth pnr pack flash sim clean

all: $(BIN)

$(BUILD):
	mkdir -p $(BUILD)

# Step 1: Synthesis — convert RTL to netlist
# -top specifies the top-level module name
# Reports LUT count, DSP usage, etc.
synth: $(BUILD) $(RTL_SRCS)
	yosys -p "synth_ice40 -top $(TOP) -json $(JSON)" $(RTL_SRCS)

# Step 2: Place & Route — map netlist to UP5K SG48 package
# --up5k  = iCE40UP5K device
# --package sg48 = SG48 package used on UPduino v3
pnr: $(JSON)
	nextpnr-ice40 --up5k --package sg48 \
	              --json $(JSON)        \
	              --pcf  $(PCF)         \
	              --asc  $(ASC)

# Step 3: Pack — produce binary bitstream from routed design
pack: $(ASC)
	icepack $(ASC) $(BIN)

# Step 4: Flash — program UPduino over USB-C
# UPduino v3 uses FTDI FT232H: vendor 0x0403 product 0x6014
flash: $(BIN)
	iceprog -d i:0x0403:0x6014 $(BIN)

# Simulation — delegates to sim/Makefile
sim:
	$(MAKE) -C sim

clean:
	rm -rf $(BUILD)
	$(MAKE) -C sim clean

# Convenience shortcuts
$(JSON): synth
$(ASC):  pnr
$(BIN):  pack
