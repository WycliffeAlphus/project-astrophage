// Sonic Shield — Core Logic Module
//
// Takes clk as an explicit input so testbenches can drive it directly.
// Synthesis wrapper (sonic_shield_board.v) provides clk from SB_HFOSC.
//
// SHADOW_MODE parameter:
//   0 = Active  — speaker fires when sensor triggers (field deployment)
//   1 = Silent  — sensors log activity but speaker stays off (first 3 days)
//
// Detection: deterrent_en = mic_in OR pir_in
//   Either sensor independently triggers the deterrent.
//
// Frequency sweep:
//   tone_val = 333 + (lfsr % 21) → sweeps 18kHz down to ~17kHz
//   Changes every 1Hz tick so birds cannot habituate to a fixed frequency.
module sonic_shield_top #(
    parameter SHADOW_MODE = 0
) (
    input  clk,
    input  rst_n,
    input  mic_in,       // High when mic comparator detects bird-frequency sound
    input  pir_in,       // High when PIR detects movement
    output speaker_out,  // PWM to transistor driver → master node piezo
    output rf_tx,        // 433MHz trigger to satellite nodes (HIGH = deterrent active)
    output status_led,   // 1Hz heartbeat — goes to SB_RGBA_DRV in board wrapper
    output uart_tx       // Serial telemetry (stub — idle high until Phase 4)
);
    wire        tick_1hz;
    wire [15:0] lfsr;
    wire [15:0] tone_val;
    wire        pwm_out;
    reg         deterrent_en;
    reg         blink;

    // --- Heartbeat: 1Hz tick drives all 1-second state changes ---
    heartbeat hb_inst (
        .clk   (clk),
        .rst_n (rst_n),
        .tick  (tick_1hz)
    );

    // --- PRNG: advances 1 step per second, produces jitter for tone_val ---
    prng prng_inst (
        .clk      (clk),
        .rst_n    (rst_n),
        .advance  (tick_1hz),
        .lfsr_out (lfsr)
    );

    // tone_val sweeps 333–353 (18kHz to ~17kHz ceiling, safe for neighbors)
    // lfsr % 21 maps 16-bit value to 0–20 range
    assign tone_val = 16'd333 + (lfsr % 16'd21);

    // --- Blink toggle: flips each 1Hz tick → 0.5s ON / 0.5s OFF ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) blink <= 1'b0;
        else if (tick_1hz) blink <= ~blink;
    end

    // --- Detection: either sensor fires the deterrent ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            deterrent_en <= 1'b0;
        else
            deterrent_en <= mic_in | pir_in;
    end

    // --- PWM generator ---
    bird_deterrent_pwm pwm_inst (
        .clk        (clk),
        .tone_val   (tone_val),
        .enable     (deterrent_en),
        .speaker_out(pwm_out)
    );

    // SHADOW_MODE gates both the local speaker and the RF trigger
    assign speaker_out = (SHADOW_MODE == 1) ? 1'b0 : pwm_out;

    // rf_tx: sends a simple HIGH/LOW trigger to 433MHz transmitter (FS1000A DATA pin)
    // Satellite nodes receive this, gate their local 555-timer oscillator → piezo
    // We send deterrent_en (not the PWM) — 433MHz modules can't carry 18kHz OOK
    assign rf_tx = (SHADOW_MODE == 1) ? 1'b0 : deterrent_en;

    // Blink toggle drives LED at 0.5Hz duty cycle (visible 1Hz blink)
    assign status_led = blink;

    // UART idle high — Phase 4 will replace this with real telemetry
    assign uart_tx = 1'b1;

endmodule
