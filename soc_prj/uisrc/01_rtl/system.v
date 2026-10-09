/*******************************MILIANKE*******************************
*Company : MiLianKe Electronic Technology Co., Ltd.
*WebSite:https://www.milianke.com
*TechWeb:https://www.uisrc.com
*tmall-shop:https://milianke.tmall.com
*jd-shop:https://milianke.jd.com
*taobao-shop1: https://milianke.taobao.com
*Create Date: 2024/06/17
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
*4) _n activ low
*5) _dg debug signal 
*6) _r delay or register
*7) _s state mechine
*********************************************************************/

module system_top (
    input  wire 		I_sysclk	,  //PL 系统时钟输入
    input  wire [1:0]	I_button	,  //PL 按键控制曝光
	
	output wire 		O_clk_24m	,
	output wire 		O_cam_rst	,
    output wire 		O_cam_scl	,  //I2C总线，SCL时钟
    inout  wire 		IO_cam_sda	,  //I2C总线，SDA数据
	
	input  wire		    I_clk_hs_p  ,
	input  wire		 	I_clk_lp_p	,
		
	input  wire[1:0]	I_data_hs_p , 
	input  wire[1:0]	I_data_lp_p ,
	input  wire[1:0]	I_data_lp_n ,

	output wire       	O_hdmi_clk_p,  //HDMI时钟输出差分P
    output wire [2:0] 	O_hdmi_tx_p	   //HDMI数据输出差分P
);

  localparam IMG_WIDTH = 1920;
  localparam IMG_HEIGHT = 1080;
  localparam HDMI_ACTIVE_WIDTH = 1024;
  localparam HDMI_ACTIVE_HEIGHT = 600;
  localparam SCALED_IMAGE_WIDTH = 1024;
  localparam SCALED_IMAGE_HEIGHT = 576;
  localparam IMAGE_TOP_OFFSET = (HDMI_ACTIVE_HEIGHT - SCALED_IMAGE_HEIGHT) / 2;

  wire pclkx1;  //synthesis keep  
  wire pclkx5;  //synthesis keep 
  wire clk70m;
  wire clk24m;
  wire locked;
  
  wire p2f_clk0;
  wire p2f_rst0_n;
  wire fdma_rstn;

  wire [31 : 0] fdma_waddr;  //FDMA写地址
  wire 			fdma_wareq;  //写请求
  wire [15 : 0] fdma_wsize;  //FDMA写数据burst大小                                      
  wire 			fdma_wbusy;  //FDMA总线忙

  wire [63 : 0] fdma_wdata;  //FDMA写数据
  wire 			fdma_wvalid; //FDMA写有效
  wire 			fdma_wready; //FDMA写准备好，目前该信号必须设置为1

  wire [31 : 0] fdma_raddr;  //FDMA读地址
  wire 			fdma_rareq;  //FDMA读请求
  wire [15 : 0] fdma_rsize;  //FDMA读数据burst大小                                 
  wire 			fdma_rbusy;  //FDMA读总线忙

  wire [63 : 0] fdma_rdata;  //FDMA读数据
  wire 			fdma_rvalid; //FDMA读有效
  wire 			fdma_rready; //FDMA读准备好，目前该信号必须设置为1
  
  wire [15:0] 	ae;
  wire [15:0] 	ag;
  wire 			cam_cfg_done;
  wire 			ae_cfg_done;
  wire 			ae_req;
  
  wire          S_hs_rx_clk;  //synthesis keep 
  wire          S_hs_rx_valid;//synthesis keep
  wire [15 : 0] S_hs_rx_data; //synthesis keep
                              
  wire          S_csi_frame_start;//synthesis keep
  wire          S_csi_frame_end;  //synthesis keep
  wire          S_csi_valid;      //synthesis keep
  wire [31 : 0] S_csi_data;       //synthesis keep
  
  wire          S_raw10_frame_start;//synthesis keep
  wire          S_raw10_frame_end;  //synthesis keep
  wire          S_raw10_valid;      //synthesis keep
  wire [39 : 0] S_raw10_data;       //synthesis keep
  
  wire 			axis_tvalid;  //synthesis keep
  wire [39:0] 	axis_tdata;   //synthesis keep
  wire 			axis_tuser;   //synthesis keep
  wire 			axis_tlast;   //synthesis keep
	
  wire          ISP_O_tready; //synthesis keep
  wire [127:0]  ISP_O_tdata;  //synthesis keep
  wire          ISP_O_tlast;  //synthesis keep
  wire          ISP_O_tuser;  //synthesis keep
  wire          ISP_O_tvalid; //synthesis keep

  wire          scale_I_tready;
  wire [127:0]  scale_O_tdata;
  wire          scale_O_tlast;
  wire          scale_O_tuser;
  wire          scale_O_tvalid;
  wire          scale_O_tready;

  
  wire [7 : 0] 	wbuf_sync; 
  wire [7 : 0] 	rbuf_sync; 
  
  wire 			fdma_I_R_tready;  	//用户读数据使能
  wire hdmi_video_ready;
  wire 			fdma_O_R_tuser;		//synthesis keep
  wire 			fdma_O_R_tvalid;  	//synthesis keep
  wire [31:0] 	fdma_O_R_tdata;  	//synthesis keep
  wire 			fdma_O_R_tlast;		//synthesis keep
  wire [23:0] 	fdma_O_R_tdata_24;  //synthesis keep
						
  wire 			vtc_vs;  //场同步输出
  wire 			vtc_hs;  //行同步输出
  wire 			vtc_de_valid;  	//synthesis keep  //视频数据有效
  wire 			vtc_user;  		//synthesis keep  //满足stream时序产生 user 信号,用于帧同步
  wire 			vtc_last;  		//synthesis keep  //满足stream时序产生 later 信号,用于每行结束

  reg  [9:0] display_y;
  wire       display_image_line;

  wire 			I_video_in_user;  //synthesis keep  
  wire 			I_video_in_valid; //synthesis keep  
  wire 			I_video_in_last;  //synthesis keep  
  wire [23:0] 	I_video_in_data;  //synthesis keep  
  
  assign O_cam_rst			= 1'b1;
  assign S_clk_lane_idelay  = 20;
  assign S_clk_70m 			= clk70m;  
  assign fdma_rstn 			= p2f_rst0_n & locked;
  assign display_image_line = (display_y >= IMAGE_TOP_OFFSET) &&
                              (display_y < IMAGE_TOP_OFFSET + SCALED_IMAGE_HEIGHT);
  assign fdma_I_R_tready = vtc_de_valid & hdmi_video_ready & display_image_line;
  assign I_video_in_user = vtc_user;
  assign I_video_in_valid = vtc_de_valid & hdmi_video_ready;
  assign I_video_in_last = vtc_last;
  assign I_video_in_data = (display_image_line && fdma_O_R_tvalid) ?
                              fdma_O_R_tdata_24 : 24'd0;

  // Align the 576-line image with each 600-line HDMI frame using 12-line top/bottom bars.
  always @(posedge pclkx1 or negedge locked) begin
    if (!locked)
      display_y <= 10'd0;
    else if (vtc_user)
      display_y <= 10'd0;
    else if (vtc_last) begin
      if (display_y == HDMI_ACTIVE_HEIGHT - 1)
        display_y <= 10'd0;
      else
        display_y <= display_y + 1'b1;
    end
  end

reg [10:0] h_cnt;//synthesis keep
reg [10:0] c_cnt;//synthesis keep

always@(posedge S_hs_rx_clk)begin
	if(!locked || I_video_in_user)
		h_cnt <= 11'd0;
	else if(I_video_in_last)
		h_cnt <= h_cnt + 1'b1;
end	

always@(posedge S_hs_rx_clk)begin
	if(!locked || I_video_in_last)
		c_cnt <= 11'd0;
	else if(I_video_in_valid)
		 c_cnt <= c_cnt + 1'b1;
end

  //调用Design Integrator
  system system_inst (
      .p2f_clk0    (p2f_clk0  	 ),
      .p2f_rst0_n   (p2f_rst0_n  ),
      .I_fdma_waddr (fdma_waddr  ),
      .I_fdma_wareq (fdma_wareq  ),
      .I_fdma_wsize (fdma_wsize  ),
      .O_fdma_wbusy (fdma_wbusy  ),
      .I_fdma_wdata (fdma_wdata  ),
      .O_fdma_wvalid(fdma_wvalid ),
      .I_fdma_wready(fdma_wready ),
      .I_fdma_raddr (fdma_raddr  ),
      .I_fdma_rareq (fdma_rareq  ),
      .I_fdma_rsize (fdma_rsize  ),
      .O_fdma_rbusy (fdma_rbusy  ),
      .O_fdma_rdata (fdma_rdata  ),
      .O_fdma_rvalid(fdma_rvalid ),
      .I_fdma_rready(fdma_rready ),
      .pl_gpio_out	(pl_gpio_out )
  );

  pll U_pll (
      .refclk  (I_sysclk),     //系统时钟输入
      .reset(~p2f_rst0_n),     //PLL复位
      .lock    (locked),       //PLL LOCKED
      .clk0_out(pclkx1),
      .clk1_out(pclkx5),
      .clk2_out(clk70m),
      .clk3_out(clk24m)
  );

  // oDDR primitive
  DR1_LOGIC_ODDR CMOS_CLK (
      .q  (O_clk_24m),  
      .clk(clk24m),
      .d0 (1'b1),
      .d1 (1'b0),
      .rst(1'b0)
  );
  
  ae_set u_ae_set (
      .I_clk(clk24m),
      .I_rst(~locked),
      .I_btn({I_button,2'b11}),
      .I_cam_cfg_done(cam_cfg_done),
      .I_ae_cfg_done(ae_cfg_done),
      .O_ae_req(ae_req),
      .O_ae(ae),
      .O_ag(ag)
  );
  
    uicfgcs500 #(
      .CLK_DIV(24000000 / 100000 - 1)
  ) u_uicfgcs500 (
      .I_clk(clk24m),  //系统时钟输入
      .I_rst_n(locked),  //系统复位输入
      .I_ae_req(ae_req),
      .I_ae(ae),
      .I_ag(ag),
      .O_cam_scl(O_cam_scl),  //I2C总线，SCL时钟
      .IO_cam_sda(IO_cam_sda),  //I2C总线，SDA数据
      .O_cfg_done(cam_cfg_done),  //摄像头寄存器初始化完成
      .O_ae_cfg_done(ae_cfg_done)  //AE配置完成
  );

  mipi_dphy_rx_over_lvds_wrapper#(
    .DEVICE           ( "DR1" ),
    .LANE_NUM         ( 2    )
)u_mipi_dphy_rx_over_lvds_wrapper(
    .I_lp_clk         ( S_clk_70m    ),
    .I_rst            ( ~locked      ),

    .I_mipi_clk_p     ( I_clk_hs_p   ),
    .I_mipi_data_hs_p ( I_data_hs_p  ),
    .I_mipi_data_lp_p ( I_data_lp_p  ),
    .I_mipi_data_lp_n ( I_data_lp_n  ),

    .I_lane_hs_invert ( 2'b00         ),
    .I_lane_lp_invert ( 2'b00         ),

    .O_hs_rx_clk      ( S_hs_rx_clk   ),
    .O_hs_rx_valid    ( S_hs_rx_valid ),
    .O_hs_rx_data     ( S_hs_rx_data  ),

    .O_lp_rx_lane0_p  (),
    .O_lp_rx_lane0_n  (),

    .O_lane_error     ( S_lane_error  )
);
  
    //csi 解码为RAW数据
  csi_unpacket_2lane u_csi_unpacket (
      .I_clk  (S_hs_rx_clk),
      .I_rst_n(locked),
      .I_hs_valid(S_hs_rx_valid),
      .I_hs_data (S_hs_rx_data),

      .O_csi_frame_start(S_csi_frame_start),
      .O_csi_frame_end  (S_csi_frame_end),
      .O_csi_valid      (S_csi_valid),
      .O_csi_data       (S_csi_data)
  );

  //解码为RAW10
  /**/
  raw10_unpacket_2lane u_raw10_unpacket (
      .I_clk  (S_hs_rx_clk),
      .I_rst_n(locked),

      .I_csi_frame_start(S_csi_frame_start),
      .I_csi_frame_end  (S_csi_frame_end),
      .I_csi_valid      (S_csi_valid),
      .I_csi_data       (S_csi_data),

      .O_raw10_frame_start(S_raw10_frame_start),
      .O_raw10_frame_end  (S_raw10_frame_end),
      .O_raw10_valid      (S_raw10_valid),
      .O_raw10_data       (S_raw10_data)
  );


	//将数据转为stream流
	uial2axis #(
	.IMG_WIDTH(IMG_WIDTH),
	.IMG_HEIGHT(IMG_HEIGHT),
	.INPUT_DATA_WIDTH(40)
	) 
	u_uial2axis (
	.I_native_clk(S_hs_rx_clk),
	.I_rst_n     (locked),
	.I_data      (S_raw10_data       ),
	.I_data_valid(S_raw10_valid      ),
	.I_data_start(S_raw10_frame_start),
	.I_data_end  (S_raw10_frame_end  ),
	.axis_tvalid (axis_tvalid),
	.axis_tdata  (axis_tdata ),
	.axis_tuser  (axis_tuser ),
	.axis_tlast  (axis_tlast )
	);

  isp_top  #(
    .IMG_HEIGHT(IMG_HEIGHT),
    .IMG_WIDTH(IMG_WIDTH)
  )u_isp_top
  (
      .axi4s_video_aclk(S_hs_rx_clk),
      .I_rst_n         (locked),
      .I_tlast         (axis_tlast),
      .I_tuser         (axis_tuser),
      .I_tdata         (axis_tdata),
      .I_tvalid        (axis_tvalid),
      .I_tdest         (),
      .O_tready        (ISP_O_tready),
      .O_tdata         (ISP_O_tdata),
      .O_tlast         (ISP_O_tlast),
      .O_tuser         (ISP_O_tuser),
      .O_tvalid        (ISP_O_tvalid),
      .I_tready        ()
  );

  //设置3帧缓存，读延迟写1帧
  uisetvbuf #(
      .BUF_DELAY(2),
      .BUF_LENTH(3)
  ) uisetvbuf_u (
      .I_bufn(wbuf_sync),
      .O_bufn(rbuf_sync)
  );

  uidbuf#(
      .AXI_DATA_WIDTH(64),  //AXI总线数据位宽
      .AXI_ADDR_WIDTH(32),  //AXI总线地址位宽.
      .W_BUFDEPTH(2048),  	//写通道AXI设置FIFO缓存大小
      .W_DATAWIDTH(128),  	//写通道AXI设置数据位宽大小
      .W_BASEADDR(32'h0A000000),//写通道设置内存起始地址
      .W_DSIZEBITS(23), 	//写通道设置缓存数据的增量地址大小，用于FDMA DBUF 计算帧缓存起始地址
      .W_XSIZE(SCALED_IMAGE_WIDTH/4), 		//写通道设置X方向的数据大小，代表了每次FDMA 传输的数据长度
      .W_XSTRIDE(SCALED_IMAGE_WIDTH/4),  	//写通道设置X方向的Stride值，主要用于图形缓存应用
      .W_YSIZE(SCALED_IMAGE_HEIGHT),  		//写通道设置Y方向值，代表了进行了多少次XSIZE传输
      .W_XDIV(2),  			//写通道对X方向数据拆分为XDIV次传输，减少FIFO的使用
      .W_BUFSIZE(3) , 		//写通道设置帧缓存大小，目前最大支持128帧，可以修改参数支持更缓存数.
      .R_BUFDEPTH(2048),  	//读通道AXI设置FIFO缓存大小
      .R_DATAWIDTH(32),  	//读通道AXI设置数据位宽大小
      .R_BASEADDR(32'h0A000000),//读通道设置内存起始地址
      .R_DSIZEBITS(23), 	//读通道设置缓存数据的增量地址大小，用于FDMA DBUF 计算帧缓存起始地址
      .R_XSIZE(SCALED_IMAGE_WIDTH), 		//读通道设置X方向的数据大小，代表了每次FDMA 传输的数据长度
      .R_XSTRIDE(SCALED_IMAGE_WIDTH),  	//读通道设置X方向的Stride值，主要用于图形缓存应用
      .R_YSIZE(SCALED_IMAGE_HEIGHT),  		//读通道设置Y方向值，代表了进行了多少次XSIZE传输
      .R_XDIV(2),  			//读通道对X方向数据拆分为XDIV次传输，减少FIFO的使用
      .R_BUFSIZE(3)  		//读通道设置帧缓存大小，目前最大支持128帧，可以修改参数支持更缓存数
  ) u_uidbuf (
      .I_ui_clk (p2f_clk0),
      .I_ui_rstn(fdma_rstn),

      .I_W_en      (1),
      .I_W_wclk    (S_hs_rx_clk),
      .I_W_tuser   (scale_O_tuser),
      .I_W_tvalid  (scale_O_tvalid),
      .I_W_tdata   (scale_O_tdata),
      .I_W_tlast   (scale_O_tlast),
      .O_W_tready  (scale_O_tready),
      .O_W_sync_cnt(wbuf_sync),
      .I_W_buf     (wbuf_sync),

      .I_R_en      (1),
      .I_R_rclk    (pclkx1),
      .I_R_tready  (fdma_I_R_tready),
      .O_R_tuser   (fdma_O_R_tuser),
      .O_R_tvalid  (fdma_O_R_tvalid),
      .O_R_tdata   (fdma_O_R_tdata),
      .O_R_tlast   (fdma_O_R_tlast),
      .O_R_sync_cnt(),
      .I_R_buf     (rbuf_sync),

      .O_fdma_waddr (fdma_waddr),
      .O_fdma_wareq (fdma_wareq),
      .O_fdma_wsize (fdma_wsize),
      .I_fdma_wbusy (fdma_wbusy),
      .O_fdma_wdata (fdma_wdata),
      .I_fdma_wvalid(fdma_wvalid),
      .O_fdma_wready(fdma_wready),

      .O_fdma_raddr (fdma_raddr),
      .O_fdma_rareq (fdma_rareq),
      .O_fdma_rsize (fdma_rsize),
      .I_fdma_rbusy (fdma_rbusy),
      .I_fdma_rdata (fdma_rdata),
      .I_fdma_rvalid(fdma_rvalid),
      .O_fdma_rready(fdma_rready)
      //   .O_fdma_wbuf  (fdma_wbuf),
      //   .O_fdma_wirq  (fdma_wirq),
      //   .O_fdma_rbuf  (fdma_rbuf),
      //   .O_fdma_rirq  (fdma_rirq)
  );

  rgb4_downscale_8_15 u_rgb4_downscale_8_15 (
      .I_clk    (S_hs_rx_clk),
      .I_rst_n  (locked),
      .I_tdata  (ISP_O_tdata),
      .I_tlast  (ISP_O_tlast),
      .I_tuser  (ISP_O_tuser),
      .I_tvalid (ISP_O_tvalid),
      .I_tready (scale_I_tready),
      .O_tdata  (scale_O_tdata),
      .O_tlast  (scale_O_tlast),
      .O_tuser  (scale_O_tuser),
      .O_tvalid (scale_O_tvalid),
      .O_tready (scale_O_tready)
  );

  assign ISP_O_tready = scale_I_tready;

  uirgb32to24 u_uirgb32to24 (
      .rgb24(fdma_O_R_tdata_24),
      .rgb32(fdma_O_R_tdata)
  );
  reg [20:0] fifowait;  //synthesis keep  
  always @(posedge pclkx1 or negedge locked) begin
    if (locked == 'b0) fifowait <= 'b0;
    else if (fifowait[20] == 0) fifowait <= fifowait + 1;
    else fifowait <= fifowait;
  end

localparam H_ActiveSize    =   (HDMI_ACTIVE_WIDTH);              //视频时间参数,行视频信号，一行有效(需要显示的部分)像素所占的时钟数，一个时钟对应一个有效像素
localparam H_SyncStart     =   (HDMI_ACTIVE_WIDTH+24);           //视频时间参数,行同步开始，即多少时钟数后开始产生行同步信号 
localparam H_SyncEnd       =   (HDMI_ACTIVE_WIDTH+24+136);        //视频时间参数,行同步结束，即多少时钟数后停止产生行同步信号，之后就是行有效数据部分
localparam H_FrameSize     =   (HDMI_ACTIVE_WIDTH+24+136+122);     //视频时间参数,行视频信号，一行视频信号总计占用的时钟数
localparam V_ActiveSize    =   (HDMI_ACTIVE_HEIGHT);              //视频时间参数,场视频信号，一帧图像所占用的有效(需要显示的部分)行数量，通常说的视频分辨率即H_ActiveSize*V_ActiveSize
localparam V_SyncStart     =   (HDMI_ACTIVE_HEIGHT+3);            //视频时间参数,场同步开始，即多少行数后开始产生场同步信号 
localparam V_SyncEnd       =   (HDMI_ACTIVE_HEIGHT+3+6);          //视频时间参数,场同步结束，多少行后停止产生长同步信号  
localparam V_FrameSize     =   (HDMI_ACTIVE_HEIGHT+3+6+29);       //视频时间参数,场视频信号，一帧视频信号总计占用的行数量   


  uivtc #(
      //1080P @ 137.5M
      .H_ActiveSize       (H_ActiveSize), //视频时间参数,行视频信号，一行有效(需要显示的部分)像素所占的时钟数，一个时钟对应一个有效像素
      .H_SyncStart        (H_SyncStart), //视频时间参数,行同步开始，即多少时钟数后开始产生行同步信号 
      .H_SyncEnd          (H_SyncEnd),//视频时间参数,行同步结束，即多少时钟数后停止产生行同步信号，之后就是行有效数据部分
      .H_FrameSize        (H_FrameSize), //视频时间参数,行视频信号，一行视频信号总计占用的时钟数
      .V_ActiveSize       (V_ActiveSize),//视频时间参数,场视频信号，一帧图像所占用的有效(需要显示的部分)行数量，通常说的视频分辨率即H_ActiveSize*V_ActiveSize
      .V_SyncStart        (V_SyncStart),//视频时间参数,场同步开始，即多少行数后开始产生场同步信号 
      .V_SyncEnd          (V_SyncEnd), //视频时间参数,场同步结束，多少行后停止产生长同步信号  
      .V_FrameSize        (V_FrameSize) //视频时间参数,场视频信号，一帧视频信号总计占用的行数量     
  ) uivtc_inst (
      .I_vtc_clk(pclkx1),  //系统时钟 
      .I_vtc_rstn(fifowait[20]),//系统复位
      .O_vtc_vs  (),//场同步输出
      .O_vtc_hs  (),//行同步输出
      .O_vtc_de_valid(vtc_de_valid),//视频数据有效
      .O_vtc_user(vtc_user),    //满足stream时序产生 user 信号,用于帧同步
      .O_vtc_last(vtc_last)     //满足stream时序产生 later 信号,用于每行结束
  );

  hdmi_tx #(
      //HDMI视频参数设置       
      //1080P @ 137.5M
      .H_ActiveSize       (H_ActiveSize), //视频时间参数,行视频信号，一行有效(需要显示的部分)像素所占的时钟数，一个时钟对应一个有效像素
      .H_SyncStart        (H_SyncStart), //视频时间参数,行同步开始，即多少时钟数后开始产生行同步信号 
      .H_SyncEnd          (H_SyncEnd),//视频时间参数,行同步结束，即多少时钟数后停止产生行同步信号，之后就是行有效数据部分
      .H_FrameSize        (H_FrameSize), //视频时间参数,行视频信号，一行视频信号总计占用的时钟数
      .V_ActiveSize       (V_ActiveSize),//视频时间参数,场视频信号，一帧图像所占用的有效(需要显示的部分)行数量，通常说的视频分辨率即H_ActiveSize*V_ActiveSize
      .V_SyncStart        (V_SyncStart),//视频时间参数,场同步开始，即多少行数后开始产生场同步信号 
      .V_SyncEnd          (V_SyncEnd), //视频时间参数,场同步结束，多少行后停止产生长同步信号  
      .V_FrameSize        (V_FrameSize),  //视频时间参数,场视频信号，一帧视频信号总计占用的行数量              
	  .DEVICE             ( "DR1"   ),  
      .VIDEO_VIC		  (0		),
      .VIDEO_TPG          ("Disable"),//设置disable，用户数据驱动HDMI接口，否则设置eable产生内部测试图形
      .VIDEO_FORMAT		  ("RGB444"	)  //设置输入数据格式为RGB格式
  ) u_hdmi_tx (
      .I_pixel_clk (pclkx1),  //像素时钟
      .I_serial_clk(pclkx5),  //串行发送时钟
      .I_rst       (~fifowait[20]), //异步复位信号，高电平有效
      .I_video_rgb_enable(1'b0),
      .I_video_in_de(1'b0),
      .I_video_in_vs(1'b0),
      
      .I_video_in_user(I_video_in_user),  //视频输入帧起始信号
      .I_video_in_last(I_video_in_last),  //视频输入行结束信号
      .I_video_in_data(I_video_in_data),  //视频输入数据
      .I_video_in_valid(I_video_in_valid),//视频输入有效信号
      .O_video_in_ready(hdmi_video_ready),
	  
      .O_hdmi_clk_p(O_hdmi_clk_p),  //HDMI时钟通道
      .O_hdmi_tx_p(O_hdmi_tx_p)  	//HDMI数据通道
  );

endmodule

