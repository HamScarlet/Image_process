/************************************************************\
**	Copyright (c) 2012-2025 Anlogic Inc.
**	All Right Reserved.
\************************************************************/
/************************************************************\
**	Build time: May 21 2025 14:12:15
**	TD version	:	5.9.151508
************************************************************/
`timescale 1ns/1ps
module system_ARM_Processor_System_0
(
  input   [5:0]                 slave_hp0_axi_awid,
  input   [32:0]                slave_hp0_axi_awaddr,
  input   [3:0]                 slave_hp0_axi_awlen,
  input   [1:0]                 slave_hp0_axi_awsize,
  input   [1:0]                 slave_hp0_axi_awburst,
  input                         slave_hp0_axi_awlock,
  input   [3:0]                 slave_hp0_axi_awcache,
  input   [2:0]                 slave_hp0_axi_awprot,
  input                         slave_hp0_axi_awvalid,
  output                        slave_hp0_axi_awready,
  input   [63:0]                slave_hp0_axi_wdata,
  input   [7:0]                 slave_hp0_axi_wstrb,
  input                         slave_hp0_axi_wlast,
  input                         slave_hp0_axi_wvalid,
  output                        slave_hp0_axi_wready,
  output  [5:0]                 slave_hp0_axi_bid,
  output  [1:0]                 slave_hp0_axi_bresp,
  output                        slave_hp0_axi_bvalid,
  input                         slave_hp0_axi_bready,
  input   [5:0]                 slave_hp0_axi_arid,
  input   [32:0]                slave_hp0_axi_araddr,
  input   [3:0]                 slave_hp0_axi_arlen,
  input   [1:0]                 slave_hp0_axi_arsize,
  input   [1:0]                 slave_hp0_axi_arburst,
  input                         slave_hp0_axi_arlock,
  input   [3:0]                 slave_hp0_axi_arcache,
  input   [2:0]                 slave_hp0_axi_arprot,
  input                         slave_hp0_axi_arvalid,
  output                        slave_hp0_axi_arready,
  output  [5:0]                 slave_hp0_axi_rid,
  output  [63:0]                slave_hp0_axi_rdata,
  output  [1:0]                 slave_hp0_axi_rresp,
  output                        slave_hp0_axi_rlast,
  output                        slave_hp0_axi_rvalid,
  input                         slave_hp0_axi_rready,
  input   [3:0]                 slave_hp0_axi_awqos,
  input   [3:0]                 slave_hp0_axi_arqos,
  input                         slave_hp0_axi_aclk,
  output  [0:0]                 pl_gpio_oe,
  output  [0:0]                 pl_gpio_out,
  input   [0:0]                 pl_gpio_in,
  output                        p2f_clk0,
  output                        p2f_rst0_n
);

  ARM_Processor_System_59fb6a0bf2ca
  #(
      .Slave_AXI_HP0_DATA_WIDTH(64),
      .GPIO_PL_Dot_IO(1)
  )ARM_Processor_System_59fb6a0bf2ca_Inst
  (
      .slave_hp0_axi_aclk(slave_hp0_axi_aclk),
      .slave_hp0_axi_araddr(slave_hp0_axi_araddr),
      .slave_hp0_axi_arburst(slave_hp0_axi_arburst),
      .slave_hp0_axi_arcache(slave_hp0_axi_arcache),
      .slave_hp0_axi_arid(slave_hp0_axi_arid),
      .slave_hp0_axi_arlen(slave_hp0_axi_arlen),
      .slave_hp0_axi_arlock(slave_hp0_axi_arlock),
      .slave_hp0_axi_arprot(slave_hp0_axi_arprot),
      .slave_hp0_axi_arqos(slave_hp0_axi_arqos),
      .slave_hp0_axi_arready(slave_hp0_axi_arready),
      .slave_hp0_axi_arsize(slave_hp0_axi_arsize),
      .slave_hp0_axi_arvalid(slave_hp0_axi_arvalid),
      .slave_hp0_axi_awaddr(slave_hp0_axi_awaddr),
      .slave_hp0_axi_awburst(slave_hp0_axi_awburst),
      .slave_hp0_axi_awcache(slave_hp0_axi_awcache),
      .slave_hp0_axi_awid(slave_hp0_axi_awid),
      .slave_hp0_axi_awlen(slave_hp0_axi_awlen),
      .slave_hp0_axi_awlock(slave_hp0_axi_awlock),
      .slave_hp0_axi_awprot(slave_hp0_axi_awprot),
      .slave_hp0_axi_awqos(slave_hp0_axi_awqos),
      .slave_hp0_axi_awready(slave_hp0_axi_awready),
      .slave_hp0_axi_awsize(slave_hp0_axi_awsize),
      .slave_hp0_axi_awvalid(slave_hp0_axi_awvalid),
      .slave_hp0_axi_bid(slave_hp0_axi_bid),
      .slave_hp0_axi_bready(slave_hp0_axi_bready),
      .slave_hp0_axi_bresp(slave_hp0_axi_bresp),
      .slave_hp0_axi_bvalid(slave_hp0_axi_bvalid),
      .slave_hp0_axi_rdata(slave_hp0_axi_rdata),
      .slave_hp0_axi_rid(slave_hp0_axi_rid),
      .slave_hp0_axi_rlast(slave_hp0_axi_rlast),
      .slave_hp0_axi_rready(slave_hp0_axi_rready),
      .slave_hp0_axi_rresp(slave_hp0_axi_rresp),
      .slave_hp0_axi_rvalid(slave_hp0_axi_rvalid),
      .slave_hp0_axi_wdata(slave_hp0_axi_wdata),
      .slave_hp0_axi_wlast(slave_hp0_axi_wlast),
      .slave_hp0_axi_wready(slave_hp0_axi_wready),
      .slave_hp0_axi_wstrb(slave_hp0_axi_wstrb),
      .slave_hp0_axi_wvalid(slave_hp0_axi_wvalid),
      .pl_gpio_in(pl_gpio_in),
      .pl_gpio_oe(pl_gpio_oe),
      .pl_gpio_out(pl_gpio_out),
      .p2f_rst0_n(p2f_rst0_n),
      .p2f_clk0(p2f_clk0)
  );
endmodule
