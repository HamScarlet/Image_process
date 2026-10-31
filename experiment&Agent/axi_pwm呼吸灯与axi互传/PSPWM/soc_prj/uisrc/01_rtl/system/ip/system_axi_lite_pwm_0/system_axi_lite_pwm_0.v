/************************************************************\
**	Copyright (c) 2012-2026 User Inc.
**	All Right Reserved.
\************************************************************/
/************************************************************\
**	Gen time	:	Oct 29 2026 18:46:41
**	IpTool version	:	2026.03(193873 2026/03/31)
**	App version	:	Release_2026.1_SP2
**	Ip Version	:	1.0
\************************************************************/
`timescale 1ns/1ps
module system_axi_lite_pwm_0
(
  input                         s_axi_aclk,
  input                         s_axi_aresetn,
  input   [31:0]                s_axi_awaddr,
  input                         s_axi_awvalid,
  output                        s_axi_awready,
  input   [31:0]                s_axi_wdata,
  input   [3:0]                 s_axi_wstrb,
  input                         s_axi_wvalid,
  output                        s_axi_wready,
  output  [1:0]                 s_axi_bresp,
  output                        s_axi_bvalid,
  input                         s_axi_bready,
  input   [31:0]                s_axi_araddr,
  input                         s_axi_arvalid,
  output                        s_axi_arready,
  output  [31:0]                s_axi_rdata,
  output  [1:0]                 s_axi_rresp,
  output                        s_axi_rvalid,
  input                         s_axi_rready,
  output  [2:0]                 pwm_out,
  output  [1:0]                 motor_dir,
  output                        motor_enable
);

  axi_lite_pwm_system_axi_lite_pwm_0
  #(
      .C_S_AXI_ADDR_WIDTH(32),
      .RESET_MOTOR_ARR(32'd9999),
      .RESET_SERVO_ARR(32'd3999599)
  )axi_lite_pwm_Inst
  (
      .s_axi_aclk(s_axi_aclk),
      .s_axi_aresetn(s_axi_aresetn),
      .s_axi_awaddr(s_axi_awaddr),
      .s_axi_awvalid(s_axi_awvalid),
      .s_axi_awready(s_axi_awready),
      .s_axi_wdata(s_axi_wdata),
      .s_axi_wstrb(s_axi_wstrb),
      .s_axi_wvalid(s_axi_wvalid),
      .s_axi_wready(s_axi_wready),
      .s_axi_bresp(s_axi_bresp),
      .s_axi_bvalid(s_axi_bvalid),
      .s_axi_bready(s_axi_bready),
      .s_axi_araddr(s_axi_araddr),
      .s_axi_arvalid(s_axi_arvalid),
      .s_axi_arready(s_axi_arready),
      .s_axi_rdata(s_axi_rdata),
      .s_axi_rresp(s_axi_rresp),
      .s_axi_rvalid(s_axi_rvalid),
      .s_axi_rready(s_axi_rready),
      .pwm_out(pwm_out),
      .motor_dir(motor_dir),
      .motor_enable(motor_enable)
  );
endmodule
