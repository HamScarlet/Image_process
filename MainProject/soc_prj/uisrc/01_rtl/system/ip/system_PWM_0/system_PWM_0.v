module system_PWM_0 
#(
    parameter PRESCALER = 0
)
(
    input             clk ,
    input             rst_n ,
    output            pwm_out ,
    input      [31:0] DUTY_VALUE ,
    input      [31:0] RELOAD_VALUE
) ;

    PWM #(
        .PRESCALER(PRESCALER)
    ) PWM (
        .clk(clk) ,
        .rst_n(rst_n) ,
        .pwm_out(pwm_out) ,
        .DUTY_VALUE(DUTY_VALUE) ,
        .RELOAD_VALUE(RELOAD_VALUE)
    );


endmodule
