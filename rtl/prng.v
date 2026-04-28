// 16-bit Fibonacci LFSR pseudo-random number generator
// Polynomial: x^16 + x^14 + x^13 + x^11 + 1
// Feedback taps: bits 15, 13, 12, 10 (0-indexed from LSB)
// Advances by 1 step each time 'advance' is pulsed (tied to 1Hz tick)
// Used to jitter the deterrent frequency so birds don't habituate
module prng (
    input  clk,
    input  rst_n,
    input  advance,
    output [15:0] lfsr_out
);
    reg [15:0] lfsr;

    // XOR feedback from taps
    wire feedback = lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            lfsr <= 16'hACE1; // non-zero seed — any non-zero value works
        else if (advance)
            lfsr <= {lfsr[14:0], feedback};
    end

    assign lfsr_out = lfsr;
endmodule
