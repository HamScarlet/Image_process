`timescale 1ns/1ps


module PWM #(
    parameter PRESCALER = 0
)
( 
    input clk,
    input rst_n,
    output pwm_out,
    input [31:0] DUTY_VALUE,
    input [31:0] RELOAD_VALUE
);

reg [4:0] prescaler_cnt;
reg [31:0] cnt;
reg pwm_state;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) prescaler_cnt <= 0;
    else 
    if(prescaler_cnt <= PRESCALER + 1) prescaler_cnt = prescaler_cnt + 1;
    else prescaler_cnt <= 0;
end

always@(posedge clk or negedge rst_n) begin
    if(!rst_n) cnt <= 0;
    else begin
        if(prescaler_cnt == PRESCALER + 1) cnt <= cnt + 1;
        if(cnt <= DUTY_VALUE) pwm_state <= 1;
        else if(cnt <= RELOAD_VALUE) pwm_state <= 0;
        else cnt <= 0;
    end
end

assign pwm_out = pwm_state;

endmodule
