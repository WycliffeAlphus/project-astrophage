// Sonic Shield — Synthesis Board Wrapper (UPduino v3.x)
//
// This file is the synthesis top-level. It instantiates two iCE40 hard macros
// that cannot be simulated with iverilog:
//
//   SB_HFOSC  — internal 12MHz oscillator (no external crystal needed)
//   SB_RGBA_DRV — LED current driver hard block
//                 Required on UPduino: the onboard RGB LED is wired to this
//                 hard macro, NOT to general-purpose GPIO pins.
//                 Driving the LED pins directly (without this block) does nothing.
//
// Do NOT instantiate this file in testbenches. Use sonic_shield_top directly.
module sonic_shield_board (
    input  rst_n,
    input  mic_in,
    input  pir_in,
    output speaker_out,
    output rf_tx,        // To FS1000A DATA pin — wireless satellite trigger
    output uart_tx,
    // UPduino onboard RGB LED — driven by SB_RGBA_DRV below
    output led_r,
    output led_g,
    output led_b
);
    wire clk;
    wire status_led; // 1Hz heartbeat signal from core

    // Internal 12MHz oscillator
    // CLKHF_DIV "0b00" = no division = 48MHz ... divided internally
    // Use SB_HFOSC with TRIM settings for 12MHz output
    SB_HFOSC #(
        .CLKHF_DIV("0b10") // 0b10 = divide by 4: 48MHz / 4 = 12MHz
    ) osc_inst (
        .CLKHFPU(1'b1),
        .CLKHFEN(1'b1),
        .CLKHF  (clk)
    );

    // Core logic
    sonic_shield_top #(
        .SHADOW_MODE(0) // Set to 1 for first 3 field days (listen-only mode)
    ) core (
        .clk        (clk),
        .rst_n      (rst_n),
        .mic_in     (mic_in),
        .pir_in     (pir_in),
        .speaker_out(speaker_out),
        .rf_tx      (rf_tx),
        .status_led (status_led),
        .uart_tx    (uart_tx)
    );

    // RGB LED driver hard macro
    // RGB0 = Red, RGB1 = Green, RGB2 = Blue
    // We blink Blue at 1Hz (heartbeat). Red and Green stay off.
    // Current setting "0b000001" = minimum current (~4mA) — enough to see
    SB_RGBA_DRV #(
        .CURRENT_MODE("0b1"),        // half-current mode
        .RGB0_CURRENT("0b000001"),   // Red: min current
        .RGB1_CURRENT("0b000001"),   // Green: min current
        .RGB2_CURRENT("0b000001")    // Blue: min current
    ) rgb_drv (
        .RGBLEDEN(1'b1),
        .RGB0PWM (1'b0),             // Red off
        .RGB1PWM (1'b0),             // Green off
        .RGB2PWM (status_led),       // Blue blinks at 1Hz heartbeat
        .CURREN  (1'b1),
        .RGB0    (led_r),
        .RGB1    (led_g),
        .RGB2    (led_b)
    );

endmodule
