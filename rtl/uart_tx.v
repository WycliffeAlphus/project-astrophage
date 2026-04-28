// Minimal 8N1 UART transmitter — 115200 baud at 12MHz
// Baud divisor: 12,000,000 / 115,200 ≈ 104 cycles per bit
//
// Frame layout (10 bits total):
//   [0]     = start bit (logic 0)
//   [1..8]  = data bits, LSB first
//   [9]     = stop bit (logic 1)
//
// Usage:
//   Assert send=1 with data_in valid for 1 cycle.
//   busy goes high for the duration of transmission (~87µs).
//   Do not assert send again while busy=1.
//
// Phase 4 note: this module will carry telemetry JSON to the GSM module.
// Currently the top-level ties uart_tx output to 1'b1 (idle).
module uart_tx (
    input        clk,
    input        rst_n,
    input  [7:0] data_in,
    input        send,
    output reg   tx,
    output reg   busy
);
    localparam BAUD_DIV = 7'd104;

    reg [9:0] frame;    // {stop(1), data[7:0], start(0)}
    reg [3:0] bit_idx;
    reg [6:0] baud_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx       <= 1'b1;     // idle high
            busy     <= 1'b0;
            bit_idx  <= 4'd0;
            baud_cnt <= 7'd0;
            frame    <= 10'h3FF;
        end else if (!busy && send) begin
            // Load frame: stop=1, data, start=0
            frame    <= {1'b1, data_in, 1'b0};
            bit_idx  <= 4'd0;
            baud_cnt <= BAUD_DIV - 1'b1;
            busy     <= 1'b1;
            tx       <= 1'b0; // start bit immediately
        end else if (busy) begin
            if (baud_cnt == 7'd0) begin
                baud_cnt <= BAUD_DIV - 1'b1;
                if (bit_idx == 4'd9) begin
                    // Stop bit just finished
                    busy <= 1'b0;
                    tx   <= 1'b1; // return to idle
                end else begin
                    bit_idx <= bit_idx + 1'b1;
                    tx      <= frame[bit_idx + 1'b1];
                end
            end else begin
                baud_cnt <= baud_cnt - 1'b1;
            end
        end
    end
endmodule
