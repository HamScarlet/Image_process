/************************************************************\
**	Copyright (c) 2012-2024 Anlogic Inc.
**	All Right Reserved.\
\************************************************************/
/************************************************************\
**	Build time: Jun 29 2024 14:56:59
**	TD version	:	5.9.112584
\************************************************************/
`timescale 1ns/1ps
module system_AXI_GPIO_0_0
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
  inout   [1:0]                 GPIO
);

  axi_gpio_top_6ece4e9912c4
  #(
      .AL_AXIS_ADDR_WD(32),
      .AL_AXIS_DATA_WD(32),
      .AL_GPIO_WD(2),
      .AL_GPIO2_WD(32),
      .AL_RESET_DOUT(0),
      .AL_RESET_TRI(0),
      .AL_RESET_DOUT_2(0),
      .AL_RESET_TRI_2(0)
  )axi_gpio_top_6ece4e9912c4_Inst
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
      .GPIO(GPIO)
  );
endmodule
