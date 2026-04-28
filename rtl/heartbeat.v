// 1Hz tick generator
// 12MHz clock / 12,000,000 cycles = 1 pulse per second
// tick is high for exactly 1 clock cycle each second
module heartbeat (
    input  clk,
    input  rst_n,
    output reg tick
);
    reg [23:0] counter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 24'd0;
            tick    <= 1'b0;
        end else if (counter == 24'd11_999_999) begin
            counter <= 24'd0;
            tick    <= 1'b1;
        end else begin
            counter <= counter + 1'b1;
            tick    <= 1'b0;
        end
    end
endmodule
