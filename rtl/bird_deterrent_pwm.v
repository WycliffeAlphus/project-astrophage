// Ultrasonic PWM generator for bird deterrence
//
// tone_val is a half-period divisor:
//   tone_val = 333 → half-period = 333 cycles @ 12MHz → full period = 666 → ~18kHz (max, safe ceiling)
//   tone_val = 353 → half-period = 353 cycles @ 12MHz → full period = 706 → ~17kHz (min)
//
// When enable=0, speaker_out is held low (silent).
// When enable=1, speaker_out toggles at the rate set by tone_val.
module bird_deterrent_pwm (
    input            clk,
    input  [15:0]    tone_val,
    input            enable,
    output reg       speaker_out
);
    reg [15:0] counter;

    always @(posedge clk) begin
        if (!enable) begin
            counter     <= 16'd0;
            speaker_out <= 1'b0;
        end else begin
            if (counter == 16'd0) begin
                counter     <= tone_val;   // reload
                speaker_out <= ~speaker_out; // toggle = one half-cycle done
            end else begin
                counter <= counter - 1'b1;
            end
        end
    end
endmodule
