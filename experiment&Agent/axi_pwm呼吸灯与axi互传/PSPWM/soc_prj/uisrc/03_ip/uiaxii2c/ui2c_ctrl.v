
/*******************************MILIANKE*******************************
*Company : MiLianKe Electronic Technology Co., Ltd.
*WebSite:https://www.milianke.com
*TechWeb:https://www.uisrc.com
*tmall-shop:https://milianke.tmall.com
*jd-shop:https://milianke.jd.com
*taobao-shop: https://milianke.taobao.com
*Create Date: 2021/04/25
*Module Name:
*File Name:
*Description: 
*The reference demo provided by Milianke is only used for learning. 
*We cannot ensure that the demo itself is free of bugs, so users 
*should be responsible for the technical problems and consequences
*caused by the use of their own products.
*Copyright: Copyright (c) MiLianKe
*All rights reserved.
*Revision: 1.0
*Signal description
*1) I_ input
*2) O_ output
*3) IO_ input output
*4) S_ system internal signal
*5) _n activ low
*6) _dg debug signal 
*7) _r delay or register
*8) _s state mechine
*********************************************************************/

/*******************************uii2c_ctrl***************************
--1.配合AXI总线使用的I2C控制器
*********************************************************************/

`timescale 1ns / 1ns

module uii2c_ctrl#
(
parameter integer CLK_DIV  = 16'd499,
parameter integer WMEN_LEN = 3,
parameter integer RMEN_LEN = 1
)
(
input  wire                     I_clk,      //系统时钟输入
input  wire                     I_rst_n,    //系统复位输入

output wire                     O_scl,      //I2C总线，SCL时钟
inout  wire                     IO_sda,     //I2C总线，SDA数据

input  wire                     I_req,      //I2C请求

input  wire[7:0]                I_wcnt,     //设置写入有效数据长度，包含寄存器地址，不含1byte的器件地址
input  wire[WMEN_LEN*8-1 : 0]   I_wdata,    //写数据寄存器，包含了器件地址和有效的数据
input  wire[7:0]                I_rcnt,     //设置读出有效数据长度，该长度为全部有效的数据
output wire[RMEN_LEN*8-1 : 0]   O_rdata,    //读数据寄存器

output wire                     O_iic_busy, //I2C总线忙
output wire                     O_iic_bus_error,
output reg                      O_cfg_done  //配置完成
);

//内部计数器产生一个延迟复位
reg[7:0] rst_cnt =0;
always@(posedge I_clk or negedge I_rst_n)  
    if(I_rst_n == 1'b0) //复位初始化寄存器
        rst_cnt<= 8'd0; 
    else if(rst_cnt[7] == 1'b0)
       rst_cnt <= rst_cnt + 1'b1; 
    else 
       rst_cnt <= rst_cnt; 

reg  iic_req;            //请求操作I2C控制器信号

reg  r_iic_busy;
wire iic_busy;           //I2C控制器忙信号 

assign O_iic_busy = iic_busy|r_iic_busy;
reg  [1 :0] TS_S = 2'd0; //状态机寄存器

always@(posedge I_clk ) begin 
    if(rst_cnt[7] == 1'b0)begin //复位初始化寄存器
        iic_req        <= 1'b0;
        r_iic_busy     <= 1'b0;
        O_cfg_done     <= 1'b0;
        TS_S           <= 2'd0;    
    end
    else begin
        case(TS_S)
        0:if(I_req )begin
            O_cfg_done <= 1'b0; //I2C操作完成  
            r_iic_busy <= 1'b1; //I2C总先忙
            iic_req    <= 1'b1; //请求操作I2C控制器
            TS_S       <= 2'b1; //I2C状态机
        end
        else begin
            O_cfg_done <= 1'b0; //I2C操作完成  
            r_iic_busy <= 1'b0; //I2C总先忙
        end
        1:if(iic_busy)begin
             iic_req   <= 1'b0;  //重置 iic_req =0
             TS_S      <= 2'd2;  //下一个状态
        end
        2:if(!iic_busy)begin     //当总线非忙，才可以操作I2C控制器 
			O_cfg_done <= 1'b1;
            r_iic_busy <= 1'b0;
			TS_S       <= 2'd0;  //回到初始状态
        end 
        default:begin
            O_cfg_done <= 1'b0;
            r_iic_busy <= 1'b0;
            iic_req    <= 1'b0;
            TS_S       <= 2'd0;  //回到初始状态
        end
        endcase
   end
end

//例化I2C控制模块
uii2c#
(
.WMEN_LEN(WMEN_LEN),     //最大支持一次写入4BYTE(包含器件地址)
.RMEN_LEN(RMEN_LEN),     //最大支持一次读出1BYTE
.CLK_DIV(CLK_DIV) //100KHZ I2C总线时钟
)
uii2c_inst
(
.I_clk(I_clk),//系统时钟
.I_rstn(rst_cnt[7]),//系统复位
.O_iic_scl(O_scl),//I2C SCL总线时钟
.IO_iic_sda(IO_sda),//I2C SDA数据总线
.I_wr_data(I_wdata),//写数据寄存器
.I_wr_cnt(I_wcnt),//需要写的数据BYTES
.O_rd_data(O_rdata),   //读数据寄存器
.I_rd_cnt(I_rcnt),//需要读的数据BYTES
.I_iic_mode(1'b1),//读模式设置
.I_iic_req(iic_req),//I2C控制器请求
.O_iic_busy(iic_busy),//I2C控制器忙
.O_iic_bus_error(O_iic_bus_error)
);


endmodule
