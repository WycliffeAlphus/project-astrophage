// Testbench: sonic_shield_top
//
// What this tests:
//   1. speaker_out silent when both sensors idle
//   2. speaker_out active when mic_in=1 (acoustic trigger)
//   3. speaker_out active when pir_in=1 (motion trigger)
//   4. SHADOW_MODE=1 blocks speaker even when sensors fire
//
// We instantiate sonic_shield_top directly (not the board wrapper)
// so we can drive clk ourselves — no SB_HFOSC needed in simulation.
//
// Run: make sim_top (from sim/ directory)
// View: gtkwave tb_sonic_shield_top.vcd
`timescale 1ns/1ps

module tb_sonic_shield_top;

    reg  clk;
    reg  rst_n;
    reg  mic_in;
    reg  pir_in;
    wire speaker_out;
    wire status_led;
    wire uart_tx_wire;

    // 12MHz: ~83ns period
    initial clk = 0;
    always #41 clk = ~clk;

    // --- DUT: Active mode (SHADOW_MODE=0) ---
    sonic_shield_top #(.SHADOW_MODE(0)) dut_active (
        .clk        (clk),
        .rst_n      (rst_n),
        .mic_in     (mic_in),
        .pir_in     (pir_in),
        .speaker_out(speaker_out),
        .status_led (status_led),
        .uart_tx    (uart_tx_wire)
    );

    // --- Shadow mode DUT wired to separate outputs ---
    wire shadow_speaker;
    wire shadow_led;
    wire shadow_uart;

    sonic_shield_top #(.SHADOW_MODE(1)) dut_shadow (
        .clk        (clk),
        .rst_n      (rst_n),
        .mic_in     (mic_in),
        .pir_in     (pir_in),
        .speaker_out(shadow_speaker),
        .status_led (shadow_led),
        .uart_tx    (shadow_uart)
    );

    // Helper task: wait N cycles then sample
    task wait_cycles;
        input integer n;
        repeat(n) @(posedge clk);
    endtask

    integer saw_toggle;

    initial begin
        $dumpfile("tb_sonic_shield_top.vcd");
        $dumpvars(0, tb_sonic_shield_top);

        // Reset
        rst_n  = 0;
        mic_in = 0;
        pir_in = 0;
        wait_cycles(10);
        rst_n = 1;
        wait_cycles(5);

        // --- Test 1: Both sensors idle — speaker must be silent ---
        wait_cycles(1000);
        if (speaker_out !== 1'b0)
            $display("FAIL Test1: speaker active with no sensor input");
        else
            $display("PASS Test1: speaker silent — no sensors triggered");

        // --- Test 2: mic_in trigger — speaker must activate ---
        mic_in = 1;
        wait_cycles(800); // deterrent_en registers after 1 clock, PWM starts
        saw_toggle = 0;

        // Sample speaker_out for 1000 cycles and check it toggles
        begin : check_pwm
            integer k;
            for (k = 0; k < 1000; k = k + 1) begin
                @(posedge clk);
                if (speaker_out === 1'b1) saw_toggle = 1;
            end
        end

        if (!saw_toggle)
            $display("FAIL Test2: speaker never went high on mic_in trigger");
        else
            $display("PASS Test2: speaker active on mic_in trigger");

        mic_in = 0;
        wait_cycles(10);

        // --- Test 3: pir_in trigger ---
        pir_in = 1;
        wait_cycles(800);
        saw_toggle = 0;

        begin : check_pir
            integer j;
            for (j = 0; j < 1000; j = j + 1) begin
                @(posedge clk);
                if (speaker_out === 1'b1) saw_toggle = 1;
            end
        end

        if (!saw_toggle)
            $display("FAIL Test3: speaker never went high on pir_in trigger");
        else
            $display("PASS Test3: speaker active on pir_in trigger");

        pir_in = 0;
        wait_cycles(10);

        // --- Test 4: SHADOW_MODE=1 blocks speaker ---
        mic_in = 1;
        wait_cycles(800);

        if (shadow_speaker !== 1'b0)
            $display("FAIL Test4: SHADOW_MODE did not block speaker output");
        else
            $display("PASS Test4: SHADOW_MODE correctly silences speaker");

        mic_in = 0;

        // --- Test 5: UART TX stays idle high ---
        if (uart_tx_wire !== 1'b1)
            $display("FAIL Test5: UART TX not idle high");
        else
            $display("PASS Test5: UART TX idle high (stub)");

        $display("--- Simulation complete ---");
        $finish;
    end

endmodule
