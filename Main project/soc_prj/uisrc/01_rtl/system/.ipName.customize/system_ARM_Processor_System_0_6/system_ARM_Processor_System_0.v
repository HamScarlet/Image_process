/************************************************************\
**	Copyright (c) 2012-2024 Anlogic Inc.
**	All Right Reserved.
\************************************************************/
/************************************************************\
**	Build time: Oct 30 2024 09:57:58
**	TD version	:	5.9.122301
************************************************************/
`timescale 1ns/1ps
module system_ARM_Processor_System_0
(
  input                         slave_hp0_axi_aclk,
  input   [32:0]                slave_hp0_axi_araddr,
  input   [1:0]                 slave_hp0_axi_arburst,
  input   [3:0]                 slave_hp0_axi_arcache,
  input   [5:0]                 slave_hp0_axi_arid,
  input   [3:0]                 slave_hp0_axi_arlen,
  input                         slave_hp0_axi_arlock,
  input   [2:0]                 slave_hp0_axi_arprot,
  input   [3:0]                 slave_hp0_axi_arqos,
  output                        slave_hp0_axi_arready,
  input   [1:0]                 slave_hp0_axi_arsize,
  input                         slave_hp0_axi_arvalid,
  input   [32:0]                slave_hp0_axi_awaddr,
  input   [1:0]                 slave_hp0_axi_awburst,
  input   [3:0]                 slave_hp0_axi_awcache,
  input   [5:0]                 slave_hp0_axi_awid,
  input   [3:0]                 slave_hp0_axi_awlen,
  input                         slave_hp0_axi_awlock,
  input   [2:0]                 slave_hp0_axi_awprot,
  input   [3:0]                 slave_hp0_axi_awqos,
  output                        slave_hp0_axi_awready,
  input   [1:0]                 slave_hp0_axi_awsize,
  input                         slave_hp0_axi_awvalid,
  output  [5:0]                 slave_hp0_axi_bid,
  input                         slave_hp0_axi_bready,
  output  [1:0]                 slave_hp0_axi_bresp,
  output                        slave_hp0_axi_bvalid,
  output  [63:0]                slave_hp0_axi_rdata,
  output  [5:0]                 slave_hp0_axi_rid,
  output                        slave_hp0_axi_rlast,
  input                         slave_hp0_axi_rready,
  output  [1:0]                 slave_hp0_axi_rresp,
  output                        slave_hp0_axi_rvalid,
  input   [63:0]                slave_hp0_axi_wdata,
  input                         slave_hp0_axi_wlast,
  output                        slave_hp0_axi_wready,
  input   [7:0]                 slave_hp0_axi_wstrb,
  input                         slave_hp0_axi_wvalid,
  output                        p2f_rst0_n,
  output                        p2f_clk0
);

  ARM_Processor_System_59fb6a0bf2ca
  #(
      .Slave_AXI_HP0_DATA_WIDTH(64),
      .p2f_clk0_1st_Divisor(2)
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
      .p2f_rst0_n(p2f_rst0_n),
      .p2f_clk0(p2f_clk0)
  );
endmodule
