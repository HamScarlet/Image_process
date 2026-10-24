module system_axi_lite_pwm_0 
#(
    parameter C_S_AXI_ADDR_WIDTH = 9 ,
    parameter RESET_MOTOR_ARR = 32'd9998 ,
    parameter RESET_SERVO_ARR = 32'd3999599
)
(
    input             s_axi_aclk ,
    input             s_axi_aresetn ,
    input  [(C_S_AXI_ADDR_WIDTH - 1):0] s_axi_awaddr ,
    input             s_axi_awvalid ,
    output            s_axi_awready ,
    input      [31:0] s_axi_wdata ,
    input       [3:0] s_axi_wstrb ,
    input             s_axi_wvalid ,
    output            s_axi_wready ,
    output      [1:0] s_axi_bresp ,
    output            s_axi_bvalid ,
    input             s_axi_bready ,
    input  [(C_S_AXI_ADDR_WIDTH - 1):0] s_axi_araddr ,
    input             s_axi_arvalid ,
    output            s_axi_arready ,
    output     [31:0] s_axi_rdata ,
    output      [1:0] s_axi_rresp ,
    output            s_axi_rvalid ,
    input             s_axi_rready ,
    output      [2:0] pwm_out ,
    output      [1:0] motor_dir ,
    output            motor_enable
) ;

    axi_lite_pwm #(
        .C_S_AXI_ADDR_WIDTH(C_S_AXI_ADDR_WIDTH) ,
        .RESET_MOTOR_ARR(RESET_MOTOR_ARR) ,
        .RESET_SERVO_ARR(RESET_SERVO_ARR)
    ) axi_lite_pwm (
        .s_axi_aclk(s_axi_aclk) ,
        .s_axi_aresetn(s_axi_aresetn) ,
        .s_axi_awaddr(s_axi_awaddr) ,
        .s_axi_awvalid(s_axi_awvalid) ,
        .s_axi_awready(s_axi_awready) ,
        .s_axi_wdata(s_axi_wdata) ,
        .s_axi_wstrb(s_axi_wstrb) ,
        .s_axi_wvalid(s_axi_wvalid) ,
        .s_axi_wready(s_axi_wready) ,
        .s_axi_bresp(s_axi_bresp) ,
        .s_axi_bvalid(s_axi_bvalid) ,
        .s_axi_bready(s_axi_bready) ,
        .s_axi_araddr(s_axi_araddr) ,
        .s_axi_arvalid(s_axi_arvalid) ,
        .s_axi_arready(s_axi_arready) ,
        .s_axi_rdata(s_axi_rdata) ,
        .s_axi_rresp(s_axi_rresp) ,
        .s_axi_rvalid(s_axi_rvalid) ,
        .s_axi_rready(s_axi_rready) ,
        .pwm_out(pwm_out) ,
        .motor_dir(motor_dir) ,
        .motor_enable(motor_enable)
    );


endmodule
