/************************************************************\
**	Copyright (c) 2012-2024 Anlogic Inc.
**	All Right Reserved.
\************************************************************/
/************************************************************\
**	Build time: Dec 03 2024 15:20:00
**	TD version	:	5.9.135718
************************************************************/
`timescale 1ns/1ps
module system_ARM_Processor_System_1
(
  input                         master_gp0_axi_aclk,
  output  [32:0]                master_gp0_axi_araddr,
  output  [1:0]                 master_gp0_axi_arburst,
  output  [3:0]                 master_gp0_axi_arcache,
  output  [11:0]                master_gp0_axi_arid,
  output  [3:0]                 master_gp0_axi_arlen,
  output                        master_gp0_axi_arlock,
  output  [2:0]                 master_gp0_axi_arprot,
  input                         master_gp0_axi_arready,
  output  [1:0]                 master_gp0_axi_arsize,
  output                        master_gp0_axi_arvalid,
  output  [32:0]                master_gp0_axi_awaddr,
  output  [1:0]                 master_gp0_axi_awburst,
  output  [3:0]                 master_gp0_axi_awcache,
  output  [11:0]                master_gp0_axi_awid,
  output  [3:0]                 master_gp0_axi_awlen,
  output                        master_gp0_axi_awlock,
  output  [2:0]                 master_gp0_axi_awprot,
  input                         master_gp0_axi_awready,
  output  [1:0]                 master_gp0_axi_awsize,
  output                        master_gp0_axi_awvalid,
  input   [11:0]                master_gp0_axi_bid,
  output                        master_gp0_axi_bready,
  input   [1:0]                 master_gp0_axi_bresp,
  input                         master_gp0_axi_bvalid,
  input   [31:0]                master_gp0_axi_rdata,
  input   [11:0]                master_gp0_axi_rid,
  input                         master_gp0_axi_rlast,
  output                        master_gp0_axi_rready,
  input   [1:0]                 master_gp0_axi_rresp,
  input                         master_gp0_axi_rvalid,
  output  [31:0]                master_gp0_axi_wdata,
  output                        master_gp0_axi_wlast,
  input                         master_gp0_axi_wready,
  output  [3:0]                 master_gp0_axi_wstrb,
  output                        master_gp0_axi_wvalid,
  input   [15:0]                f2p_irq,
  output                        p2f_rst0_n,
  output                        p2f_clk0
);

  ARM_Processor_System_644123ab1028
  #(
      .p2f_clk0_1st_Divisor(8)
  )ARM_Processor_System_644123ab1028_Inst
  (
      .master_gp0_axi_aclk(master_gp0_axi_aclk),
      .master_gp0_axi_araddr(master_gp0_axi_araddr),
      .master_gp0_axi_arburst(master_gp0_axi_arburst),
      .master_gp0_axi_arcache(master_gp0_axi_arcache),
      .master_gp0_axi_arid(master_gp0_axi_arid),
      .master_gp0_axi_arlen(master_gp0_axi_arlen),
      .master_gp0_axi_arlock(master_gp0_axi_arlock),
      .master_gp0_axi_arprot(master_gp0_axi_arprot),
      .master_gp0_axi_arready(master_gp0_axi_arready),
      .master_gp0_axi_arsize(master_gp0_axi_arsize),
      .master_gp0_axi_arvalid(master_gp0_axi_arvalid),
      .master_gp0_axi_awaddr(master_gp0_axi_awaddr),
      .master_gp0_axi_awburst(master_gp0_axi_awburst),
      .master_gp0_axi_awcache(master_gp0_axi_awcache),
      .master_gp0_axi_awid(master_gp0_axi_awid),
      .master_gp0_axi_awlen(master_gp0_axi_awlen),
      .master_gp0_axi_awlock(master_gp0_axi_awlock),
      .master_gp0_axi_awprot(master_gp0_axi_awprot),
      .master_gp0_axi_awready(master_gp0_axi_awready),
      .master_gp0_axi_awsize(master_gp0_axi_awsize),
      .master_gp0_axi_awvalid(master_gp0_axi_awvalid),
      .master_gp0_axi_bid(master_gp0_axi_bid),
      .master_gp0_axi_bready(master_gp0_axi_bready),
      .master_gp0_axi_bresp(master_gp0_axi_bresp),
      .master_gp0_axi_bvalid(master_gp0_axi_bvalid),
      .master_gp0_axi_rdata(master_gp0_axi_rdata),
      .master_gp0_axi_rid(master_gp0_axi_rid),
      .master_gp0_axi_rlast(master_gp0_axi_rlast),
      .master_gp0_axi_rready(master_gp0_axi_rready),
      .master_gp0_axi_rresp(master_gp0_axi_rresp),
      .master_gp0_axi_rvalid(master_gp0_axi_rvalid),
      .master_gp0_axi_wdata(master_gp0_axi_wdata),
      .master_gp0_axi_wlast(master_gp0_axi_wlast),
      .master_gp0_axi_wready(master_gp0_axi_wready),
      .master_gp0_axi_wstrb(master_gp0_axi_wstrb),
      .master_gp0_axi_wvalid(master_gp0_axi_wvalid),
      .f2p_irq(f2p_irq),
      .p2f_rst0_n(p2f_rst0_n),
      .p2f_clk0(p2f_clk0)
  );
endmodule
