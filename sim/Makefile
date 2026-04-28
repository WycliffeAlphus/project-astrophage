# Simulation Makefile
# Tools: iverilog (compile), vvp (run), gtkwave (view waveforms)
#
# Targets:
#   make sim      — run all testbenches
#   make sim_pwm  — run PWM testbench + open GTKWave
#   make sim_top  — run top-level testbench + open GTKWave
#   make clean    — remove build artifacts

RTL_DIR  := ../rtl
IFLAGS   := -I$(RTL_DIR)

.PHONY: sim sim_pwm sim_top clean

sim: sim_pwm sim_top

# --- PWM testbench ---
sim_pwm: tb_bird_deterrent_pwm.vvp
	vvp tb_bird_deterrent_pwm.vvp
	@if command -v gtkwave >/dev/null 2>&1; then \
	    gtkwave tb_bird_deterrent_pwm.vcd & \
	else \
	    echo "gtkwave not found — open tb_bird_deterrent_pwm.vcd manually"; \
	fi

tb_bird_deterrent_pwm.vvp: tb_bird_deterrent_pwm.v \
                            $(RTL_DIR)/bird_deterrent_pwm.v
	iverilog $(IFLAGS) -o $@ $^

# --- Top-level testbench ---
# All RTL sources needed because sonic_shield_top instantiates submodules
sim_top: tb_sonic_shield_top.vvp
	vvp tb_sonic_shield_top.vvp
	@if command -v gtkwave >/dev/null 2>&1; then \
	    gtkwave tb_sonic_shield_top.vcd & \
	else \
	    echo "gtkwave not found — open tb_sonic_shield_top.vcd manually"; \
	fi

tb_sonic_shield_top.vvp: tb_sonic_shield_top.v              \
                         $(RTL_DIR)/sonic_shield_top.v       \
                         $(RTL_DIR)/heartbeat.v              \
                         $(RTL_DIR)/prng.v                   \
                         $(RTL_DIR)/bird_deterrent_pwm.v     \
                         $(RTL_DIR)/uart_tx.v
	iverilog $(IFLAGS) -o $@ $^

clean:
	rm -f *.vvp *.vcd
