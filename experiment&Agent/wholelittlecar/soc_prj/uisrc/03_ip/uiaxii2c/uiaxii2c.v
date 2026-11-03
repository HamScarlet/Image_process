`timescale 1ns / 1ps
/*******************************MILIANKE*******************************
*Company : MiLianKe Electronic Technology Co., Ltd.
*WebSite:https://www.milianke.com
*TechWeb:https://www.uisrc.com
*tmall-shop:https://milianke.tmall.com
*jd-shop:https://milianke.jd.com
*taobao-shop: https://milianke.taobao.com
*Create Date: 2022/09/25
*Module Name:
*File Name:
*Description: 
*The reference demo provided by Milianke is only used for learning. 
*We cannot ensure that the demo itself is free of bugs, so users 
*should be responsible for the technical problems and consequences
*caused by the use of their own products.
*Copyright: Copyright (c) MiLianKe
*All rights reserved.
*Revision: 3.1
*Signal description
*1) _i input
*2) _o output
*3) _n activ low
*4) _dg debug signal 
*5) _r delay or register
*6) _s state mechine
*********************************************************************/

module uiaxii2c#
(
parameter integer SYSCLK_FREQ = 100000000,
parameter integer I2C_FREQ  = 100000,
parameter integer WMEN_LEN = 12,
parameter integer RMEN_LEN = 12
)
(
output wire                     O_scl,      //I2C总线，SCL时钟
inout  wire                     IO_sda,     //I2C总线，SDA数据
output wire                     O_I2c_irq,  //中断输出
//AXI-LITE接口总线信号
input  wire                     S_AXI_ACLK,
input  wire                     S_AXI_ARESETN,
input  wire [3 : 0]             S_AXI_AWADDR,
input  wire [2 : 0]             S_AXI_AWPROT,
input  wire                     S_AXI_AWVALID,
output wire                     S_AXI_AWREADY,
input  wire [31 : 0]            S_AXI_WDATA,  
input  wire [3  : 0]            S_AXI_WSTRB,
input  wire                     S_AXI_WVALID,
output wire                     S_AXI_WREADY,
output wire [1 : 0]             S_AXI_BRESP,
output wire                     S_AXI_BVALID,
input  wire                     S_AXI_BREADY,
input  wire [3 : 0]             S_AXI_ARADDR,
input  wire [2 : 0]             S_AXI_ARPROT,
input  wire                     S_AXI_ARVALID,
output wire                     S_AXI_ARREADY,
output wire [31 : 0]            S_AXI_RDATA,
output wire [1  : 0]            S_AXI_RRESP,
output wire                     S_AXI_RVALID,
input  wire                     S_AXI_RREADY
);



// AXI4LITE signals
(*mark_debug = "true"*) (* KEEP = "TRUE" *) reg [3 : 0]	     axi_awaddr;
reg  	         axi_awready;
reg  	         axi_wready;
reg [1 : 0] 	 axi_bresp;
reg  	         axi_bvalid;
reg [3 : 0]	 	 axi_araddr;
reg  	         axi_arready;
reg [31: 0] 	 axi_rdata;
reg [1 : 0] 	 axi_rresp;
reg  	         axi_rvalid;

// Example-specific design signals
// local parameter for addressing 32 bit / 64 bit C_S_AXI_DATA_WIDTH
// ADDR_LSB is used for addressing 32/64 bit registers/memories
// ADDR_LSB = 2 for 32 bits (n downto 2)
// ADDR_LSB = 3 for 64 bits (n downto 3)
localparam integer ADDR_LSB = 2;
localparam integer OPT_MEM_ADDR_BITS = 1;
//----------------------------------------------
//-- Signals for user logic register space example
//------------------------------------------------
//-- Number of Slave Registers 4

reg [127:0]	slv_reg;

 wire	 slv_reg_rden;

 wire	 slv_reg_wren;

 reg [31:0]	 reg_data_out;
reg	 aw_en;

// I/O Connections assignments

assign S_AXI_AWREADY	= axi_awready;
assign S_AXI_WREADY	= axi_wready;
assign S_AXI_BRESP	= axi_bresp;
assign S_AXI_BVALID	= axi_bvalid;
assign S_AXI_ARREADY = axi_arready;
assign S_AXI_RDATA	= axi_rdata;
assign S_AXI_RRESP	= axi_rresp;
assign S_AXI_RVALID	= axi_rvalid;
// Implement axi_awready generation
// axi_awready is asserted for one S_AXI_ACLK clock cycle when both
// S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_awready is
// de-asserted when reset is low.

always @( posedge S_AXI_ACLK )
begin
	if ( S_AXI_ARESETN == 1'b0 )
	begin
		axi_awready <= 1'b0;
		aw_en <= 1'b1;
	end 
	else
	begin    
		if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en)
		begin
			// slave is ready to accept write address when 
			// there is a valid write address and write data
			// on the write address and data bus. This design 
			// expects no outstanding transactions. 
			axi_awready <= 1'b1;
			aw_en <= 1'b0;
		end
		else if (S_AXI_BREADY && axi_bvalid)
			begin
				aw_en <= 1'b1;
				axi_awready <= 1'b0;
			end
		else           
		begin
			axi_awready <= 1'b0;
		end
	end 
end       

// Implement axi_awaddr latching
// This process is used to latch the address when both 
// S_AXI_AWVALID and S_AXI_WVALID are valid. 

always @( posedge S_AXI_ACLK )
begin
	if ( S_AXI_ARESETN == 1'b0 )
	begin
		axi_awaddr <= 0;
	end 
	else
	begin    
		if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en)
		begin
			// Write Address latching 
			axi_awaddr <= S_AXI_AWADDR;
		end
	end 
end       

// Implement axi_wready generation
// axi_wready is asserted for one S_AXI_ACLK clock cycle when both
// S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_wready is 
// de-asserted when reset is low. 

always @( posedge S_AXI_ACLK )
begin
	if ( S_AXI_ARESETN == 1'b0 )
	begin
		axi_wready <= 1'b0;
	end 
	else
	begin    
		if (~axi_wready && S_AXI_WVALID && S_AXI_AWVALID && aw_en )
		begin
			// slave is ready to accept write data when 
			// there is a valid write address and write data
			// on the write address and data bus. This design 
			// expects no outstanding transactions. 
			axi_wready <= 1'b1;
		end
		else
		begin
			axi_wready <= 1'b0;
		end
	end 
end       

assign slv_reg_wren = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID;

(*mark_debug = "true"*) (* KEEP = "TRUE" *) reg clrl_reg_en;

(*mark_debug = "true"*) (* KEEP = "TRUE" *) wire i2c_busy;

always @( posedge S_AXI_ACLK )
begin
	if ( S_AXI_ARESETN == 1'b0 )begin
		slv_reg <= 0;
		clrl_reg_en <= 1'b0;
	end 
	else if(slv_reg_wren)begin 
		slv_reg[axi_awaddr[3:2]*32 +: 32] <= S_AXI_WDATA;//8*3 max 32bytes 
		clrl_reg_en <= (axi_awaddr[3:2]==2'b11) ? 1'b1 : 0; //寄存器为0~3 其中0~2为数据，3为控制信号，当总线写出现这个地址代表了使能   
	end 
	else if(clrl_reg_en&(~i2c_busy))begin
		slv_reg <= 0;
		clrl_reg_en <= 0;
	end
	else begin
		slv_reg <= slv_reg;
		clrl_reg_en <= clrl_reg_en;
	end   
end    

//[31 : 0]//data 包含地址
//[63 :32]//data
//[95 :64]//data
//[127:96]//控制 其中底4bit为写数据长度，高4bit为读数据长度

 reg [7:0] i2c_wcnt;
 reg [7:0] i2c_rcnt;
 reg i2c_req;
reg [95:0] i2c_wdata;
always @( posedge S_AXI_ACLK )
begin
	if ( S_AXI_ARESETN == 1'b0 )begin
		i2c_wdata <= 0;
		i2c_wcnt  <= 0;
		i2c_rcnt  <= 0;
		i2c_req   <= 0;
	end
	else if(clrl_reg_en & (~i2c_busy)) begin
			i2c_wdata[95:0] <= slv_reg[95:0];//有效数据
			i2c_wcnt [7 : 0] <= {4'd0,slv_reg[99:96]};  //写数据长度,包含器件地址
			i2c_rcnt [7 : 0] <= {4'd0,slv_reg[103:100]};//读数据长度
			i2c_req  <= 1'b1;
	end
	else if(i2c_req & i2c_busy)begin //等在总线忙
			i2c_wdata <= i2c_wdata;
			i2c_req  <= 1'b0;
	end
end
// Implement write response logic generation
// The write response and response valid signals are asserted by the slave 
// when axi_wready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted.  
// This marks the acceptance of address and indicates the status of 
// write transaction.

always @( posedge S_AXI_ACLK )
begin
	if ( S_AXI_ARESETN == 1'b0 )
	begin
		axi_bvalid  <= 0;
		axi_bresp   <= 2'b0;
	end 
	else
	begin    
		if (axi_awready && S_AXI_AWVALID && ~axi_bvalid && axi_wready && S_AXI_WVALID)
		begin
			// indicates a valid write response is available
			axi_bvalid <= 1'b1;
			axi_bresp  <= 2'b0; // 'OKAY' response 
		end                   // work error responses in future
		else
		begin
			if (S_AXI_BREADY && axi_bvalid) 
			//check if bready is asserted while bvalid is high) 
			//(there is a possibility that bready is always asserted high)   
			begin
				axi_bvalid <= 1'b0; 
			end  
		end
	end
end   

// Implement axi_arready generation
// axi_arready is asserted for one S_AXI_ACLK clock cycle when
// S_AXI_ARVALID is asserted. axi_awready is 
// de-asserted when reset (active low) is asserted. 
// The read address is also latched when S_AXI_ARVALID is 
// asserted. axi_araddr is reset to zero on reset assertion.

always @( posedge S_AXI_ACLK )
begin
	if ( S_AXI_ARESETN == 1'b0 )
	begin
		axi_arready <= 1'b0;
		axi_araddr  <= 32'b0;
	end 
	else
	begin    
		if (~axi_arready && S_AXI_ARVALID)
		begin
			// indicates that the slave has acceped the valid read address
			axi_arready <= 1'b1;
			// Read address latching
			axi_araddr  <= S_AXI_ARADDR;
		end
		else
		begin
			axi_arready <= 1'b0;
		end
	end 
end       

// Implement axi_arvalid generation
// axi_rvalid is asserted for one S_AXI_ACLK clock cycle when both 
// S_AXI_ARVALID and axi_arready are asserted. The slave registers 
// data are available on the axi_rdata bus at this instance. The 
// assertion of axi_rvalid marks the validity of read data on the 
// bus and axi_rresp indicates the status of read transaction.axi_rvalid 
// is deasserted on reset (active low). axi_rresp and axi_rdata are 
// cleared to zero on reset (active low).  
always @( posedge S_AXI_ACLK )
begin
	if ( S_AXI_ARESETN == 1'b0 )
	begin
		axi_rvalid <= 0;
		axi_rresp  <= 0;
	end 
	else
	begin    
		if (axi_arready && S_AXI_ARVALID && ~axi_rvalid)
		begin
			// Valid read data is available at the read data bus
			axi_rvalid <= 1'b1;
			axi_rresp  <= 2'b0; // 'OKAY' response
		end   
		else if (axi_rvalid && S_AXI_RREADY)
		begin
			// Read data is accepted by the master
			axi_rvalid <= 1'b0;
		end                
	end
end    

//用户寄存器代表部分
wire[95:0]i2c_rdata;
wire[127:0]rdata ={{32'd0,O_iic_bus_error,i2c_busy},i2c_rdata};
// Implement memory mapped register select and read logic generation
// Slave register read enable is asserted when valid address is available
// and the slave is ready to accept the read address.
assign slv_reg_rden = axi_arready & S_AXI_ARVALID & ~axi_rvalid;
always @(*)
	reg_data_out[31:0] = rdata[axi_araddr[3:2]*32 +: 32];

		
// Output register or memory read data
always @( posedge S_AXI_ACLK )
begin
	if ( S_AXI_ARESETN == 1'b0 )
	begin
		axi_rdata  <= 0;
	end 
	else
	begin    
		// When there is a valid read address (S_AXI_ARVALID) with 
		// acceptance of read address by the slave (axi_arready), 
		// output the read dada 
		if (slv_reg_rden) begin
			axi_rdata <= reg_data_out;     // register read data
		end   
	end
end    


reg [5:0] irq_dlycnt;

// Output interrupt plus time
always @( posedge S_AXI_ACLK )
begin
	if ( S_AXI_ARESETN == 1'b0 )
	begin
		irq_dlycnt  <= 0;
	end 
	else
	begin    
		if(O_cfg_done)
			irq_dlycnt <= 20;
		else if(irq_dlycnt != 0)
			irq_dlycnt <= irq_dlycnt - 1'b1;
	end
end    

assign O_I2c_irq = (irq_dlycnt != 0);


uii2c_ctrl# 
(
.CLK_DIV (SYSCLK_FREQ/I2C_FREQ-1),
.WMEN_LEN(WMEN_LEN),
.RMEN_LEN(RMEN_LEN)
)
uii2c_ctrl_inst
(
.I_clk(S_AXI_ACLK),      //系统时钟输入
.I_rst_n(S_AXI_ARESETN),    //系统复位输入

.O_scl(O_scl),      //I2C总线，SCL时钟
.IO_sda(IO_sda),     //I2C总线，SDA数据
.I_req(i2c_req),     //I2C总线操作请求
.I_wcnt(i2c_wcnt),     //设置写入有效数据长度，包含寄存器地址，不含1byte的器件地址
.I_wdata(i2c_wdata),    //写数据寄存器，包含了器件地址和有效的数据
.I_rcnt(i2c_rcnt),     //设置读出有效数据长度，该长度为全部有效的数据
.O_rdata(i2c_rdata),    //读数据寄存器
.O_iic_busy(i2c_busy), //I2C总线忙
.O_cfg_done(O_cfg_done),  //配置完成
.O_iic_bus_error(O_iic_bus_error)
);


endmodule
