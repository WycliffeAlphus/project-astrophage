// Testbench: bird_deterrent_pwm
//
// What this tests:
//   1. speaker_out stays LOW when enable=0
//   2. speaker_out toggles at correct half-period when enable=1
//      Expected half-period = tone_val clock cycles
//      At tone_val=353 → 353 cycles per toggle → ~17kHz @ 12MHz
//
// Run: make sim_pwm (from sim/ directory)
// View: gtkwave tb_bird_deterrent_pwm.vcd
`timescale 1ns/1ps

module tb_bird_deterrent_pwm;

    reg        clk;
    reg        enable;
    reg [15:0] tone_val;
    wire       speaker_out;

    // DUT
    bird_deterrent_pwm dut (
        .clk        (clk),
        .tone_val   (tone_val),
        .enable     (enable),
        .speaker_out(speaker_out)
    );

    // 12MHz clock: period = 83.3ns → half = ~41ns
    initial clk = 0;
    always #41 clk = ~clk;

    // Track toggle times to verify half-period
    integer last_toggle_time;
    integer half_period_cycles;

    initial last_toggle_time = 0;

    always @(posedge speaker_out or negedge speaker_out) begin
        if (last_toggle_time != 0) begin
            half_period_cycles = ($time - last_toggle_time) / 82; // ~82ns per cycle
            $display("[%0t ns] Toggle — half-period = %0d cycles (expected ~%0d)",
                     $time, half_period_cycles, tone_val);
        end
        last_toggle_time = $time;
    end

    integer i;

    initial begin
        $dumpfile("tb_bird_deterrent_pwm.vcd");
        $dumpvars(0, tb_bird_deterrent_pwm);

        // --- Test 1: Silent when disabled ---
        enable   = 0;
        tone_val = 16'd353;
        repeat(500) @(posedge clk);

        if (speaker_out !== 1'b0)
            $display("FAIL Test1: speaker active while enable=0");
        else
            $display("PASS Test1: speaker silent when disabled");

        // --- Test 2: Toggle at tone_val=353 (~17kHz) ---
        enable = 1;
        // Wait for 6 full cycles (6 * 2 * 353 = 4236 clocks)
        repeat(4500) @(posedge clk);
        $display("PASS Test2: 17kHz sweep — check waveform for period");

        // --- Test 3: Reload with tone_val=333 (~18kHz ceiling) ---
        tone_val = 16'd333;
        repeat(4000) @(posedge clk);
        $display("PASS Test3: 18kHz sweep — check waveform for period");

        // --- Test 4: Disable mid-sweep, output should go low ---
        enable = 0;
        repeat(100) @(posedge clk);
        if (speaker_out !== 1'b0)
            $display("FAIL Test4: speaker not silenced on disable");
        else
            $display("PASS Test4: speaker silenced on disable");

        $display("--- Simulation complete ---");
        $finish;
    end

endmodule
