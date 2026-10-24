module system (
    input     wire       [31:0] I_fdma_waddr ,
    input     wire              I_fdma_wareq ,
    input     wire       [15:0] I_fdma_wsize ,
    input     wire              I_fdma_wready ,
    input     wire       [31:0] I_fdma_raddr ,
    input     wire              I_fdma_rareq ,
    input     wire       [15:0] I_fdma_rsize ,
    input     wire              I_fdma_rready ,
    input     wire       [63:0] I_fdma_wdata ,
    input     wire              pwm_clk ,
    input     wire              rst_n ,
    output    wire              p2f_clk0 ,
    output    wire              p2f_rst0_n ,
    output    wire              O_fdma_wbusy ,
    output    wire              O_fdma_wvalid ,
    output    wire              O_fdma_rbusy ,
    output    wire              O_fdma_rvalid ,
    output    wire       [63:0] O_fdma_rdata ,
    output    wire        [3:0] code_driver ,
    output    wire              pwm_out1 ,
    output    wire        [2:0] pwm_out ,
    output    wire        [1:0] motor_dir ,
    output    wire              motor_enable
); 
    wire [32:0]       w_port__ARM_Processor_System_0__master_gp0_axi_araddr ;
    wire [31:0]       w_port__AXI_Matrix_0__us0_araddr ;
    wire [32:0]       w_net__ARM_Processor_System_0__master_gp0_axi_araddr ; 

    wire [1:0]        w_port__ARM_Processor_System_0__master_gp0_axi_arburst ;
    wire [1:0]        w_port__AXI_Matrix_0__us0_arburst ;
    wire [1:0]        w_net__ARM_Processor_System_0__master_gp0_axi_arburst ; 

    wire [3:0]        w_port__ARM_Processor_System_0__master_gp0_axi_arcache ;
    wire [3:0]        w_port__AXI_Matrix_0__us0_arcache ;
    wire [3:0]        w_net__ARM_Processor_System_0__master_gp0_axi_arcache ; 

    wire [11:0]       w_port__ARM_Processor_System_0__master_gp0_axi_arid ;
    wire [0:0]        w_port__AXI_Matrix_0__us0_arid ;
    wire [11:0]       w_net__ARM_Processor_System_0__master_gp0_axi_arid ; 

    wire [3:0]        w_port__ARM_Processor_System_0__master_gp0_axi_arlen ;
    wire [7:0]        w_port__AXI_Matrix_0__us0_arlen ;
    wire [3:0]        w_net__ARM_Processor_System_0__master_gp0_axi_arlen ; 

    wire              w_port__ARM_Processor_System_0__master_gp0_axi_arlock ;
    wire [0:0]        w_port__AXI_Matrix_0__us0_arlock ;
    wire              w_net__ARM_Processor_System_0__master_gp0_axi_arlock ; 

    wire [2:0]        w_port__ARM_Processor_System_0__master_gp0_axi_arprot ;
    wire [2:0]        w_port__AXI_Matrix_0__us0_arprot ;
    wire [2:0]        w_net__ARM_Processor_System_0__master_gp0_axi_arprot ; 

    wire [1:0]        w_port__ARM_Processor_System_0__master_gp0_axi_arsize ;
    wire [2:0]        w_port__AXI_Matrix_0__us0_arsize ;
    wire [1:0]        w_net__ARM_Processor_System_0__master_gp0_axi_arsize ; 

    wire              w_port__ARM_Processor_System_0__master_gp0_axi_arvalid ;
    wire              w_port__AXI_Matrix_0__us0_arvalid ;
    wire              w_net__ARM_Processor_System_0__master_gp0_axi_arvalid ; 

    wire [32:0]       w_port__ARM_Processor_System_0__master_gp0_axi_awaddr ;
    wire [31:0]       w_port__AXI_Matrix_0__us0_awaddr ;
    wire [32:0]       w_net__ARM_Processor_System_0__master_gp0_axi_awaddr ; 

    wire [1:0]        w_port__ARM_Processor_System_0__master_gp0_axi_awburst ;
    wire [1:0]        w_port__AXI_Matrix_0__us0_awburst ;
    wire [1:0]        w_net__ARM_Processor_System_0__master_gp0_axi_awburst ; 

    wire [3:0]        w_port__ARM_Processor_System_0__master_gp0_axi_awcache ;
    wire [3:0]        w_port__AXI_Matrix_0__us0_awcache ;
    wire [3:0]        w_net__ARM_Processor_System_0__master_gp0_axi_awcache ; 

    wire [11:0]       w_port__ARM_Processor_System_0__master_gp0_axi_awid ;
    wire [0:0]        w_port__AXI_Matrix_0__us0_awid ;
    wire [11:0]       w_net__ARM_Processor_System_0__master_gp0_axi_awid ; 

    wire [3:0]        w_port__ARM_Processor_System_0__master_gp0_axi_awlen ;
    wire [7:0]        w_port__AXI_Matrix_0__us0_awlen ;
    wire [3:0]        w_net__ARM_Processor_System_0__master_gp0_axi_awlen ; 

    wire              w_port__ARM_Processor_System_0__master_gp0_axi_awlock ;
    wire [0:0]        w_port__AXI_Matrix_0__us0_awlock ;
    wire              w_net__ARM_Processor_System_0__master_gp0_axi_awlock ; 

    wire [2:0]        w_port__ARM_Processor_System_0__master_gp0_axi_awprot ;
    wire [2:0]        w_port__AXI_Matrix_0__us0_awprot ;
    wire [2:0]        w_net__ARM_Processor_System_0__master_gp0_axi_awprot ; 

    wire [1:0]        w_port__ARM_Processor_System_0__master_gp0_axi_awsize ;
    wire [2:0]        w_port__AXI_Matrix_0__us0_awsize ;
    wire [1:0]        w_net__ARM_Processor_System_0__master_gp0_axi_awsize ; 

    wire              w_port__ARM_Processor_System_0__master_gp0_axi_awvalid ;
    wire              w_port__AXI_Matrix_0__us0_awvalid ;
    wire              w_net__ARM_Processor_System_0__master_gp0_axi_awvalid ; 

    wire              w_port__ARM_Processor_System_0__master_gp0_axi_bready ;
    wire              w_port__AXI_Matrix_0__us0_bready ;
    wire              w_net__ARM_Processor_System_0__master_gp0_axi_bready ; 

    wire              w_port__ARM_Processor_System_0__master_gp0_axi_rready ;
    wire              w_port__AXI_Matrix_0__us0_rready ;
    wire              w_net__ARM_Processor_System_0__master_gp0_axi_rready ; 

    wire [31:0]       w_port__ARM_Processor_System_0__master_gp0_axi_wdata ;
    wire [31:0]       w_port__AXI_Matrix_0__us0_wdata ;
    wire [31:0]       w_net__ARM_Processor_System_0__master_gp0_axi_wdata ; 

    wire              w_port__ARM_Processor_System_0__master_gp0_axi_wlast ;
    wire              w_port__AXI_Matrix_0__us0_wlast ;
    wire              w_net__ARM_Processor_System_0__master_gp0_axi_wlast ; 

    wire [3:0]        w_port__ARM_Processor_System_0__master_gp0_axi_wstrb ;
    wire [3:0]        w_port__AXI_Matrix_0__us0_wstrb ;
    wire [3:0]        w_net__ARM_Processor_System_0__master_gp0_axi_wstrb ; 

    wire              w_port__ARM_Processor_System_0__master_gp0_axi_wvalid ;
    wire              w_port__AXI_Matrix_0__us0_wvalid ;
    wire              w_net__ARM_Processor_System_0__master_gp0_axi_wvalid ; 

    wire              w_port__ARM_Processor_System_0__p2f_clk0 ;
    wire              w_port__ARM_Processor_System_0__slave_hp0_axi_aclk ;
    wire              w_port__uiFDMA_0__M_AXI_ACLK ;
    wire              w_port__ARM_Processor_System_0__master_gp0_axi_aclk ;
    wire              w_port__Processor_System_Reset_0__clk ;
    wire              w_net__ARM_Processor_System_0__p2f_clk0 ; 

    wire              w_port__ARM_Processor_System_0__p2f_clk1 ;
    wire              w_port__AXI_Matrix_0__aclk ;
    wire              w_port__AXI_Protocol_Converter_0__aclk ;
    wire              w_port__AXI_Protocol_Converter_1__aclk ;
    wire              w_port__AXI_GPIO_0__s_axi_aclk ;
    wire              w_port__AXI_GPIO_1__s_axi_aclk ;
    wire              w_port__AXI_Protocol_Converter_2__aclk ;
    wire              w_port__axi_lite_pwm_0__s_axi_aclk ;
    wire              w_net__ARM_Processor_System_0__p2f_clk1 ; 

    wire              w_port__ARM_Processor_System_0__p2f_rst0_n ;
    wire              w_port__uiFDMA_0__M_AXI_ARESETN ;
    wire              w_port__AXI_GPIO_0__s_axi_aresetn ;
    wire              w_port__AXI_Protocol_Converter_0__aresetn ;
    wire              w_port__AXI_Protocol_Converter_1__aresetn ;
    wire              w_port__AXI_GPIO_1__s_axi_aresetn ;
    wire              w_port__AXI_Matrix_0__aresetn ;
    wire              w_port__Processor_System_Reset_0__external_reset ;
    wire              w_port__AXI_Protocol_Converter_2__aresetn ;
    wire              w_port__axi_lite_pwm_0__s_axi_aresetn ;
    wire              w_net__ARM_Processor_System_0__p2f_rst0_n ; 

    wire              w_port__ARM_Processor_System_0__slave_hp0_axi_arready ;
    wire              w_port__uiFDMA_0__M_AXI_ARREADY ;
    wire              w_net__ARM_Processor_System_0__slave_hp0_axi_arready ; 

    wire              w_port__ARM_Processor_System_0__slave_hp0_axi_awready ;
    wire              w_port__uiFDMA_0__M_AXI_AWREADY ;
    wire              w_net__ARM_Processor_System_0__slave_hp0_axi_awready ; 

    wire [5:0]        w_port__ARM_Processor_System_0__slave_hp0_axi_bid ;
    wire [11:0]       w_port__uiFDMA_0__M_AXI_BID ;
    wire [5:0]        w_net__ARM_Processor_System_0__slave_hp0_axi_bid ; 

    wire [1:0]        w_port__ARM_Processor_System_0__slave_hp0_axi_bresp ;
    wire [1:0]        w_port__uiFDMA_0__M_AXI_BRESP ;
    wire [1:0]        w_net__ARM_Processor_System_0__slave_hp0_axi_bresp ; 

    wire              w_port__ARM_Processor_System_0__slave_hp0_axi_bvalid ;
    wire              w_port__uiFDMA_0__M_AXI_BVALID ;
    wire              w_net__ARM_Processor_System_0__slave_hp0_axi_bvalid ; 

    wire [63:0]       w_port__ARM_Processor_System_0__slave_hp0_axi_rdata ;
    wire [63:0]       w_port__uiFDMA_0__M_AXI_RDATA ;
    wire [63:0]       w_net__ARM_Processor_System_0__slave_hp0_axi_rdata ; 

    wire [5:0]        w_port__ARM_Processor_System_0__slave_hp0_axi_rid ;
    wire [11:0]       w_port__uiFDMA_0__M_AXI_RID ;
    wire [5:0]        w_net__ARM_Processor_System_0__slave_hp0_axi_rid ; 

    wire              w_port__ARM_Processor_System_0__slave_hp0_axi_rlast ;
    wire              w_port__uiFDMA_0__M_AXI_RLAST ;
    wire              w_net__ARM_Processor_System_0__slave_hp0_axi_rlast ; 

    wire [1:0]        w_port__ARM_Processor_System_0__slave_hp0_axi_rresp ;
    wire [1:0]        w_port__uiFDMA_0__M_AXI_RRESP ;
    wire [1:0]        w_net__ARM_Processor_System_0__slave_hp0_axi_rresp ; 

    wire              w_port__ARM_Processor_System_0__slave_hp0_axi_rvalid ;
    wire              w_port__uiFDMA_0__M_AXI_RVALID ;
    wire              w_net__ARM_Processor_System_0__slave_hp0_axi_rvalid ; 

    wire              w_port__ARM_Processor_System_0__slave_hp0_axi_wready ;
    wire              w_port__uiFDMA_0__M_AXI_WREADY ;
    wire              w_net__ARM_Processor_System_0__slave_hp0_axi_wready ; 

    wire [3:0]        w_port__AXI_GPIO_0__gpio_io_o ;
    wire [3:0]        w_net__AXI_GPIO_0__gpio_io_o ; 

    wire              w_port__AXI_GPIO_0__s_axi_arready ;
    wire              w_port__AXI_Protocol_Converter_0__ds_axi_arready ;
    wire              w_net__AXI_GPIO_0__s_axi_arready ; 

    wire              w_port__AXI_GPIO_0__s_axi_awready ;
    wire              w_port__AXI_Protocol_Converter_0__ds_axi_awready ;
    wire              w_net__AXI_GPIO_0__s_axi_awready ; 

    wire [1:0]        w_port__AXI_GPIO_0__s_axi_bresp ;
    wire [1:0]        w_port__AXI_Protocol_Converter_0__ds_axi_bresp ;
    wire [1:0]        w_net__AXI_GPIO_0__s_axi_bresp ; 

    wire              w_port__AXI_GPIO_0__s_axi_bvalid ;
    wire              w_port__AXI_Protocol_Converter_0__ds_axi_bvalid ;
    wire              w_net__AXI_GPIO_0__s_axi_bvalid ; 

    wire [31:0]       w_port__AXI_GPIO_0__s_axi_rdata ;
    wire [31:0]       w_port__AXI_Protocol_Converter_0__ds_axi_rdata ;
    wire [31:0]       w_net__AXI_GPIO_0__s_axi_rdata ; 

    wire [1:0]        w_port__AXI_GPIO_0__s_axi_rresp ;
    wire [1:0]        w_port__AXI_Protocol_Converter_0__ds_axi_rresp ;
    wire [1:0]        w_net__AXI_GPIO_0__s_axi_rresp ; 

    wire              w_port__AXI_GPIO_0__s_axi_rvalid ;
    wire              w_port__AXI_Protocol_Converter_0__ds_axi_rvalid ;
    wire              w_net__AXI_GPIO_0__s_axi_rvalid ; 

    wire              w_port__AXI_GPIO_0__s_axi_wready ;
    wire              w_port__AXI_Protocol_Converter_0__ds_axi_wready ;
    wire              w_net__AXI_GPIO_0__s_axi_wready ; 

    wire [31:0]       w_port__AXI_GPIO_1__gpio2_io_o ;
    wire [31:0]       w_port__PWM_0__RELOAD_VALUE ;
    wire [31:0]       w_net__AXI_GPIO_1__gpio2_io_o ; 

    wire [31:0]       w_port__AXI_GPIO_1__gpio_io_o ;
    wire [31:0]       w_port__PWM_0__DUTY_VALUE ;
    wire [31:0]       w_net__AXI_GPIO_1__gpio_io_o ; 

    wire              w_port__AXI_GPIO_1__s_axi_arready ;
    wire              w_port__AXI_Protocol_Converter_1__ds_axi_arready ;
    wire              w_net__AXI_GPIO_1__s_axi_arready ; 

    wire              w_port__AXI_GPIO_1__s_axi_awready ;
    wire              w_port__AXI_Protocol_Converter_1__ds_axi_awready ;
    wire              w_net__AXI_GPIO_1__s_axi_awready ; 

    wire [1:0]        w_port__AXI_GPIO_1__s_axi_bresp ;
    wire [1:0]        w_port__AXI_Protocol_Converter_1__ds_axi_bresp ;
    wire [1:0]        w_net__AXI_GPIO_1__s_axi_bresp ; 

    wire              w_port__AXI_GPIO_1__s_axi_bvalid ;
    wire              w_port__AXI_Protocol_Converter_1__ds_axi_bvalid ;
    wire              w_net__AXI_GPIO_1__s_axi_bvalid ; 

    wire [31:0]       w_port__AXI_GPIO_1__s_axi_rdata ;
    wire [31:0]       w_port__AXI_Protocol_Converter_1__ds_axi_rdata ;
    wire [31:0]       w_net__AXI_GPIO_1__s_axi_rdata ; 

    wire [1:0]        w_port__AXI_GPIO_1__s_axi_rresp ;
    wire [1:0]        w_port__AXI_Protocol_Converter_1__ds_axi_rresp ;
    wire [1:0]        w_net__AXI_GPIO_1__s_axi_rresp ; 

    wire              w_port__AXI_GPIO_1__s_axi_rvalid ;
    wire              w_port__AXI_Protocol_Converter_1__ds_axi_rvalid ;
    wire              w_net__AXI_GPIO_1__s_axi_rvalid ; 

    wire              w_port__AXI_GPIO_1__s_axi_wready ;
    wire              w_port__AXI_Protocol_Converter_1__ds_axi_wready ;
    wire              w_net__AXI_GPIO_1__s_axi_wready ; 

    wire [31:0]       w_port__AXI_Matrix_0__ds0_araddr ;
    wire [31:0]       w_port__AXI_Protocol_Converter_0__us_axi_araddr ;
    wire [31:0]       w_net__AXI_Matrix_0__ds0_araddr ; 

    wire [1:0]        w_port__AXI_Matrix_0__ds0_arburst ;
    wire [1:0]        w_port__AXI_Protocol_Converter_0__us_axi_arburst ;
    wire [1:0]        w_net__AXI_Matrix_0__ds0_arburst ; 

    wire [3:0]        w_port__AXI_Matrix_0__ds0_arcache ;
    wire [3:0]        w_port__AXI_Protocol_Converter_0__us_axi_arcache ;
    wire [3:0]        w_net__AXI_Matrix_0__ds0_arcache ; 

    wire [1:0]        w_port__AXI_Matrix_0__ds0_arid ;
    wire [3:0]        w_port__AXI_Protocol_Converter_0__us_axi_arid ;
    wire [1:0]        w_net__AXI_Matrix_0__ds0_arid ; 

    wire [7:0]        w_port__AXI_Matrix_0__ds0_arlen ;
    wire [7:0]        w_port__AXI_Protocol_Converter_0__us_axi_arlen ;
    wire [7:0]        w_net__AXI_Matrix_0__ds0_arlen ; 

    wire [0:0]        w_port__AXI_Matrix_0__ds0_arlock ;
    wire [0:0]        w_port__AXI_Protocol_Converter_0__us_axi_arlock ;
    wire [0:0]        w_net__AXI_Matrix_0__ds0_arlock ; 

    wire [2:0]        w_port__AXI_Matrix_0__ds0_arprot ;
    wire [2:0]        w_port__AXI_Protocol_Converter_0__us_axi_arprot ;
    wire [2:0]        w_net__AXI_Matrix_0__ds0_arprot ; 

    wire [3:0]        w_port__AXI_Matrix_0__ds0_arqos ;
    wire [3:0]        w_port__AXI_Protocol_Converter_0__us_axi_arqos ;
    wire [3:0]        w_net__AXI_Matrix_0__ds0_arqos ; 

    wire [2:0]        w_port__AXI_Matrix_0__ds0_arsize ;
    wire [2:0]        w_port__AXI_Protocol_Converter_0__us_axi_arsize ;
    wire [2:0]        w_net__AXI_Matrix_0__ds0_arsize ; 

    wire              w_port__AXI_Matrix_0__ds0_arvalid ;
    wire              w_port__AXI_Protocol_Converter_0__us_axi_arvalid ;
    wire              w_net__AXI_Matrix_0__ds0_arvalid ; 

    wire [31:0]       w_port__AXI_Matrix_0__ds0_awaddr ;
    wire [31:0]       w_port__AXI_Protocol_Converter_0__us_axi_awaddr ;
    wire [31:0]       w_net__AXI_Matrix_0__ds0_awaddr ; 

    wire [1:0]        w_port__AXI_Matrix_0__ds0_awburst ;
    wire [1:0]        w_port__AXI_Protocol_Converter_0__us_axi_awburst ;
    wire [1:0]        w_net__AXI_Matrix_0__ds0_awburst ; 

    wire [3:0]        w_port__AXI_Matrix_0__ds0_awcache ;
    wire [3:0]        w_port__AXI_Protocol_Converter_0__us_axi_awcache ;
    wire [3:0]        w_net__AXI_Matrix_0__ds0_awcache ; 

    wire [1:0]        w_port__AXI_Matrix_0__ds0_awid ;
    wire [3:0]        w_port__AXI_Protocol_Converter_0__us_axi_awid ;
    wire [1:0]        w_net__AXI_Matrix_0__ds0_awid ; 

    wire [7:0]        w_port__AXI_Matrix_0__ds0_awlen ;
    wire [7:0]        w_port__AXI_Protocol_Converter_0__us_axi_awlen ;
    wire [7:0]        w_net__AXI_Matrix_0__ds0_awlen ; 

    wire [0:0]        w_port__AXI_Matrix_0__ds0_awlock ;
    wire [0:0]        w_port__AXI_Protocol_Converter_0__us_axi_awlock ;
    wire [0:0]        w_net__AXI_Matrix_0__ds0_awlock ; 

    wire [2:0]        w_port__AXI_Matrix_0__ds0_awprot ;
    wire [2:0]        w_port__AXI_Protocol_Converter_0__us_axi_awprot ;
    wire [2:0]        w_net__AXI_Matrix_0__ds0_awprot ; 

    wire [3:0]        w_port__AXI_Matrix_0__ds0_awqos ;
    wire [3:0]        w_port__AXI_Protocol_Converter_0__us_axi_awqos ;
    wire [3:0]        w_net__AXI_Matrix_0__ds0_awqos ; 

    wire [2:0]        w_port__AXI_Matrix_0__ds0_awsize ;
    wire [2:0]        w_port__AXI_Protocol_Converter_0__us_axi_awsize ;
    wire [2:0]        w_net__AXI_Matrix_0__ds0_awsize ; 

    wire              w_port__AXI_Matrix_0__ds0_awvalid ;
    wire              w_port__AXI_Protocol_Converter_0__us_axi_awvalid ;
    wire              w_net__AXI_Matrix_0__ds0_awvalid ; 

    wire              w_port__AXI_Matrix_0__ds0_bready ;
    wire              w_port__AXI_Protocol_Converter_0__us_axi_bready ;
    wire              w_net__AXI_Matrix_0__ds0_bready ; 

    wire              w_port__AXI_Matrix_0__ds0_rready ;
    wire              w_port__AXI_Protocol_Converter_0__us_axi_rready ;
    wire              w_net__AXI_Matrix_0__ds0_rready ; 

    wire [31:0]       w_port__AXI_Matrix_0__ds0_wdata ;
    wire [31:0]       w_port__AXI_Protocol_Converter_0__us_axi_wdata ;
    wire [31:0]       w_net__AXI_Matrix_0__ds0_wdata ; 

    wire              w_port__AXI_Matrix_0__ds0_wlast ;
    wire              w_port__AXI_Protocol_Converter_0__us_axi_wlast ;
    wire              w_net__AXI_Matrix_0__ds0_wlast ; 

    wire [3:0]        w_port__AXI_Matrix_0__ds0_wstrb ;
    wire [3:0]        w_port__AXI_Protocol_Converter_0__us_axi_wstrb ;
    wire [3:0]        w_net__AXI_Matrix_0__ds0_wstrb ; 

    wire              w_port__AXI_Matrix_0__ds0_wvalid ;
    wire              w_port__AXI_Protocol_Converter_0__us_axi_wvalid ;
    wire              w_net__AXI_Matrix_0__ds0_wvalid ; 

    wire [31:0]       w_port__AXI_Matrix_0__ds1_araddr ;
    wire [31:0]       w_port__AXI_Protocol_Converter_1__us_axi_araddr ;
    wire [31:0]       w_net__AXI_Matrix_0__ds1_araddr ; 

    wire [1:0]        w_port__AXI_Matrix_0__ds1_arburst ;
    wire [1:0]        w_port__AXI_Protocol_Converter_1__us_axi_arburst ;
    wire [1:0]        w_net__AXI_Matrix_0__ds1_arburst ; 

    wire [3:0]        w_port__AXI_Matrix_0__ds1_arcache ;
    wire [3:0]        w_port__AXI_Protocol_Converter_1__us_axi_arcache ;
    wire [3:0]        w_net__AXI_Matrix_0__ds1_arcache ; 

    wire [1:0]        w_port__AXI_Matrix_0__ds1_arid ;
    wire [3:0]        w_port__AXI_Protocol_Converter_1__us_axi_arid ;
    wire [1:0]        w_net__AXI_Matrix_0__ds1_arid ; 

    wire [7:0]        w_port__AXI_Matrix_0__ds1_arlen ;
    wire [7:0]        w_port__AXI_Protocol_Converter_1__us_axi_arlen ;
    wire [7:0]        w_net__AXI_Matrix_0__ds1_arlen ; 

    wire [0:0]        w_port__AXI_Matrix_0__ds1_arlock ;
    wire [0:0]        w_port__AXI_Protocol_Converter_1__us_axi_arlock ;
    wire [0:0]        w_net__AXI_Matrix_0__ds1_arlock ; 

    wire [2:0]        w_port__AXI_Matrix_0__ds1_arprot ;
    wire [2:0]        w_port__AXI_Protocol_Converter_1__us_axi_arprot ;
    wire [2:0]        w_net__AXI_Matrix_0__ds1_arprot ; 

    wire [3:0]        w_port__AXI_Matrix_0__ds1_arqos ;
    wire [3:0]        w_port__AXI_Protocol_Converter_1__us_axi_arqos ;
    wire [3:0]        w_net__AXI_Matrix_0__ds1_arqos ; 

    wire [2:0]        w_port__AXI_Matrix_0__ds1_arsize ;
    wire [2:0]        w_port__AXI_Protocol_Converter_1__us_axi_arsize ;
    wire [2:0]        w_net__AXI_Matrix_0__ds1_arsize ; 

    wire              w_port__AXI_Matrix_0__ds1_arvalid ;
    wire              w_port__AXI_Protocol_Converter_1__us_axi_arvalid ;
    wire              w_net__AXI_Matrix_0__ds1_arvalid ; 

    wire [31:0]       w_port__AXI_Matrix_0__ds1_awaddr ;
    wire [31:0]       w_port__AXI_Protocol_Converter_1__us_axi_awaddr ;
    wire [31:0]       w_net__AXI_Matrix_0__ds1_awaddr ; 

    wire [1:0]        w_port__AXI_Matrix_0__ds1_awburst ;
    wire [1:0]        w_port__AXI_Protocol_Converter_1__us_axi_awburst ;
    wire [1:0]        w_net__AXI_Matrix_0__ds1_awburst ; 

    wire [3:0]        w_port__AXI_Matrix_0__ds1_awcache ;
    wire [3:0]        w_port__AXI_Protocol_Converter_1__us_axi_awcache ;
    wire [3:0]        w_net__AXI_Matrix_0__ds1_awcache ; 

    wire [1:0]        w_port__AXI_Matrix_0__ds1_awid ;
    wire [3:0]        w_port__AXI_Protocol_Converter_1__us_axi_awid ;
    wire [1:0]        w_net__AXI_Matrix_0__ds1_awid ; 

    wire [7:0]        w_port__AXI_Matrix_0__ds1_awlen ;
    wire [7:0]        w_port__AXI_Protocol_Converter_1__us_axi_awlen ;
    wire [7:0]        w_net__AXI_Matrix_0__ds1_awlen ; 

    wire [0:0]        w_port__AXI_Matrix_0__ds1_awlock ;
    wire [0:0]        w_port__AXI_Protocol_Converter_1__us_axi_awlock ;
    wire [0:0]        w_net__AXI_Matrix_0__ds1_awlock ; 

    wire [2:0]        w_port__AXI_Matrix_0__ds1_awprot ;
    wire [2:0]        w_port__AXI_Protocol_Converter_1__us_axi_awprot ;
    wire [2:0]        w_net__AXI_Matrix_0__ds1_awprot ; 

    wire [3:0]        w_port__AXI_Matrix_0__ds1_awqos ;
    wire [3:0]        w_port__AXI_Protocol_Converter_1__us_axi_awqos ;
    wire [3:0]        w_net__AXI_Matrix_0__ds1_awqos ; 

    wire [2:0]        w_port__AXI_Matrix_0__ds1_awsize ;
    wire [2:0]        w_port__AXI_Protocol_Converter_1__us_axi_awsize ;
    wire [2:0]        w_net__AXI_Matrix_0__ds1_awsize ; 

    wire              w_port__AXI_Matrix_0__ds1_awvalid ;
    wire              w_port__AXI_Protocol_Converter_1__us_axi_awvalid ;
    wire              w_net__AXI_Matrix_0__ds1_awvalid ; 

    wire              w_port__AXI_Matrix_0__ds1_bready ;
    wire              w_port__AXI_Protocol_Converter_1__us_axi_bready ;
    wire              w_net__AXI_Matrix_0__ds1_bready ; 

    wire              w_port__AXI_Matrix_0__ds1_rready ;
    wire              w_port__AXI_Protocol_Converter_1__us_axi_rready ;
    wire              w_net__AXI_Matrix_0__ds1_rready ; 

    wire [31:0]       w_port__AXI_Matrix_0__ds1_wdata ;
    wire [31:0]       w_port__AXI_Protocol_Converter_1__us_axi_wdata ;
    wire [31:0]       w_net__AXI_Matrix_0__ds1_wdata ; 

    wire              w_port__AXI_Matrix_0__ds1_wlast ;
    wire              w_port__AXI_Protocol_Converter_1__us_axi_wlast ;
    wire              w_net__AXI_Matrix_0__ds1_wlast ; 

    wire [3:0]        w_port__AXI_Matrix_0__ds1_wstrb ;
    wire [3:0]        w_port__AXI_Protocol_Converter_1__us_axi_wstrb ;
    wire [3:0]        w_net__AXI_Matrix_0__ds1_wstrb ; 

    wire              w_port__AXI_Matrix_0__ds1_wvalid ;
    wire              w_port__AXI_Protocol_Converter_1__us_axi_wvalid ;
    wire              w_net__AXI_Matrix_0__ds1_wvalid ; 

    wire [31:0]       w_port__AXI_Matrix_0__ds2_araddr ;
    wire [31:0]       w_port__AXI_Protocol_Converter_2__us_axi_araddr ;
    wire [31:0]       w_net__AXI_Matrix_0__ds2_araddr ; 

    wire [1:0]        w_port__AXI_Matrix_0__ds2_arburst ;
    wire [1:0]        w_port__AXI_Protocol_Converter_2__us_axi_arburst ;
    wire [1:0]        w_net__AXI_Matrix_0__ds2_arburst ; 

    wire [3:0]        w_port__AXI_Matrix_0__ds2_arcache ;
    wire [3:0]        w_port__AXI_Protocol_Converter_2__us_axi_arcache ;
    wire [3:0]        w_net__AXI_Matrix_0__ds2_arcache ; 

    wire [1:0]        w_port__AXI_Matrix_0__ds2_arid ;
    wire [3:0]        w_port__AXI_Protocol_Converter_2__us_axi_arid ;
    wire [1:0]        w_net__AXI_Matrix_0__ds2_arid ; 

    wire [7:0]        w_port__AXI_Matrix_0__ds2_arlen ;
    wire [7:0]        w_port__AXI_Protocol_Converter_2__us_axi_arlen ;
    wire [7:0]        w_net__AXI_Matrix_0__ds2_arlen ; 

    wire [0:0]        w_port__AXI_Matrix_0__ds2_arlock ;
    wire [0:0]        w_port__AXI_Protocol_Converter_2__us_axi_arlock ;
    wire [0:0]        w_net__AXI_Matrix_0__ds2_arlock ; 

    wire [2:0]        w_port__AXI_Matrix_0__ds2_arprot ;
    wire [2:0]        w_port__AXI_Protocol_Converter_2__us_axi_arprot ;
    wire [2:0]        w_net__AXI_Matrix_0__ds2_arprot ; 

    wire [3:0]        w_port__AXI_Matrix_0__ds2_arqos ;
    wire [3:0]        w_port__AXI_Protocol_Converter_2__us_axi_arqos ;
    wire [3:0]        w_net__AXI_Matrix_0__ds2_arqos ; 

    wire [2:0]        w_port__AXI_Matrix_0__ds2_arsize ;
    wire [2:0]        w_port__AXI_Protocol_Converter_2__us_axi_arsize ;
    wire [2:0]        w_net__AXI_Matrix_0__ds2_arsize ; 

    wire              w_port__AXI_Matrix_0__ds2_arvalid ;
    wire              w_port__AXI_Protocol_Converter_2__us_axi_arvalid ;
    wire              w_net__AXI_Matrix_0__ds2_arvalid ; 

    wire [31:0]       w_port__AXI_Matrix_0__ds2_awaddr ;
    wire [31:0]       w_port__AXI_Protocol_Converter_2__us_axi_awaddr ;
    wire [31:0]       w_net__AXI_Matrix_0__ds2_awaddr ; 

    wire [1:0]        w_port__AXI_Matrix_0__ds2_awburst ;
    wire [1:0]        w_port__AXI_Protocol_Converter_2__us_axi_awburst ;
    wire [1:0]        w_net__AXI_Matrix_0__ds2_awburst ; 

    wire [3:0]        w_port__AXI_Matrix_0__ds2_awcache ;
    wire [3:0]        w_port__AXI_Protocol_Converter_2__us_axi_awcache ;
    wire [3:0]        w_net__AXI_Matrix_0__ds2_awcache ; 

    wire [1:0]        w_port__AXI_Matrix_0__ds2_awid ;
    wire [3:0]        w_port__AXI_Protocol_Converter_2__us_axi_awid ;
    wire [1:0]        w_net__AXI_Matrix_0__ds2_awid ; 

    wire [7:0]        w_port__AXI_Matrix_0__ds2_awlen ;
    wire [7:0]        w_port__AXI_Protocol_Converter_2__us_axi_awlen ;
    wire [7:0]        w_net__AXI_Matrix_0__ds2_awlen ; 

    wire [0:0]        w_port__AXI_Matrix_0__ds2_awlock ;
    wire [0:0]        w_port__AXI_Protocol_Converter_2__us_axi_awlock ;
    wire [0:0]        w_net__AXI_Matrix_0__ds2_awlock ; 

    wire [2:0]        w_port__AXI_Matrix_0__ds2_awprot ;
    wire [2:0]        w_port__AXI_Protocol_Converter_2__us_axi_awprot ;
    wire [2:0]        w_net__AXI_Matrix_0__ds2_awprot ; 

    wire [3:0]        w_port__AXI_Matrix_0__ds2_awqos ;
    wire [3:0]        w_port__AXI_Protocol_Converter_2__us_axi_awqos ;
    wire [3:0]        w_net__AXI_Matrix_0__ds2_awqos ; 

    wire [2:0]        w_port__AXI_Matrix_0__ds2_awsize ;
    wire [2:0]        w_port__AXI_Protocol_Converter_2__us_axi_awsize ;
    wire [2:0]        w_net__AXI_Matrix_0__ds2_awsize ; 

    wire              w_port__AXI_Matrix_0__ds2_awvalid ;
    wire              w_port__AXI_Protocol_Converter_2__us_axi_awvalid ;
    wire              w_net__AXI_Matrix_0__ds2_awvalid ; 

    wire              w_port__AXI_Matrix_0__ds2_bready ;
    wire              w_port__AXI_Protocol_Converter_2__us_axi_bready ;
    wire              w_net__AXI_Matrix_0__ds2_bready ; 

    wire              w_port__AXI_Matrix_0__ds2_rready ;
    wire              w_port__AXI_Protocol_Converter_2__us_axi_rready ;
    wire              w_net__AXI_Matrix_0__ds2_rready ; 

    wire [31:0]       w_port__AXI_Matrix_0__ds2_wdata ;
    wire [31:0]       w_port__AXI_Protocol_Converter_2__us_axi_wdata ;
    wire [31:0]       w_net__AXI_Matrix_0__ds2_wdata ; 

    wire              w_port__AXI_Matrix_0__ds2_wlast ;
    wire              w_port__AXI_Protocol_Converter_2__us_axi_wlast ;
    wire              w_net__AXI_Matrix_0__ds2_wlast ; 

    wire [3:0]        w_port__AXI_Matrix_0__ds2_wstrb ;
    wire [3:0]        w_port__AXI_Protocol_Converter_2__us_axi_wstrb ;
    wire [3:0]        w_net__AXI_Matrix_0__ds2_wstrb ; 

    wire              w_port__AXI_Matrix_0__ds2_wvalid ;
    wire              w_port__AXI_Protocol_Converter_2__us_axi_wvalid ;
    wire              w_net__AXI_Matrix_0__ds2_wvalid ; 

    wire              w_port__AXI_Matrix_0__us0_arready ;
    wire              w_port__ARM_Processor_System_0__master_gp0_axi_arready ;
    wire              w_net__AXI_Matrix_0__us0_arready ; 

    wire              w_port__AXI_Matrix_0__us0_awready ;
    wire              w_port__ARM_Processor_System_0__master_gp0_axi_awready ;
    wire              w_net__AXI_Matrix_0__us0_awready ; 

    wire [0:0]        w_port__AXI_Matrix_0__us0_bid ;
    wire [11:0]       w_port__ARM_Processor_System_0__master_gp0_axi_bid ;
    wire [0:0]        w_net__AXI_Matrix_0__us0_bid ; 

    wire [1:0]        w_port__AXI_Matrix_0__us0_bresp ;
    wire [1:0]        w_port__ARM_Processor_System_0__master_gp0_axi_bresp ;
    wire [1:0]        w_net__AXI_Matrix_0__us0_bresp ; 

    wire              w_port__AXI_Matrix_0__us0_bvalid ;
    wire              w_port__ARM_Processor_System_0__master_gp0_axi_bvalid ;
    wire              w_net__AXI_Matrix_0__us0_bvalid ; 

    wire [31:0]       w_port__AXI_Matrix_0__us0_rdata ;
    wire [31:0]       w_port__ARM_Processor_System_0__master_gp0_axi_rdata ;
    wire [31:0]       w_net__AXI_Matrix_0__us0_rdata ; 

    wire [0:0]        w_port__AXI_Matrix_0__us0_rid ;
    wire [11:0]       w_port__ARM_Processor_System_0__master_gp0_axi_rid ;
    wire [0:0]        w_net__AXI_Matrix_0__us0_rid ; 

    wire              w_port__AXI_Matrix_0__us0_rlast ;
    wire              w_port__ARM_Processor_System_0__master_gp0_axi_rlast ;
    wire              w_net__AXI_Matrix_0__us0_rlast ; 

    wire [1:0]        w_port__AXI_Matrix_0__us0_rresp ;
    wire [1:0]        w_port__ARM_Processor_System_0__master_gp0_axi_rresp ;
    wire [1:0]        w_net__AXI_Matrix_0__us0_rresp ; 

    wire              w_port__AXI_Matrix_0__us0_rvalid ;
    wire              w_port__ARM_Processor_System_0__master_gp0_axi_rvalid ;
    wire              w_net__AXI_Matrix_0__us0_rvalid ; 

    wire              w_port__AXI_Matrix_0__us0_wready ;
    wire              w_port__ARM_Processor_System_0__master_gp0_axi_wready ;
    wire              w_net__AXI_Matrix_0__us0_wready ; 

    wire [31:0]       w_port__AXI_Protocol_Converter_0__ds_axi_araddr ;
    wire [8:0]        w_port__AXI_GPIO_0__s_axi_araddr ;
    wire [31:0]       w_net__AXI_Protocol_Converter_0__ds_axi_araddr ; 

    wire              w_port__AXI_Protocol_Converter_0__ds_axi_arvalid ;
    wire              w_port__AXI_GPIO_0__s_axi_arvalid ;
    wire              w_net__AXI_Protocol_Converter_0__ds_axi_arvalid ; 

    wire [31:0]       w_port__AXI_Protocol_Converter_0__ds_axi_awaddr ;
    wire [8:0]        w_port__AXI_GPIO_0__s_axi_awaddr ;
    wire [31:0]       w_net__AXI_Protocol_Converter_0__ds_axi_awaddr ; 

    wire              w_port__AXI_Protocol_Converter_0__ds_axi_awvalid ;
    wire              w_port__AXI_GPIO_0__s_axi_awvalid ;
    wire              w_net__AXI_Protocol_Converter_0__ds_axi_awvalid ; 

    wire              w_port__AXI_Protocol_Converter_0__ds_axi_bready ;
    wire              w_port__AXI_GPIO_0__s_axi_bready ;
    wire              w_net__AXI_Protocol_Converter_0__ds_axi_bready ; 

    wire              w_port__AXI_Protocol_Converter_0__ds_axi_rready ;
    wire              w_port__AXI_GPIO_0__s_axi_rready ;
    wire              w_net__AXI_Protocol_Converter_0__ds_axi_rready ; 

    wire [31:0]       w_port__AXI_Protocol_Converter_0__ds_axi_wdata ;
    wire [31:0]       w_port__AXI_GPIO_0__s_axi_wdata ;
    wire [31:0]       w_net__AXI_Protocol_Converter_0__ds_axi_wdata ; 

    wire [3:0]        w_port__AXI_Protocol_Converter_0__ds_axi_wstrb ;
    wire [3:0]        w_port__AXI_GPIO_0__s_axi_wstrb ;
    wire [3:0]        w_net__AXI_Protocol_Converter_0__ds_axi_wstrb ; 

    wire              w_port__AXI_Protocol_Converter_0__ds_axi_wvalid ;
    wire              w_port__AXI_GPIO_0__s_axi_wvalid ;
    wire              w_net__AXI_Protocol_Converter_0__ds_axi_wvalid ; 

    wire              w_port__AXI_Protocol_Converter_0__us_axi_arready ;
    wire              w_port__AXI_Matrix_0__ds0_arready ;
    wire              w_net__AXI_Protocol_Converter_0__us_axi_arready ; 

    wire              w_port__AXI_Protocol_Converter_0__us_axi_awready ;
    wire              w_port__AXI_Matrix_0__ds0_awready ;
    wire              w_net__AXI_Protocol_Converter_0__us_axi_awready ; 

    wire [3:0]        w_port__AXI_Protocol_Converter_0__us_axi_bid ;
    wire [1:0]        w_port__AXI_Matrix_0__ds0_bid ;
    wire [3:0]        w_net__AXI_Protocol_Converter_0__us_axi_bid ; 

    wire [1:0]        w_port__AXI_Protocol_Converter_0__us_axi_bresp ;
    wire [1:0]        w_port__AXI_Matrix_0__ds0_bresp ;
    wire [1:0]        w_net__AXI_Protocol_Converter_0__us_axi_bresp ; 

    wire              w_port__AXI_Protocol_Converter_0__us_axi_bvalid ;
    wire              w_port__AXI_Matrix_0__ds0_bvalid ;
    wire              w_net__AXI_Protocol_Converter_0__us_axi_bvalid ; 

    wire [31:0]       w_port__AXI_Protocol_Converter_0__us_axi_rdata ;
    wire [31:0]       w_port__AXI_Matrix_0__ds0_rdata ;
    wire [31:0]       w_net__AXI_Protocol_Converter_0__us_axi_rdata ; 

    wire [3:0]        w_port__AXI_Protocol_Converter_0__us_axi_rid ;
    wire [1:0]        w_port__AXI_Matrix_0__ds0_rid ;
    wire [3:0]        w_net__AXI_Protocol_Converter_0__us_axi_rid ; 

    wire              w_port__AXI_Protocol_Converter_0__us_axi_rlast ;
    wire              w_port__AXI_Matrix_0__ds0_rlast ;
    wire              w_net__AXI_Protocol_Converter_0__us_axi_rlast ; 

    wire [1:0]        w_port__AXI_Protocol_Converter_0__us_axi_rresp ;
    wire [1:0]        w_port__AXI_Matrix_0__ds0_rresp ;
    wire [1:0]        w_net__AXI_Protocol_Converter_0__us_axi_rresp ; 

    wire              w_port__AXI_Protocol_Converter_0__us_axi_rvalid ;
    wire              w_port__AXI_Matrix_0__ds0_rvalid ;
    wire              w_net__AXI_Protocol_Converter_0__us_axi_rvalid ; 

    wire              w_port__AXI_Protocol_Converter_0__us_axi_wready ;
    wire              w_port__AXI_Matrix_0__ds0_wready ;
    wire              w_net__AXI_Protocol_Converter_0__us_axi_wready ; 

    wire [31:0]       w_port__AXI_Protocol_Converter_1__ds_axi_araddr ;
    wire [8:0]        w_port__AXI_GPIO_1__s_axi_araddr ;
    wire [31:0]       w_net__AXI_Protocol_Converter_1__ds_axi_araddr ; 

    wire              w_port__AXI_Protocol_Converter_1__ds_axi_arvalid ;
    wire              w_port__AXI_GPIO_1__s_axi_arvalid ;
    wire              w_net__AXI_Protocol_Converter_1__ds_axi_arvalid ; 

    wire [31:0]       w_port__AXI_Protocol_Converter_1__ds_axi_awaddr ;
    wire [8:0]        w_port__AXI_GPIO_1__s_axi_awaddr ;
    wire [31:0]       w_net__AXI_Protocol_Converter_1__ds_axi_awaddr ; 

    wire              w_port__AXI_Protocol_Converter_1__ds_axi_awvalid ;
    wire              w_port__AXI_GPIO_1__s_axi_awvalid ;
    wire              w_net__AXI_Protocol_Converter_1__ds_axi_awvalid ; 

    wire              w_port__AXI_Protocol_Converter_1__ds_axi_bready ;
    wire              w_port__AXI_GPIO_1__s_axi_bready ;
    wire              w_net__AXI_Protocol_Converter_1__ds_axi_bready ; 

    wire              w_port__AXI_Protocol_Converter_1__ds_axi_rready ;
    wire              w_port__AXI_GPIO_1__s_axi_rready ;
    wire              w_net__AXI_Protocol_Converter_1__ds_axi_rready ; 

    wire [31:0]       w_port__AXI_Protocol_Converter_1__ds_axi_wdata ;
    wire [31:0]       w_port__AXI_GPIO_1__s_axi_wdata ;
    wire [31:0]       w_net__AXI_Protocol_Converter_1__ds_axi_wdata ; 

    wire [3:0]        w_port__AXI_Protocol_Converter_1__ds_axi_wstrb ;
    wire [3:0]        w_port__AXI_GPIO_1__s_axi_wstrb ;
    wire [3:0]        w_net__AXI_Protocol_Converter_1__ds_axi_wstrb ; 

    wire              w_port__AXI_Protocol_Converter_1__ds_axi_wvalid ;
    wire              w_port__AXI_GPIO_1__s_axi_wvalid ;
    wire              w_net__AXI_Protocol_Converter_1__ds_axi_wvalid ; 

    wire              w_port__AXI_Protocol_Converter_1__us_axi_arready ;
    wire              w_port__AXI_Matrix_0__ds1_arready ;
    wire              w_net__AXI_Protocol_Converter_1__us_axi_arready ; 

    wire              w_port__AXI_Protocol_Converter_1__us_axi_awready ;
    wire              w_port__AXI_Matrix_0__ds1_awready ;
    wire              w_net__AXI_Protocol_Converter_1__us_axi_awready ; 

    wire [3:0]        w_port__AXI_Protocol_Converter_1__us_axi_bid ;
    wire [1:0]        w_port__AXI_Matrix_0__ds1_bid ;
    wire [3:0]        w_net__AXI_Protocol_Converter_1__us_axi_bid ; 

    wire [1:0]        w_port__AXI_Protocol_Converter_1__us_axi_bresp ;
    wire [1:0]        w_port__AXI_Matrix_0__ds1_bresp ;
    wire [1:0]        w_net__AXI_Protocol_Converter_1__us_axi_bresp ; 

    wire              w_port__AXI_Protocol_Converter_1__us_axi_bvalid ;
    wire              w_port__AXI_Matrix_0__ds1_bvalid ;
    wire              w_net__AXI_Protocol_Converter_1__us_axi_bvalid ; 

    wire [31:0]       w_port__AXI_Protocol_Converter_1__us_axi_rdata ;
    wire [31:0]       w_port__AXI_Matrix_0__ds1_rdata ;
    wire [31:0]       w_net__AXI_Protocol_Converter_1__us_axi_rdata ; 

    wire [3:0]        w_port__AXI_Protocol_Converter_1__us_axi_rid ;
    wire [1:0]        w_port__AXI_Matrix_0__ds1_rid ;
    wire [3:0]        w_net__AXI_Protocol_Converter_1__us_axi_rid ; 

    wire              w_port__AXI_Protocol_Converter_1__us_axi_rlast ;
    wire              w_port__AXI_Matrix_0__ds1_rlast ;
    wire              w_net__AXI_Protocol_Converter_1__us_axi_rlast ; 

    wire [1:0]        w_port__AXI_Protocol_Converter_1__us_axi_rresp ;
    wire [1:0]        w_port__AXI_Matrix_0__ds1_rresp ;
    wire [1:0]        w_net__AXI_Protocol_Converter_1__us_axi_rresp ; 

    wire              w_port__AXI_Protocol_Converter_1__us_axi_rvalid ;
    wire              w_port__AXI_Matrix_0__ds1_rvalid ;
    wire              w_net__AXI_Protocol_Converter_1__us_axi_rvalid ; 

    wire              w_port__AXI_Protocol_Converter_1__us_axi_wready ;
    wire              w_port__AXI_Matrix_0__ds1_wready ;
    wire              w_net__AXI_Protocol_Converter_1__us_axi_wready ; 

    wire [31:0]       w_port__AXI_Protocol_Converter_2__ds_axi_araddr ;
    wire [8:0]        w_port__axi_lite_pwm_0__s_axi_araddr ;
    wire [31:0]       w_net__AXI_Protocol_Converter_2__ds_axi_araddr ; 

    wire              w_port__AXI_Protocol_Converter_2__ds_axi_arvalid ;
    wire              w_port__axi_lite_pwm_0__s_axi_arvalid ;
    wire              w_net__AXI_Protocol_Converter_2__ds_axi_arvalid ; 

    wire [31:0]       w_port__AXI_Protocol_Converter_2__ds_axi_awaddr ;
    wire [8:0]        w_port__axi_lite_pwm_0__s_axi_awaddr ;
    wire [31:0]       w_net__AXI_Protocol_Converter_2__ds_axi_awaddr ; 

    wire              w_port__AXI_Protocol_Converter_2__ds_axi_awvalid ;
    wire              w_port__axi_lite_pwm_0__s_axi_awvalid ;
    wire              w_net__AXI_Protocol_Converter_2__ds_axi_awvalid ; 

    wire              w_port__AXI_Protocol_Converter_2__ds_axi_bready ;
    wire              w_port__axi_lite_pwm_0__s_axi_bready ;
    wire              w_net__AXI_Protocol_Converter_2__ds_axi_bready ; 

    wire              w_port__AXI_Protocol_Converter_2__ds_axi_rready ;
    wire              w_port__axi_lite_pwm_0__s_axi_rready ;
    wire              w_net__AXI_Protocol_Converter_2__ds_axi_rready ; 

    wire [31:0]       w_port__AXI_Protocol_Converter_2__ds_axi_wdata ;
    wire [31:0]       w_port__axi_lite_pwm_0__s_axi_wdata ;
    wire [31:0]       w_net__AXI_Protocol_Converter_2__ds_axi_wdata ; 

    wire [3:0]        w_port__AXI_Protocol_Converter_2__ds_axi_wstrb ;
    wire [3:0]        w_port__axi_lite_pwm_0__s_axi_wstrb ;
    wire [3:0]        w_net__AXI_Protocol_Converter_2__ds_axi_wstrb ; 

    wire              w_port__AXI_Protocol_Converter_2__ds_axi_wvalid ;
    wire              w_port__axi_lite_pwm_0__s_axi_wvalid ;
    wire              w_net__AXI_Protocol_Converter_2__ds_axi_wvalid ; 

    wire              w_port__AXI_Protocol_Converter_2__us_axi_arready ;
    wire              w_port__AXI_Matrix_0__ds2_arready ;
    wire              w_net__AXI_Protocol_Converter_2__us_axi_arready ; 

    wire              w_port__AXI_Protocol_Converter_2__us_axi_awready ;
    wire              w_port__AXI_Matrix_0__ds2_awready ;
    wire              w_net__AXI_Protocol_Converter_2__us_axi_awready ; 

    wire [3:0]        w_port__AXI_Protocol_Converter_2__us_axi_bid ;
    wire [1:0]        w_port__AXI_Matrix_0__ds2_bid ;
    wire [3:0]        w_net__AXI_Protocol_Converter_2__us_axi_bid ; 

    wire [1:0]        w_port__AXI_Protocol_Converter_2__us_axi_bresp ;
    wire [1:0]        w_port__AXI_Matrix_0__ds2_bresp ;
    wire [1:0]        w_net__AXI_Protocol_Converter_2__us_axi_bresp ; 

    wire              w_port__AXI_Protocol_Converter_2__us_axi_bvalid ;
    wire              w_port__AXI_Matrix_0__ds2_bvalid ;
    wire              w_net__AXI_Protocol_Converter_2__us_axi_bvalid ; 

    wire [31:0]       w_port__AXI_Protocol_Converter_2__us_axi_rdata ;
    wire [31:0]       w_port__AXI_Matrix_0__ds2_rdata ;
    wire [31:0]       w_net__AXI_Protocol_Converter_2__us_axi_rdata ; 

    wire [3:0]        w_port__AXI_Protocol_Converter_2__us_axi_rid ;
    wire [1:0]        w_port__AXI_Matrix_0__ds2_rid ;
    wire [3:0]        w_net__AXI_Protocol_Converter_2__us_axi_rid ; 

    wire              w_port__AXI_Protocol_Converter_2__us_axi_rlast ;
    wire              w_port__AXI_Matrix_0__ds2_rlast ;
    wire              w_net__AXI_Protocol_Converter_2__us_axi_rlast ; 

    wire [1:0]        w_port__AXI_Protocol_Converter_2__us_axi_rresp ;
    wire [1:0]        w_port__AXI_Matrix_0__ds2_rresp ;
    wire [1:0]        w_net__AXI_Protocol_Converter_2__us_axi_rresp ; 

    wire              w_port__AXI_Protocol_Converter_2__us_axi_rvalid ;
    wire              w_port__AXI_Matrix_0__ds2_rvalid ;
    wire              w_net__AXI_Protocol_Converter_2__us_axi_rvalid ; 

    wire              w_port__AXI_Protocol_Converter_2__us_axi_wready ;
    wire              w_port__AXI_Matrix_0__ds2_wready ;
    wire              w_net__AXI_Protocol_Converter_2__us_axi_wready ; 

    wire [0:0]        w_port__Constant_0__dout ;
    wire              w_port__Processor_System_Reset_0__pll_locked ;
    wire [0:0]        w_net__Constant_0__dout ; 

    wire [31:0]       w_port__uiFDMA_0__I_fdma_raddr ;
    wire [31:0]       w_net__I_fdma_raddr ; 

    wire              w_port__uiFDMA_0__I_fdma_rareq ;
    wire              w_net__I_fdma_rareq ; 

    wire              w_port__uiFDMA_0__I_fdma_rready ;
    wire              w_net__I_fdma_rready ; 

    wire [15:0]       w_port__uiFDMA_0__I_fdma_rsize ;
    wire [15:0]       w_net__I_fdma_rsize ; 

    wire [31:0]       w_port__uiFDMA_0__I_fdma_waddr ;
    wire [31:0]       w_net__I_fdma_waddr ; 

    wire              w_port__uiFDMA_0__I_fdma_wareq ;
    wire              w_net__I_fdma_wareq ; 

    wire [63:0]       w_port__uiFDMA_0__I_fdma_wdata ;
    wire [63:0]       w_net__I_fdma_wdata ; 

    wire              w_port__uiFDMA_0__I_fdma_wready ;
    wire              w_net__I_fdma_wready ; 

    wire [15:0]       w_port__uiFDMA_0__I_fdma_wsize ;
    wire [15:0]       w_net__I_fdma_wsize ; 

    wire              w_port__PWM_0__pwm_out ;
    wire              w_net__PWM_0__pwm_out ; 

    wire [1:0]        w_port__axi_lite_pwm_0__motor_dir ;
    wire [1:0]        w_net__axi_lite_pwm_0__motor_dir ; 

    wire              w_port__axi_lite_pwm_0__motor_enable ;
    wire              w_net__axi_lite_pwm_0__motor_enable ; 

    wire [2:0]        w_port__axi_lite_pwm_0__pwm_out ;
    wire [2:0]        w_net__axi_lite_pwm_0__pwm_out ; 

    wire              w_port__axi_lite_pwm_0__s_axi_arready ;
    wire              w_port__AXI_Protocol_Converter_2__ds_axi_arready ;
    wire              w_net__axi_lite_pwm_0__s_axi_arready ; 

    wire              w_port__axi_lite_pwm_0__s_axi_awready ;
    wire              w_port__AXI_Protocol_Converter_2__ds_axi_awready ;
    wire              w_net__axi_lite_pwm_0__s_axi_awready ; 

    wire [1:0]        w_port__axi_lite_pwm_0__s_axi_bresp ;
    wire [1:0]        w_port__AXI_Protocol_Converter_2__ds_axi_bresp ;
    wire [1:0]        w_net__axi_lite_pwm_0__s_axi_bresp ; 

    wire              w_port__axi_lite_pwm_0__s_axi_bvalid ;
    wire              w_port__AXI_Protocol_Converter_2__ds_axi_bvalid ;
    wire              w_net__axi_lite_pwm_0__s_axi_bvalid ; 

    wire [31:0]       w_port__axi_lite_pwm_0__s_axi_rdata ;
    wire [31:0]       w_port__AXI_Protocol_Converter_2__ds_axi_rdata ;
    wire [31:0]       w_net__axi_lite_pwm_0__s_axi_rdata ; 

    wire [1:0]        w_port__axi_lite_pwm_0__s_axi_rresp ;
    wire [1:0]        w_port__AXI_Protocol_Converter_2__ds_axi_rresp ;
    wire [1:0]        w_net__axi_lite_pwm_0__s_axi_rresp ; 

    wire              w_port__axi_lite_pwm_0__s_axi_rvalid ;
    wire              w_port__AXI_Protocol_Converter_2__ds_axi_rvalid ;
    wire              w_net__axi_lite_pwm_0__s_axi_rvalid ; 

    wire              w_port__axi_lite_pwm_0__s_axi_wready ;
    wire              w_port__AXI_Protocol_Converter_2__ds_axi_wready ;
    wire              w_net__axi_lite_pwm_0__s_axi_wready ; 

    wire              w_port__PWM_0__clk ;
    wire              w_net__pwm_clk ; 

    wire              w_port__PWM_0__rst_n ;
    wire              w_net__rst_n ; 

    wire [31:0]       w_port__uiFDMA_0__M_AXI_ARADDR ;
    wire [32:0]       w_port__ARM_Processor_System_0__slave_hp0_axi_araddr ;
    wire [31:0]       w_net__uiFDMA_0__M_AXI_ARADDR ; 

    wire [1:0]        w_port__uiFDMA_0__M_AXI_ARBURST ;
    wire [1:0]        w_port__ARM_Processor_System_0__slave_hp0_axi_arburst ;
    wire [1:0]        w_net__uiFDMA_0__M_AXI_ARBURST ; 

    wire [3:0]        w_port__uiFDMA_0__M_AXI_ARCACHE ;
    wire [3:0]        w_port__ARM_Processor_System_0__slave_hp0_axi_arcache ;
    wire [3:0]        w_net__uiFDMA_0__M_AXI_ARCACHE ; 

    wire [11:0]       w_port__uiFDMA_0__M_AXI_ARID ;
    wire [5:0]        w_port__ARM_Processor_System_0__slave_hp0_axi_arid ;
    wire [11:0]       w_net__uiFDMA_0__M_AXI_ARID ; 

    wire [7:0]        w_port__uiFDMA_0__M_AXI_ARLEN ;
    wire [3:0]        w_port__ARM_Processor_System_0__slave_hp0_axi_arlen ;
    wire [7:0]        w_net__uiFDMA_0__M_AXI_ARLEN ; 

    wire              w_port__uiFDMA_0__M_AXI_ARLOCK ;
    wire              w_port__ARM_Processor_System_0__slave_hp0_axi_arlock ;
    wire              w_net__uiFDMA_0__M_AXI_ARLOCK ; 

    wire [2:0]        w_port__uiFDMA_0__M_AXI_ARPROT ;
    wire [2:0]        w_port__ARM_Processor_System_0__slave_hp0_axi_arprot ;
    wire [2:0]        w_net__uiFDMA_0__M_AXI_ARPROT ; 

    wire [3:0]        w_port__uiFDMA_0__M_AXI_ARQOS ;
    wire [3:0]        w_port__ARM_Processor_System_0__slave_hp0_axi_arqos ;
    wire [3:0]        w_net__uiFDMA_0__M_AXI_ARQOS ; 

    wire [2:0]        w_port__uiFDMA_0__M_AXI_ARSIZE ;
    wire [1:0]        w_port__ARM_Processor_System_0__slave_hp0_axi_arsize ;
    wire [2:0]        w_net__uiFDMA_0__M_AXI_ARSIZE ; 

    wire              w_port__uiFDMA_0__M_AXI_ARVALID ;
    wire              w_port__ARM_Processor_System_0__slave_hp0_axi_arvalid ;
    wire              w_net__uiFDMA_0__M_AXI_ARVALID ; 

    wire [31:0]       w_port__uiFDMA_0__M_AXI_AWADDR ;
    wire [32:0]       w_port__ARM_Processor_System_0__slave_hp0_axi_awaddr ;
    wire [31:0]       w_net__uiFDMA_0__M_AXI_AWADDR ; 

    wire [1:0]        w_port__uiFDMA_0__M_AXI_AWBURST ;
    wire [1:0]        w_port__ARM_Processor_System_0__slave_hp0_axi_awburst ;
    wire [1:0]        w_net__uiFDMA_0__M_AXI_AWBURST ; 

    wire [3:0]        w_port__uiFDMA_0__M_AXI_AWCACHE ;
    wire [3:0]        w_port__ARM_Processor_System_0__slave_hp0_axi_awcache ;
    wire [3:0]        w_net__uiFDMA_0__M_AXI_AWCACHE ; 

    wire [11:0]       w_port__uiFDMA_0__M_AXI_AWID ;
    wire [5:0]        w_port__ARM_Processor_System_0__slave_hp0_axi_awid ;
    wire [11:0]       w_net__uiFDMA_0__M_AXI_AWID ; 

    wire [7:0]        w_port__uiFDMA_0__M_AXI_AWLEN ;
    wire [3:0]        w_port__ARM_Processor_System_0__slave_hp0_axi_awlen ;
    wire [7:0]        w_net__uiFDMA_0__M_AXI_AWLEN ; 

    wire              w_port__uiFDMA_0__M_AXI_AWLOCK ;
    wire              w_port__ARM_Processor_System_0__slave_hp0_axi_awlock ;
    wire              w_net__uiFDMA_0__M_AXI_AWLOCK ; 

    wire [2:0]        w_port__uiFDMA_0__M_AXI_AWPROT ;
    wire [2:0]        w_port__ARM_Processor_System_0__slave_hp0_axi_awprot ;
    wire [2:0]        w_net__uiFDMA_0__M_AXI_AWPROT ; 

    wire [3:0]        w_port__uiFDMA_0__M_AXI_AWQOS ;
    wire [3:0]        w_port__ARM_Processor_System_0__slave_hp0_axi_awqos ;
    wire [3:0]        w_net__uiFDMA_0__M_AXI_AWQOS ; 

    wire [2:0]        w_port__uiFDMA_0__M_AXI_AWSIZE ;
    wire [1:0]        w_port__ARM_Processor_System_0__slave_hp0_axi_awsize ;
    wire [2:0]        w_net__uiFDMA_0__M_AXI_AWSIZE ; 

    wire              w_port__uiFDMA_0__M_AXI_AWVALID ;
    wire              w_port__ARM_Processor_System_0__slave_hp0_axi_awvalid ;
    wire              w_net__uiFDMA_0__M_AXI_AWVALID ; 

    wire              w_port__uiFDMA_0__M_AXI_BREADY ;
    wire              w_port__ARM_Processor_System_0__slave_hp0_axi_bready ;
    wire              w_net__uiFDMA_0__M_AXI_BREADY ; 

    wire              w_port__uiFDMA_0__M_AXI_RREADY ;
    wire              w_port__ARM_Processor_System_0__slave_hp0_axi_rready ;
    wire              w_net__uiFDMA_0__M_AXI_RREADY ; 

    wire [63:0]       w_port__uiFDMA_0__M_AXI_WDATA ;
    wire [63:0]       w_port__ARM_Processor_System_0__slave_hp0_axi_wdata ;
    wire [63:0]       w_net__uiFDMA_0__M_AXI_WDATA ; 

    wire              w_port__uiFDMA_0__M_AXI_WLAST ;
    wire              w_port__ARM_Processor_System_0__slave_hp0_axi_wlast ;
    wire              w_net__uiFDMA_0__M_AXI_WLAST ; 

    wire [7:0]        w_port__uiFDMA_0__M_AXI_WSTRB ;
    wire [7:0]        w_port__ARM_Processor_System_0__slave_hp0_axi_wstrb ;
    wire [7:0]        w_net__uiFDMA_0__M_AXI_WSTRB ; 

    wire              w_port__uiFDMA_0__M_AXI_WVALID ;
    wire              w_port__ARM_Processor_System_0__slave_hp0_axi_wvalid ;
    wire              w_net__uiFDMA_0__M_AXI_WVALID ; 

    wire              w_port__uiFDMA_0__O_fdma_rbusy ;
    wire              w_net__uiFDMA_0__O_fdma_rbusy ; 

    wire [63:0]       w_port__uiFDMA_0__O_fdma_rdata ;
    wire [63:0]       w_net__uiFDMA_0__O_fdma_rdata ; 

    wire              w_port__uiFDMA_0__O_fdma_rvalid ;
    wire              w_net__uiFDMA_0__O_fdma_rvalid ; 

    wire              w_port__uiFDMA_0__O_fdma_wbusy ;
    wire              w_net__uiFDMA_0__O_fdma_wbusy ; 

    wire              w_port__uiFDMA_0__O_fdma_wvalid ;
    wire              w_net__uiFDMA_0__O_fdma_wvalid ; 








    assign w_net__ARM_Processor_System_0__master_gp0_axi_araddr = w_port__ARM_Processor_System_0__master_gp0_axi_araddr ;
    assign w_port__AXI_Matrix_0__us0_araddr = w_net__ARM_Processor_System_0__master_gp0_axi_araddr ;

    assign w_net__ARM_Processor_System_0__master_gp0_axi_arburst = w_port__ARM_Processor_System_0__master_gp0_axi_arburst ;
    assign w_port__AXI_Matrix_0__us0_arburst = w_net__ARM_Processor_System_0__master_gp0_axi_arburst ;

    assign w_net__ARM_Processor_System_0__master_gp0_axi_arcache = w_port__ARM_Processor_System_0__master_gp0_axi_arcache ;
    assign w_port__AXI_Matrix_0__us0_arcache = w_net__ARM_Processor_System_0__master_gp0_axi_arcache ;

    assign w_net__ARM_Processor_System_0__master_gp0_axi_arid = w_port__ARM_Processor_System_0__master_gp0_axi_arid ;
    assign w_port__AXI_Matrix_0__us0_arid = w_net__ARM_Processor_System_0__master_gp0_axi_arid ;

    assign w_net__ARM_Processor_System_0__master_gp0_axi_arlen = w_port__ARM_Processor_System_0__master_gp0_axi_arlen ;
    assign w_port__AXI_Matrix_0__us0_arlen = {4'b0,w_net__ARM_Processor_System_0__master_gp0_axi_arlen} ;

    assign w_net__ARM_Processor_System_0__master_gp0_axi_arlock = w_port__ARM_Processor_System_0__master_gp0_axi_arlock ;
    assign w_port__AXI_Matrix_0__us0_arlock = w_net__ARM_Processor_System_0__master_gp0_axi_arlock ;

    assign w_net__ARM_Processor_System_0__master_gp0_axi_arprot = w_port__ARM_Processor_System_0__master_gp0_axi_arprot ;
    assign w_port__AXI_Matrix_0__us0_arprot = w_net__ARM_Processor_System_0__master_gp0_axi_arprot ;

    assign w_net__ARM_Processor_System_0__master_gp0_axi_arsize = w_port__ARM_Processor_System_0__master_gp0_axi_arsize ;
    assign w_port__AXI_Matrix_0__us0_arsize = {1'b0,w_net__ARM_Processor_System_0__master_gp0_axi_arsize} ;

    assign w_net__ARM_Processor_System_0__master_gp0_axi_arvalid = w_port__ARM_Processor_System_0__master_gp0_axi_arvalid ;
    assign w_port__AXI_Matrix_0__us0_arvalid = w_net__ARM_Processor_System_0__master_gp0_axi_arvalid ;

    assign w_net__ARM_Processor_System_0__master_gp0_axi_awaddr = w_port__ARM_Processor_System_0__master_gp0_axi_awaddr ;
    assign w_port__AXI_Matrix_0__us0_awaddr = w_net__ARM_Processor_System_0__master_gp0_axi_awaddr ;

    assign w_net__ARM_Processor_System_0__master_gp0_axi_awburst = w_port__ARM_Processor_System_0__master_gp0_axi_awburst ;
    assign w_port__AXI_Matrix_0__us0_awburst = w_net__ARM_Processor_System_0__master_gp0_axi_awburst ;

    assign w_net__ARM_Processor_System_0__master_gp0_axi_awcache = w_port__ARM_Processor_System_0__master_gp0_axi_awcache ;
    assign w_port__AXI_Matrix_0__us0_awcache = w_net__ARM_Processor_System_0__master_gp0_axi_awcache ;

    assign w_net__ARM_Processor_System_0__master_gp0_axi_awid = w_port__ARM_Processor_System_0__master_gp0_axi_awid ;
    assign w_port__AXI_Matrix_0__us0_awid = w_net__ARM_Processor_System_0__master_gp0_axi_awid ;

    assign w_net__ARM_Processor_System_0__master_gp0_axi_awlen = w_port__ARM_Processor_System_0__master_gp0_axi_awlen ;
    assign w_port__AXI_Matrix_0__us0_awlen = {4'b0,w_net__ARM_Processor_System_0__master_gp0_axi_awlen} ;

    assign w_net__ARM_Processor_System_0__master_gp0_axi_awlock = w_port__ARM_Processor_System_0__master_gp0_axi_awlock ;
    assign w_port__AXI_Matrix_0__us0_awlock = w_net__ARM_Processor_System_0__master_gp0_axi_awlock ;

    assign w_net__ARM_Processor_System_0__master_gp0_axi_awprot = w_port__ARM_Processor_System_0__master_gp0_axi_awprot ;
    assign w_port__AXI_Matrix_0__us0_awprot = w_net__ARM_Processor_System_0__master_gp0_axi_awprot ;

    assign w_net__ARM_Processor_System_0__master_gp0_axi_awsize = w_port__ARM_Processor_System_0__master_gp0_axi_awsize ;
    assign w_port__AXI_Matrix_0__us0_awsize = {1'b0,w_net__ARM_Processor_System_0__master_gp0_axi_awsize} ;

    assign w_net__ARM_Processor_System_0__master_gp0_axi_awvalid = w_port__ARM_Processor_System_0__master_gp0_axi_awvalid ;
    assign w_port__AXI_Matrix_0__us0_awvalid = w_net__ARM_Processor_System_0__master_gp0_axi_awvalid ;

    assign w_net__ARM_Processor_System_0__master_gp0_axi_bready = w_port__ARM_Processor_System_0__master_gp0_axi_bready ;
    assign w_port__AXI_Matrix_0__us0_bready = w_net__ARM_Processor_System_0__master_gp0_axi_bready ;

    assign w_net__ARM_Processor_System_0__master_gp0_axi_rready = w_port__ARM_Processor_System_0__master_gp0_axi_rready ;
    assign w_port__AXI_Matrix_0__us0_rready = w_net__ARM_Processor_System_0__master_gp0_axi_rready ;

    assign w_net__ARM_Processor_System_0__master_gp0_axi_wdata = w_port__ARM_Processor_System_0__master_gp0_axi_wdata ;
    assign w_port__AXI_Matrix_0__us0_wdata = w_net__ARM_Processor_System_0__master_gp0_axi_wdata ;

    assign w_net__ARM_Processor_System_0__master_gp0_axi_wlast = w_port__ARM_Processor_System_0__master_gp0_axi_wlast ;
    assign w_port__AXI_Matrix_0__us0_wlast = w_net__ARM_Processor_System_0__master_gp0_axi_wlast ;

    assign w_net__ARM_Processor_System_0__master_gp0_axi_wstrb = w_port__ARM_Processor_System_0__master_gp0_axi_wstrb ;
    assign w_port__AXI_Matrix_0__us0_wstrb = w_net__ARM_Processor_System_0__master_gp0_axi_wstrb ;

    assign w_net__ARM_Processor_System_0__master_gp0_axi_wvalid = w_port__ARM_Processor_System_0__master_gp0_axi_wvalid ;
    assign w_port__AXI_Matrix_0__us0_wvalid = w_net__ARM_Processor_System_0__master_gp0_axi_wvalid ;

    assign w_net__ARM_Processor_System_0__p2f_clk0 = w_port__ARM_Processor_System_0__p2f_clk0 ;
    assign p2f_clk0 = w_net__ARM_Processor_System_0__p2f_clk0 ;
    assign w_port__ARM_Processor_System_0__slave_hp0_axi_aclk = w_net__ARM_Processor_System_0__p2f_clk0 ;
    assign w_port__uiFDMA_0__M_AXI_ACLK = w_net__ARM_Processor_System_0__p2f_clk0 ;
    assign w_port__ARM_Processor_System_0__master_gp0_axi_aclk = w_net__ARM_Processor_System_0__p2f_clk0 ;
    assign w_port__Processor_System_Reset_0__clk = w_net__ARM_Processor_System_0__p2f_clk0 ;

    assign w_net__ARM_Processor_System_0__p2f_clk1 = w_port__ARM_Processor_System_0__p2f_clk1 ;
    assign w_port__AXI_Matrix_0__aclk = w_net__ARM_Processor_System_0__p2f_clk1 ;
    assign w_port__AXI_Protocol_Converter_0__aclk = w_net__ARM_Processor_System_0__p2f_clk1 ;
    assign w_port__AXI_Protocol_Converter_1__aclk = w_net__ARM_Processor_System_0__p2f_clk1 ;
    assign w_port__AXI_GPIO_0__s_axi_aclk = w_net__ARM_Processor_System_0__p2f_clk1 ;
    assign w_port__AXI_GPIO_1__s_axi_aclk = w_net__ARM_Processor_System_0__p2f_clk1 ;
    assign w_port__AXI_Protocol_Converter_2__aclk = w_net__ARM_Processor_System_0__p2f_clk1 ;
    assign w_port__axi_lite_pwm_0__s_axi_aclk = w_net__ARM_Processor_System_0__p2f_clk1 ;

    assign w_net__ARM_Processor_System_0__p2f_rst0_n = w_port__ARM_Processor_System_0__p2f_rst0_n ;
    assign p2f_rst0_n = w_net__ARM_Processor_System_0__p2f_rst0_n ;
    assign w_port__uiFDMA_0__M_AXI_ARESETN = w_net__ARM_Processor_System_0__p2f_rst0_n ;
    assign w_port__AXI_GPIO_0__s_axi_aresetn = w_net__ARM_Processor_System_0__p2f_rst0_n ;
    assign w_port__AXI_Protocol_Converter_0__aresetn = w_net__ARM_Processor_System_0__p2f_rst0_n ;
    assign w_port__AXI_Protocol_Converter_1__aresetn = w_net__ARM_Processor_System_0__p2f_rst0_n ;
    assign w_port__AXI_GPIO_1__s_axi_aresetn = w_net__ARM_Processor_System_0__p2f_rst0_n ;
    assign w_port__AXI_Matrix_0__aresetn = w_net__ARM_Processor_System_0__p2f_rst0_n ;
    assign w_port__Processor_System_Reset_0__external_reset = w_net__ARM_Processor_System_0__p2f_rst0_n ;
    assign w_port__AXI_Protocol_Converter_2__aresetn = w_net__ARM_Processor_System_0__p2f_rst0_n ;
    assign w_port__axi_lite_pwm_0__s_axi_aresetn = w_net__ARM_Processor_System_0__p2f_rst0_n ;

    assign w_net__ARM_Processor_System_0__slave_hp0_axi_arready = w_port__ARM_Processor_System_0__slave_hp0_axi_arready ;
    assign w_port__uiFDMA_0__M_AXI_ARREADY = w_net__ARM_Processor_System_0__slave_hp0_axi_arready ;

    assign w_net__ARM_Processor_System_0__slave_hp0_axi_awready = w_port__ARM_Processor_System_0__slave_hp0_axi_awready ;
    assign w_port__uiFDMA_0__M_AXI_AWREADY = w_net__ARM_Processor_System_0__slave_hp0_axi_awready ;

    assign w_net__ARM_Processor_System_0__slave_hp0_axi_bid = w_port__ARM_Processor_System_0__slave_hp0_axi_bid ;
    assign w_port__uiFDMA_0__M_AXI_BID = {6'b0,w_net__ARM_Processor_System_0__slave_hp0_axi_bid} ;

    assign w_net__ARM_Processor_System_0__slave_hp0_axi_bresp = w_port__ARM_Processor_System_0__slave_hp0_axi_bresp ;
    assign w_port__uiFDMA_0__M_AXI_BRESP = w_net__ARM_Processor_System_0__slave_hp0_axi_bresp ;

    assign w_net__ARM_Processor_System_0__slave_hp0_axi_bvalid = w_port__ARM_Processor_System_0__slave_hp0_axi_bvalid ;
    assign w_port__uiFDMA_0__M_AXI_BVALID = w_net__ARM_Processor_System_0__slave_hp0_axi_bvalid ;

    assign w_net__ARM_Processor_System_0__slave_hp0_axi_rdata = w_port__ARM_Processor_System_0__slave_hp0_axi_rdata ;
    assign w_port__uiFDMA_0__M_AXI_RDATA = w_net__ARM_Processor_System_0__slave_hp0_axi_rdata ;

    assign w_net__ARM_Processor_System_0__slave_hp0_axi_rid = w_port__ARM_Processor_System_0__slave_hp0_axi_rid ;
    assign w_port__uiFDMA_0__M_AXI_RID = {6'b0,w_net__ARM_Processor_System_0__slave_hp0_axi_rid} ;

    assign w_net__ARM_Processor_System_0__slave_hp0_axi_rlast = w_port__ARM_Processor_System_0__slave_hp0_axi_rlast ;
    assign w_port__uiFDMA_0__M_AXI_RLAST = w_net__ARM_Processor_System_0__slave_hp0_axi_rlast ;

    assign w_net__ARM_Processor_System_0__slave_hp0_axi_rresp = w_port__ARM_Processor_System_0__slave_hp0_axi_rresp ;
    assign w_port__uiFDMA_0__M_AXI_RRESP = w_net__ARM_Processor_System_0__slave_hp0_axi_rresp ;

    assign w_net__ARM_Processor_System_0__slave_hp0_axi_rvalid = w_port__ARM_Processor_System_0__slave_hp0_axi_rvalid ;
    assign w_port__uiFDMA_0__M_AXI_RVALID = w_net__ARM_Processor_System_0__slave_hp0_axi_rvalid ;

    assign w_net__ARM_Processor_System_0__slave_hp0_axi_wready = w_port__ARM_Processor_System_0__slave_hp0_axi_wready ;
    assign w_port__uiFDMA_0__M_AXI_WREADY = w_net__ARM_Processor_System_0__slave_hp0_axi_wready ;

    assign w_net__AXI_GPIO_0__gpio_io_o = w_port__AXI_GPIO_0__gpio_io_o ;
    assign code_driver = w_net__AXI_GPIO_0__gpio_io_o ;

    assign w_net__AXI_GPIO_0__s_axi_arready = w_port__AXI_GPIO_0__s_axi_arready ;
    assign w_port__AXI_Protocol_Converter_0__ds_axi_arready = w_net__AXI_GPIO_0__s_axi_arready ;

    assign w_net__AXI_GPIO_0__s_axi_awready = w_port__AXI_GPIO_0__s_axi_awready ;
    assign w_port__AXI_Protocol_Converter_0__ds_axi_awready = w_net__AXI_GPIO_0__s_axi_awready ;

    assign w_net__AXI_GPIO_0__s_axi_bresp = w_port__AXI_GPIO_0__s_axi_bresp ;
    assign w_port__AXI_Protocol_Converter_0__ds_axi_bresp = w_net__AXI_GPIO_0__s_axi_bresp ;

    assign w_net__AXI_GPIO_0__s_axi_bvalid = w_port__AXI_GPIO_0__s_axi_bvalid ;
    assign w_port__AXI_Protocol_Converter_0__ds_axi_bvalid = w_net__AXI_GPIO_0__s_axi_bvalid ;

    assign w_net__AXI_GPIO_0__s_axi_rdata = w_port__AXI_GPIO_0__s_axi_rdata ;
    assign w_port__AXI_Protocol_Converter_0__ds_axi_rdata = w_net__AXI_GPIO_0__s_axi_rdata ;

    assign w_net__AXI_GPIO_0__s_axi_rresp = w_port__AXI_GPIO_0__s_axi_rresp ;
    assign w_port__AXI_Protocol_Converter_0__ds_axi_rresp = w_net__AXI_GPIO_0__s_axi_rresp ;

    assign w_net__AXI_GPIO_0__s_axi_rvalid = w_port__AXI_GPIO_0__s_axi_rvalid ;
    assign w_port__AXI_Protocol_Converter_0__ds_axi_rvalid = w_net__AXI_GPIO_0__s_axi_rvalid ;

    assign w_net__AXI_GPIO_0__s_axi_wready = w_port__AXI_GPIO_0__s_axi_wready ;
    assign w_port__AXI_Protocol_Converter_0__ds_axi_wready = w_net__AXI_GPIO_0__s_axi_wready ;

    assign w_net__AXI_GPIO_1__gpio2_io_o = w_port__AXI_GPIO_1__gpio2_io_o ;
    assign w_port__PWM_0__RELOAD_VALUE = w_net__AXI_GPIO_1__gpio2_io_o ;

    assign w_net__AXI_GPIO_1__gpio_io_o = w_port__AXI_GPIO_1__gpio_io_o ;
    assign w_port__PWM_0__DUTY_VALUE = w_net__AXI_GPIO_1__gpio_io_o ;

    assign w_net__AXI_GPIO_1__s_axi_arready = w_port__AXI_GPIO_1__s_axi_arready ;
    assign w_port__AXI_Protocol_Converter_1__ds_axi_arready = w_net__AXI_GPIO_1__s_axi_arready ;

    assign w_net__AXI_GPIO_1__s_axi_awready = w_port__AXI_GPIO_1__s_axi_awready ;
    assign w_port__AXI_Protocol_Converter_1__ds_axi_awready = w_net__AXI_GPIO_1__s_axi_awready ;

    assign w_net__AXI_GPIO_1__s_axi_bresp = w_port__AXI_GPIO_1__s_axi_bresp ;
    assign w_port__AXI_Protocol_Converter_1__ds_axi_bresp = w_net__AXI_GPIO_1__s_axi_bresp ;

    assign w_net__AXI_GPIO_1__s_axi_bvalid = w_port__AXI_GPIO_1__s_axi_bvalid ;
    assign w_port__AXI_Protocol_Converter_1__ds_axi_bvalid = w_net__AXI_GPIO_1__s_axi_bvalid ;

    assign w_net__AXI_GPIO_1__s_axi_rdata = w_port__AXI_GPIO_1__s_axi_rdata ;
    assign w_port__AXI_Protocol_Converter_1__ds_axi_rdata = w_net__AXI_GPIO_1__s_axi_rdata ;

    assign w_net__AXI_GPIO_1__s_axi_rresp = w_port__AXI_GPIO_1__s_axi_rresp ;
    assign w_port__AXI_Protocol_Converter_1__ds_axi_rresp = w_net__AXI_GPIO_1__s_axi_rresp ;

    assign w_net__AXI_GPIO_1__s_axi_rvalid = w_port__AXI_GPIO_1__s_axi_rvalid ;
    assign w_port__AXI_Protocol_Converter_1__ds_axi_rvalid = w_net__AXI_GPIO_1__s_axi_rvalid ;

    assign w_net__AXI_GPIO_1__s_axi_wready = w_port__AXI_GPIO_1__s_axi_wready ;
    assign w_port__AXI_Protocol_Converter_1__ds_axi_wready = w_net__AXI_GPIO_1__s_axi_wready ;

    assign w_net__AXI_Matrix_0__ds0_araddr = w_port__AXI_Matrix_0__ds0_araddr ;
    assign w_port__AXI_Protocol_Converter_0__us_axi_araddr = w_net__AXI_Matrix_0__ds0_araddr ;

    assign w_net__AXI_Matrix_0__ds0_arburst = w_port__AXI_Matrix_0__ds0_arburst ;
    assign w_port__AXI_Protocol_Converter_0__us_axi_arburst = w_net__AXI_Matrix_0__ds0_arburst ;

    assign w_net__AXI_Matrix_0__ds0_arcache = w_port__AXI_Matrix_0__ds0_arcache ;
    assign w_port__AXI_Protocol_Converter_0__us_axi_arcache = w_net__AXI_Matrix_0__ds0_arcache ;

    assign w_net__AXI_Matrix_0__ds0_arid = w_port__AXI_Matrix_0__ds0_arid ;
    assign w_port__AXI_Protocol_Converter_0__us_axi_arid = {2'b0,w_net__AXI_Matrix_0__ds0_arid} ;

    assign w_net__AXI_Matrix_0__ds0_arlen = w_port__AXI_Matrix_0__ds0_arlen ;
    assign w_port__AXI_Protocol_Converter_0__us_axi_arlen = w_net__AXI_Matrix_0__ds0_arlen ;

    assign w_net__AXI_Matrix_0__ds0_arlock = w_port__AXI_Matrix_0__ds0_arlock ;
    assign w_port__AXI_Protocol_Converter_0__us_axi_arlock = w_net__AXI_Matrix_0__ds0_arlock ;

    assign w_net__AXI_Matrix_0__ds0_arprot = w_port__AXI_Matrix_0__ds0_arprot ;
    assign w_port__AXI_Protocol_Converter_0__us_axi_arprot = w_net__AXI_Matrix_0__ds0_arprot ;

    assign w_net__AXI_Matrix_0__ds0_arqos = w_port__AXI_Matrix_0__ds0_arqos ;
    assign w_port__AXI_Protocol_Converter_0__us_axi_arqos = w_net__AXI_Matrix_0__ds0_arqos ;

    assign w_net__AXI_Matrix_0__ds0_arsize = w_port__AXI_Matrix_0__ds0_arsize ;
    assign w_port__AXI_Protocol_Converter_0__us_axi_arsize = w_net__AXI_Matrix_0__ds0_arsize ;

    assign w_net__AXI_Matrix_0__ds0_arvalid = w_port__AXI_Matrix_0__ds0_arvalid ;
    assign w_port__AXI_Protocol_Converter_0__us_axi_arvalid = w_net__AXI_Matrix_0__ds0_arvalid ;

    assign w_net__AXI_Matrix_0__ds0_awaddr = w_port__AXI_Matrix_0__ds0_awaddr ;
    assign w_port__AXI_Protocol_Converter_0__us_axi_awaddr = w_net__AXI_Matrix_0__ds0_awaddr ;

    assign w_net__AXI_Matrix_0__ds0_awburst = w_port__AXI_Matrix_0__ds0_awburst ;
    assign w_port__AXI_Protocol_Converter_0__us_axi_awburst = w_net__AXI_Matrix_0__ds0_awburst ;

    assign w_net__AXI_Matrix_0__ds0_awcache = w_port__AXI_Matrix_0__ds0_awcache ;
    assign w_port__AXI_Protocol_Converter_0__us_axi_awcache = w_net__AXI_Matrix_0__ds0_awcache ;

    assign w_net__AXI_Matrix_0__ds0_awid = w_port__AXI_Matrix_0__ds0_awid ;
    assign w_port__AXI_Protocol_Converter_0__us_axi_awid = {2'b0,w_net__AXI_Matrix_0__ds0_awid} ;

    assign w_net__AXI_Matrix_0__ds0_awlen = w_port__AXI_Matrix_0__ds0_awlen ;
    assign w_port__AXI_Protocol_Converter_0__us_axi_awlen = w_net__AXI_Matrix_0__ds0_awlen ;

    assign w_net__AXI_Matrix_0__ds0_awlock = w_port__AXI_Matrix_0__ds0_awlock ;
    assign w_port__AXI_Protocol_Converter_0__us_axi_awlock = w_net__AXI_Matrix_0__ds0_awlock ;

    assign w_net__AXI_Matrix_0__ds0_awprot = w_port__AXI_Matrix_0__ds0_awprot ;
    assign w_port__AXI_Protocol_Converter_0__us_axi_awprot = w_net__AXI_Matrix_0__ds0_awprot ;

    assign w_net__AXI_Matrix_0__ds0_awqos = w_port__AXI_Matrix_0__ds0_awqos ;
    assign w_port__AXI_Protocol_Converter_0__us_axi_awqos = w_net__AXI_Matrix_0__ds0_awqos ;

    assign w_net__AXI_Matrix_0__ds0_awsize = w_port__AXI_Matrix_0__ds0_awsize ;
    assign w_port__AXI_Protocol_Converter_0__us_axi_awsize = w_net__AXI_Matrix_0__ds0_awsize ;

    assign w_net__AXI_Matrix_0__ds0_awvalid = w_port__AXI_Matrix_0__ds0_awvalid ;
    assign w_port__AXI_Protocol_Converter_0__us_axi_awvalid = w_net__AXI_Matrix_0__ds0_awvalid ;

    assign w_net__AXI_Matrix_0__ds0_bready = w_port__AXI_Matrix_0__ds0_bready ;
    assign w_port__AXI_Protocol_Converter_0__us_axi_bready = w_net__AXI_Matrix_0__ds0_bready ;

    assign w_net__AXI_Matrix_0__ds0_rready = w_port__AXI_Matrix_0__ds0_rready ;
    assign w_port__AXI_Protocol_Converter_0__us_axi_rready = w_net__AXI_Matrix_0__ds0_rready ;

    assign w_net__AXI_Matrix_0__ds0_wdata = w_port__AXI_Matrix_0__ds0_wdata ;
    assign w_port__AXI_Protocol_Converter_0__us_axi_wdata = w_net__AXI_Matrix_0__ds0_wdata ;

    assign w_net__AXI_Matrix_0__ds0_wlast = w_port__AXI_Matrix_0__ds0_wlast ;
    assign w_port__AXI_Protocol_Converter_0__us_axi_wlast = w_net__AXI_Matrix_0__ds0_wlast ;

    assign w_net__AXI_Matrix_0__ds0_wstrb = w_port__AXI_Matrix_0__ds0_wstrb ;
    assign w_port__AXI_Protocol_Converter_0__us_axi_wstrb = w_net__AXI_Matrix_0__ds0_wstrb ;

    assign w_net__AXI_Matrix_0__ds0_wvalid = w_port__AXI_Matrix_0__ds0_wvalid ;
    assign w_port__AXI_Protocol_Converter_0__us_axi_wvalid = w_net__AXI_Matrix_0__ds0_wvalid ;

    assign w_net__AXI_Matrix_0__ds1_araddr = w_port__AXI_Matrix_0__ds1_araddr ;
    assign w_port__AXI_Protocol_Converter_1__us_axi_araddr = w_net__AXI_Matrix_0__ds1_araddr ;

    assign w_net__AXI_Matrix_0__ds1_arburst = w_port__AXI_Matrix_0__ds1_arburst ;
    assign w_port__AXI_Protocol_Converter_1__us_axi_arburst = w_net__AXI_Matrix_0__ds1_arburst ;

    assign w_net__AXI_Matrix_0__ds1_arcache = w_port__AXI_Matrix_0__ds1_arcache ;
    assign w_port__AXI_Protocol_Converter_1__us_axi_arcache = w_net__AXI_Matrix_0__ds1_arcache ;

    assign w_net__AXI_Matrix_0__ds1_arid = w_port__AXI_Matrix_0__ds1_arid ;
    assign w_port__AXI_Protocol_Converter_1__us_axi_arid = {2'b0,w_net__AXI_Matrix_0__ds1_arid} ;

    assign w_net__AXI_Matrix_0__ds1_arlen = w_port__AXI_Matrix_0__ds1_arlen ;
    assign w_port__AXI_Protocol_Converter_1__us_axi_arlen = w_net__AXI_Matrix_0__ds1_arlen ;

    assign w_net__AXI_Matrix_0__ds1_arlock = w_port__AXI_Matrix_0__ds1_arlock ;
    assign w_port__AXI_Protocol_Converter_1__us_axi_arlock = w_net__AXI_Matrix_0__ds1_arlock ;

    assign w_net__AXI_Matrix_0__ds1_arprot = w_port__AXI_Matrix_0__ds1_arprot ;
    assign w_port__AXI_Protocol_Converter_1__us_axi_arprot = w_net__AXI_Matrix_0__ds1_arprot ;

    assign w_net__AXI_Matrix_0__ds1_arqos = w_port__AXI_Matrix_0__ds1_arqos ;
    assign w_port__AXI_Protocol_Converter_1__us_axi_arqos = w_net__AXI_Matrix_0__ds1_arqos ;

    assign w_net__AXI_Matrix_0__ds1_arsize = w_port__AXI_Matrix_0__ds1_arsize ;
    assign w_port__AXI_Protocol_Converter_1__us_axi_arsize = w_net__AXI_Matrix_0__ds1_arsize ;

    assign w_net__AXI_Matrix_0__ds1_arvalid = w_port__AXI_Matrix_0__ds1_arvalid ;
    assign w_port__AXI_Protocol_Converter_1__us_axi_arvalid = w_net__AXI_Matrix_0__ds1_arvalid ;

    assign w_net__AXI_Matrix_0__ds1_awaddr = w_port__AXI_Matrix_0__ds1_awaddr ;
    assign w_port__AXI_Protocol_Converter_1__us_axi_awaddr = w_net__AXI_Matrix_0__ds1_awaddr ;

    assign w_net__AXI_Matrix_0__ds1_awburst = w_port__AXI_Matrix_0__ds1_awburst ;
    assign w_port__AXI_Protocol_Converter_1__us_axi_awburst = w_net__AXI_Matrix_0__ds1_awburst ;

    assign w_net__AXI_Matrix_0__ds1_awcache = w_port__AXI_Matrix_0__ds1_awcache ;
    assign w_port__AXI_Protocol_Converter_1__us_axi_awcache = w_net__AXI_Matrix_0__ds1_awcache ;

    assign w_net__AXI_Matrix_0__ds1_awid = w_port__AXI_Matrix_0__ds1_awid ;
    assign w_port__AXI_Protocol_Converter_1__us_axi_awid = {2'b0,w_net__AXI_Matrix_0__ds1_awid} ;

    assign w_net__AXI_Matrix_0__ds1_awlen = w_port__AXI_Matrix_0__ds1_awlen ;
    assign w_port__AXI_Protocol_Converter_1__us_axi_awlen = w_net__AXI_Matrix_0__ds1_awlen ;

    assign w_net__AXI_Matrix_0__ds1_awlock = w_port__AXI_Matrix_0__ds1_awlock ;
    assign w_port__AXI_Protocol_Converter_1__us_axi_awlock = w_net__AXI_Matrix_0__ds1_awlock ;

    assign w_net__AXI_Matrix_0__ds1_awprot = w_port__AXI_Matrix_0__ds1_awprot ;
    assign w_port__AXI_Protocol_Converter_1__us_axi_awprot = w_net__AXI_Matrix_0__ds1_awprot ;

    assign w_net__AXI_Matrix_0__ds1_awqos = w_port__AXI_Matrix_0__ds1_awqos ;
    assign w_port__AXI_Protocol_Converter_1__us_axi_awqos = w_net__AXI_Matrix_0__ds1_awqos ;

    assign w_net__AXI_Matrix_0__ds1_awsize = w_port__AXI_Matrix_0__ds1_awsize ;
    assign w_port__AXI_Protocol_Converter_1__us_axi_awsize = w_net__AXI_Matrix_0__ds1_awsize ;

    assign w_net__AXI_Matrix_0__ds1_awvalid = w_port__AXI_Matrix_0__ds1_awvalid ;
    assign w_port__AXI_Protocol_Converter_1__us_axi_awvalid = w_net__AXI_Matrix_0__ds1_awvalid ;

    assign w_net__AXI_Matrix_0__ds1_bready = w_port__AXI_Matrix_0__ds1_bready ;
    assign w_port__AXI_Protocol_Converter_1__us_axi_bready = w_net__AXI_Matrix_0__ds1_bready ;

    assign w_net__AXI_Matrix_0__ds1_rready = w_port__AXI_Matrix_0__ds1_rready ;
    assign w_port__AXI_Protocol_Converter_1__us_axi_rready = w_net__AXI_Matrix_0__ds1_rready ;

    assign w_net__AXI_Matrix_0__ds1_wdata = w_port__AXI_Matrix_0__ds1_wdata ;
    assign w_port__AXI_Protocol_Converter_1__us_axi_wdata = w_net__AXI_Matrix_0__ds1_wdata ;

    assign w_net__AXI_Matrix_0__ds1_wlast = w_port__AXI_Matrix_0__ds1_wlast ;
    assign w_port__AXI_Protocol_Converter_1__us_axi_wlast = w_net__AXI_Matrix_0__ds1_wlast ;

    assign w_net__AXI_Matrix_0__ds1_wstrb = w_port__AXI_Matrix_0__ds1_wstrb ;
    assign w_port__AXI_Protocol_Converter_1__us_axi_wstrb = w_net__AXI_Matrix_0__ds1_wstrb ;

    assign w_net__AXI_Matrix_0__ds1_wvalid = w_port__AXI_Matrix_0__ds1_wvalid ;
    assign w_port__AXI_Protocol_Converter_1__us_axi_wvalid = w_net__AXI_Matrix_0__ds1_wvalid ;

    assign w_net__AXI_Matrix_0__ds2_araddr = w_port__AXI_Matrix_0__ds2_araddr ;
    assign w_port__AXI_Protocol_Converter_2__us_axi_araddr = w_net__AXI_Matrix_0__ds2_araddr ;

    assign w_net__AXI_Matrix_0__ds2_arburst = w_port__AXI_Matrix_0__ds2_arburst ;
    assign w_port__AXI_Protocol_Converter_2__us_axi_arburst = w_net__AXI_Matrix_0__ds2_arburst ;

    assign w_net__AXI_Matrix_0__ds2_arcache = w_port__AXI_Matrix_0__ds2_arcache ;
    assign w_port__AXI_Protocol_Converter_2__us_axi_arcache = w_net__AXI_Matrix_0__ds2_arcache ;

    assign w_net__AXI_Matrix_0__ds2_arid = w_port__AXI_Matrix_0__ds2_arid ;
    assign w_port__AXI_Protocol_Converter_2__us_axi_arid = {2'b0,w_net__AXI_Matrix_0__ds2_arid} ;

    assign w_net__AXI_Matrix_0__ds2_arlen = w_port__AXI_Matrix_0__ds2_arlen ;
    assign w_port__AXI_Protocol_Converter_2__us_axi_arlen = w_net__AXI_Matrix_0__ds2_arlen ;

    assign w_net__AXI_Matrix_0__ds2_arlock = w_port__AXI_Matrix_0__ds2_arlock ;
    assign w_port__AXI_Protocol_Converter_2__us_axi_arlock = w_net__AXI_Matrix_0__ds2_arlock ;

    assign w_net__AXI_Matrix_0__ds2_arprot = w_port__AXI_Matrix_0__ds2_arprot ;
    assign w_port__AXI_Protocol_Converter_2__us_axi_arprot = w_net__AXI_Matrix_0__ds2_arprot ;

    assign w_net__AXI_Matrix_0__ds2_arqos = w_port__AXI_Matrix_0__ds2_arqos ;
    assign w_port__AXI_Protocol_Converter_2__us_axi_arqos = w_net__AXI_Matrix_0__ds2_arqos ;

    assign w_net__AXI_Matrix_0__ds2_arsize = w_port__AXI_Matrix_0__ds2_arsize ;
    assign w_port__AXI_Protocol_Converter_2__us_axi_arsize = w_net__AXI_Matrix_0__ds2_arsize ;

    assign w_net__AXI_Matrix_0__ds2_arvalid = w_port__AXI_Matrix_0__ds2_arvalid ;
    assign w_port__AXI_Protocol_Converter_2__us_axi_arvalid = w_net__AXI_Matrix_0__ds2_arvalid ;

    assign w_net__AXI_Matrix_0__ds2_awaddr = w_port__AXI_Matrix_0__ds2_awaddr ;
    assign w_port__AXI_Protocol_Converter_2__us_axi_awaddr = w_net__AXI_Matrix_0__ds2_awaddr ;

    assign w_net__AXI_Matrix_0__ds2_awburst = w_port__AXI_Matrix_0__ds2_awburst ;
    assign w_port__AXI_Protocol_Converter_2__us_axi_awburst = w_net__AXI_Matrix_0__ds2_awburst ;

    assign w_net__AXI_Matrix_0__ds2_awcache = w_port__AXI_Matrix_0__ds2_awcache ;
    assign w_port__AXI_Protocol_Converter_2__us_axi_awcache = w_net__AXI_Matrix_0__ds2_awcache ;

    assign w_net__AXI_Matrix_0__ds2_awid = w_port__AXI_Matrix_0__ds2_awid ;
    assign w_port__AXI_Protocol_Converter_2__us_axi_awid = {2'b0,w_net__AXI_Matrix_0__ds2_awid} ;

    assign w_net__AXI_Matrix_0__ds2_awlen = w_port__AXI_Matrix_0__ds2_awlen ;
    assign w_port__AXI_Protocol_Converter_2__us_axi_awlen = w_net__AXI_Matrix_0__ds2_awlen ;

    assign w_net__AXI_Matrix_0__ds2_awlock = w_port__AXI_Matrix_0__ds2_awlock ;
    assign w_port__AXI_Protocol_Converter_2__us_axi_awlock = w_net__AXI_Matrix_0__ds2_awlock ;

    assign w_net__AXI_Matrix_0__ds2_awprot = w_port__AXI_Matrix_0__ds2_awprot ;
    assign w_port__AXI_Protocol_Converter_2__us_axi_awprot = w_net__AXI_Matrix_0__ds2_awprot ;

    assign w_net__AXI_Matrix_0__ds2_awqos = w_port__AXI_Matrix_0__ds2_awqos ;
    assign w_port__AXI_Protocol_Converter_2__us_axi_awqos = w_net__AXI_Matrix_0__ds2_awqos ;

    assign w_net__AXI_Matrix_0__ds2_awsize = w_port__AXI_Matrix_0__ds2_awsize ;
    assign w_port__AXI_Protocol_Converter_2__us_axi_awsize = w_net__AXI_Matrix_0__ds2_awsize ;

    assign w_net__AXI_Matrix_0__ds2_awvalid = w_port__AXI_Matrix_0__ds2_awvalid ;
    assign w_port__AXI_Protocol_Converter_2__us_axi_awvalid = w_net__AXI_Matrix_0__ds2_awvalid ;

    assign w_net__AXI_Matrix_0__ds2_bready = w_port__AXI_Matrix_0__ds2_bready ;
    assign w_port__AXI_Protocol_Converter_2__us_axi_bready = w_net__AXI_Matrix_0__ds2_bready ;

    assign w_net__AXI_Matrix_0__ds2_rready = w_port__AXI_Matrix_0__ds2_rready ;
    assign w_port__AXI_Protocol_Converter_2__us_axi_rready = w_net__AXI_Matrix_0__ds2_rready ;

    assign w_net__AXI_Matrix_0__ds2_wdata = w_port__AXI_Matrix_0__ds2_wdata ;
    assign w_port__AXI_Protocol_Converter_2__us_axi_wdata = w_net__AXI_Matrix_0__ds2_wdata ;

    assign w_net__AXI_Matrix_0__ds2_wlast = w_port__AXI_Matrix_0__ds2_wlast ;
    assign w_port__AXI_Protocol_Converter_2__us_axi_wlast = w_net__AXI_Matrix_0__ds2_wlast ;

    assign w_net__AXI_Matrix_0__ds2_wstrb = w_port__AXI_Matrix_0__ds2_wstrb ;
    assign w_port__AXI_Protocol_Converter_2__us_axi_wstrb = w_net__AXI_Matrix_0__ds2_wstrb ;

    assign w_net__AXI_Matrix_0__ds2_wvalid = w_port__AXI_Matrix_0__ds2_wvalid ;
    assign w_port__AXI_Protocol_Converter_2__us_axi_wvalid = w_net__AXI_Matrix_0__ds2_wvalid ;

    assign w_net__AXI_Matrix_0__us0_arready = w_port__AXI_Matrix_0__us0_arready ;
    assign w_port__ARM_Processor_System_0__master_gp0_axi_arready = w_net__AXI_Matrix_0__us0_arready ;

    assign w_net__AXI_Matrix_0__us0_awready = w_port__AXI_Matrix_0__us0_awready ;
    assign w_port__ARM_Processor_System_0__master_gp0_axi_awready = w_net__AXI_Matrix_0__us0_awready ;

    assign w_net__AXI_Matrix_0__us0_bid = w_port__AXI_Matrix_0__us0_bid ;
    assign w_port__ARM_Processor_System_0__master_gp0_axi_bid = {11'b0,w_net__AXI_Matrix_0__us0_bid} ;

    assign w_net__AXI_Matrix_0__us0_bresp = w_port__AXI_Matrix_0__us0_bresp ;
    assign w_port__ARM_Processor_System_0__master_gp0_axi_bresp = w_net__AXI_Matrix_0__us0_bresp ;

    assign w_net__AXI_Matrix_0__us0_bvalid = w_port__AXI_Matrix_0__us0_bvalid ;
    assign w_port__ARM_Processor_System_0__master_gp0_axi_bvalid = w_net__AXI_Matrix_0__us0_bvalid ;

    assign w_net__AXI_Matrix_0__us0_rdata = w_port__AXI_Matrix_0__us0_rdata ;
    assign w_port__ARM_Processor_System_0__master_gp0_axi_rdata = w_net__AXI_Matrix_0__us0_rdata ;

    assign w_net__AXI_Matrix_0__us0_rid = w_port__AXI_Matrix_0__us0_rid ;
    assign w_port__ARM_Processor_System_0__master_gp0_axi_rid = {11'b0,w_net__AXI_Matrix_0__us0_rid} ;

    assign w_net__AXI_Matrix_0__us0_rlast = w_port__AXI_Matrix_0__us0_rlast ;
    assign w_port__ARM_Processor_System_0__master_gp0_axi_rlast = w_net__AXI_Matrix_0__us0_rlast ;

    assign w_net__AXI_Matrix_0__us0_rresp = w_port__AXI_Matrix_0__us0_rresp ;
    assign w_port__ARM_Processor_System_0__master_gp0_axi_rresp = w_net__AXI_Matrix_0__us0_rresp ;

    assign w_net__AXI_Matrix_0__us0_rvalid = w_port__AXI_Matrix_0__us0_rvalid ;
    assign w_port__ARM_Processor_System_0__master_gp0_axi_rvalid = w_net__AXI_Matrix_0__us0_rvalid ;

    assign w_net__AXI_Matrix_0__us0_wready = w_port__AXI_Matrix_0__us0_wready ;
    assign w_port__ARM_Processor_System_0__master_gp0_axi_wready = w_net__AXI_Matrix_0__us0_wready ;

    assign w_net__AXI_Protocol_Converter_0__ds_axi_araddr = w_port__AXI_Protocol_Converter_0__ds_axi_araddr ;
    assign w_port__AXI_GPIO_0__s_axi_araddr = w_net__AXI_Protocol_Converter_0__ds_axi_araddr ;

    assign w_net__AXI_Protocol_Converter_0__ds_axi_arvalid = w_port__AXI_Protocol_Converter_0__ds_axi_arvalid ;
    assign w_port__AXI_GPIO_0__s_axi_arvalid = w_net__AXI_Protocol_Converter_0__ds_axi_arvalid ;

    assign w_net__AXI_Protocol_Converter_0__ds_axi_awaddr = w_port__AXI_Protocol_Converter_0__ds_axi_awaddr ;
    assign w_port__AXI_GPIO_0__s_axi_awaddr = w_net__AXI_Protocol_Converter_0__ds_axi_awaddr ;

    assign w_net__AXI_Protocol_Converter_0__ds_axi_awvalid = w_port__AXI_Protocol_Converter_0__ds_axi_awvalid ;
    assign w_port__AXI_GPIO_0__s_axi_awvalid = w_net__AXI_Protocol_Converter_0__ds_axi_awvalid ;

    assign w_net__AXI_Protocol_Converter_0__ds_axi_bready = w_port__AXI_Protocol_Converter_0__ds_axi_bready ;
    assign w_port__AXI_GPIO_0__s_axi_bready = w_net__AXI_Protocol_Converter_0__ds_axi_bready ;

    assign w_net__AXI_Protocol_Converter_0__ds_axi_rready = w_port__AXI_Protocol_Converter_0__ds_axi_rready ;
    assign w_port__AXI_GPIO_0__s_axi_rready = w_net__AXI_Protocol_Converter_0__ds_axi_rready ;

    assign w_net__AXI_Protocol_Converter_0__ds_axi_wdata = w_port__AXI_Protocol_Converter_0__ds_axi_wdata ;
    assign w_port__AXI_GPIO_0__s_axi_wdata = w_net__AXI_Protocol_Converter_0__ds_axi_wdata ;

    assign w_net__AXI_Protocol_Converter_0__ds_axi_wstrb = w_port__AXI_Protocol_Converter_0__ds_axi_wstrb ;
    assign w_port__AXI_GPIO_0__s_axi_wstrb = w_net__AXI_Protocol_Converter_0__ds_axi_wstrb ;

    assign w_net__AXI_Protocol_Converter_0__ds_axi_wvalid = w_port__AXI_Protocol_Converter_0__ds_axi_wvalid ;
    assign w_port__AXI_GPIO_0__s_axi_wvalid = w_net__AXI_Protocol_Converter_0__ds_axi_wvalid ;

    assign w_net__AXI_Protocol_Converter_0__us_axi_arready = w_port__AXI_Protocol_Converter_0__us_axi_arready ;
    assign w_port__AXI_Matrix_0__ds0_arready = w_net__AXI_Protocol_Converter_0__us_axi_arready ;

    assign w_net__AXI_Protocol_Converter_0__us_axi_awready = w_port__AXI_Protocol_Converter_0__us_axi_awready ;
    assign w_port__AXI_Matrix_0__ds0_awready = w_net__AXI_Protocol_Converter_0__us_axi_awready ;

    assign w_net__AXI_Protocol_Converter_0__us_axi_bid = w_port__AXI_Protocol_Converter_0__us_axi_bid ;
    assign w_port__AXI_Matrix_0__ds0_bid = w_net__AXI_Protocol_Converter_0__us_axi_bid ;

    assign w_net__AXI_Protocol_Converter_0__us_axi_bresp = w_port__AXI_Protocol_Converter_0__us_axi_bresp ;
    assign w_port__AXI_Matrix_0__ds0_bresp = w_net__AXI_Protocol_Converter_0__us_axi_bresp ;

    assign w_net__AXI_Protocol_Converter_0__us_axi_bvalid = w_port__AXI_Protocol_Converter_0__us_axi_bvalid ;
    assign w_port__AXI_Matrix_0__ds0_bvalid = w_net__AXI_Protocol_Converter_0__us_axi_bvalid ;

    assign w_net__AXI_Protocol_Converter_0__us_axi_rdata = w_port__AXI_Protocol_Converter_0__us_axi_rdata ;
    assign w_port__AXI_Matrix_0__ds0_rdata = w_net__AXI_Protocol_Converter_0__us_axi_rdata ;

    assign w_net__AXI_Protocol_Converter_0__us_axi_rid = w_port__AXI_Protocol_Converter_0__us_axi_rid ;
    assign w_port__AXI_Matrix_0__ds0_rid = w_net__AXI_Protocol_Converter_0__us_axi_rid ;

    assign w_net__AXI_Protocol_Converter_0__us_axi_rlast = w_port__AXI_Protocol_Converter_0__us_axi_rlast ;
    assign w_port__AXI_Matrix_0__ds0_rlast = w_net__AXI_Protocol_Converter_0__us_axi_rlast ;

    assign w_net__AXI_Protocol_Converter_0__us_axi_rresp = w_port__AXI_Protocol_Converter_0__us_axi_rresp ;
    assign w_port__AXI_Matrix_0__ds0_rresp = w_net__AXI_Protocol_Converter_0__us_axi_rresp ;

    assign w_net__AXI_Protocol_Converter_0__us_axi_rvalid = w_port__AXI_Protocol_Converter_0__us_axi_rvalid ;
    assign w_port__AXI_Matrix_0__ds0_rvalid = w_net__AXI_Protocol_Converter_0__us_axi_rvalid ;

    assign w_net__AXI_Protocol_Converter_0__us_axi_wready = w_port__AXI_Protocol_Converter_0__us_axi_wready ;
    assign w_port__AXI_Matrix_0__ds0_wready = w_net__AXI_Protocol_Converter_0__us_axi_wready ;

    assign w_net__AXI_Protocol_Converter_1__ds_axi_araddr = w_port__AXI_Protocol_Converter_1__ds_axi_araddr ;
    assign w_port__AXI_GPIO_1__s_axi_araddr = w_net__AXI_Protocol_Converter_1__ds_axi_araddr ;

    assign w_net__AXI_Protocol_Converter_1__ds_axi_arvalid = w_port__AXI_Protocol_Converter_1__ds_axi_arvalid ;
    assign w_port__AXI_GPIO_1__s_axi_arvalid = w_net__AXI_Protocol_Converter_1__ds_axi_arvalid ;

    assign w_net__AXI_Protocol_Converter_1__ds_axi_awaddr = w_port__AXI_Protocol_Converter_1__ds_axi_awaddr ;
    assign w_port__AXI_GPIO_1__s_axi_awaddr = w_net__AXI_Protocol_Converter_1__ds_axi_awaddr ;

    assign w_net__AXI_Protocol_Converter_1__ds_axi_awvalid = w_port__AXI_Protocol_Converter_1__ds_axi_awvalid ;
    assign w_port__AXI_GPIO_1__s_axi_awvalid = w_net__AXI_Protocol_Converter_1__ds_axi_awvalid ;

    assign w_net__AXI_Protocol_Converter_1__ds_axi_bready = w_port__AXI_Protocol_Converter_1__ds_axi_bready ;
    assign w_port__AXI_GPIO_1__s_axi_bready = w_net__AXI_Protocol_Converter_1__ds_axi_bready ;

    assign w_net__AXI_Protocol_Converter_1__ds_axi_rready = w_port__AXI_Protocol_Converter_1__ds_axi_rready ;
    assign w_port__AXI_GPIO_1__s_axi_rready = w_net__AXI_Protocol_Converter_1__ds_axi_rready ;

    assign w_net__AXI_Protocol_Converter_1__ds_axi_wdata = w_port__AXI_Protocol_Converter_1__ds_axi_wdata ;
    assign w_port__AXI_GPIO_1__s_axi_wdata = w_net__AXI_Protocol_Converter_1__ds_axi_wdata ;

    assign w_net__AXI_Protocol_Converter_1__ds_axi_wstrb = w_port__AXI_Protocol_Converter_1__ds_axi_wstrb ;
    assign w_port__AXI_GPIO_1__s_axi_wstrb = w_net__AXI_Protocol_Converter_1__ds_axi_wstrb ;

    assign w_net__AXI_Protocol_Converter_1__ds_axi_wvalid = w_port__AXI_Protocol_Converter_1__ds_axi_wvalid ;
    assign w_port__AXI_GPIO_1__s_axi_wvalid = w_net__AXI_Protocol_Converter_1__ds_axi_wvalid ;

    assign w_net__AXI_Protocol_Converter_1__us_axi_arready = w_port__AXI_Protocol_Converter_1__us_axi_arready ;
    assign w_port__AXI_Matrix_0__ds1_arready = w_net__AXI_Protocol_Converter_1__us_axi_arready ;

    assign w_net__AXI_Protocol_Converter_1__us_axi_awready = w_port__AXI_Protocol_Converter_1__us_axi_awready ;
    assign w_port__AXI_Matrix_0__ds1_awready = w_net__AXI_Protocol_Converter_1__us_axi_awready ;

    assign w_net__AXI_Protocol_Converter_1__us_axi_bid = w_port__AXI_Protocol_Converter_1__us_axi_bid ;
    assign w_port__AXI_Matrix_0__ds1_bid = w_net__AXI_Protocol_Converter_1__us_axi_bid ;

    assign w_net__AXI_Protocol_Converter_1__us_axi_bresp = w_port__AXI_Protocol_Converter_1__us_axi_bresp ;
    assign w_port__AXI_Matrix_0__ds1_bresp = w_net__AXI_Protocol_Converter_1__us_axi_bresp ;

    assign w_net__AXI_Protocol_Converter_1__us_axi_bvalid = w_port__AXI_Protocol_Converter_1__us_axi_bvalid ;
    assign w_port__AXI_Matrix_0__ds1_bvalid = w_net__AXI_Protocol_Converter_1__us_axi_bvalid ;

    assign w_net__AXI_Protocol_Converter_1__us_axi_rdata = w_port__AXI_Protocol_Converter_1__us_axi_rdata ;
    assign w_port__AXI_Matrix_0__ds1_rdata = w_net__AXI_Protocol_Converter_1__us_axi_rdata ;

    assign w_net__AXI_Protocol_Converter_1__us_axi_rid = w_port__AXI_Protocol_Converter_1__us_axi_rid ;
    assign w_port__AXI_Matrix_0__ds1_rid = w_net__AXI_Protocol_Converter_1__us_axi_rid ;

    assign w_net__AXI_Protocol_Converter_1__us_axi_rlast = w_port__AXI_Protocol_Converter_1__us_axi_rlast ;
    assign w_port__AXI_Matrix_0__ds1_rlast = w_net__AXI_Protocol_Converter_1__us_axi_rlast ;

    assign w_net__AXI_Protocol_Converter_1__us_axi_rresp = w_port__AXI_Protocol_Converter_1__us_axi_rresp ;
    assign w_port__AXI_Matrix_0__ds1_rresp = w_net__AXI_Protocol_Converter_1__us_axi_rresp ;

    assign w_net__AXI_Protocol_Converter_1__us_axi_rvalid = w_port__AXI_Protocol_Converter_1__us_axi_rvalid ;
    assign w_port__AXI_Matrix_0__ds1_rvalid = w_net__AXI_Protocol_Converter_1__us_axi_rvalid ;

    assign w_net__AXI_Protocol_Converter_1__us_axi_wready = w_port__AXI_Protocol_Converter_1__us_axi_wready ;
    assign w_port__AXI_Matrix_0__ds1_wready = w_net__AXI_Protocol_Converter_1__us_axi_wready ;

    assign w_net__AXI_Protocol_Converter_2__ds_axi_araddr = w_port__AXI_Protocol_Converter_2__ds_axi_araddr ;
    assign w_port__axi_lite_pwm_0__s_axi_araddr = w_net__AXI_Protocol_Converter_2__ds_axi_araddr ;

    assign w_net__AXI_Protocol_Converter_2__ds_axi_arvalid = w_port__AXI_Protocol_Converter_2__ds_axi_arvalid ;
    assign w_port__axi_lite_pwm_0__s_axi_arvalid = w_net__AXI_Protocol_Converter_2__ds_axi_arvalid ;

    assign w_net__AXI_Protocol_Converter_2__ds_axi_awaddr = w_port__AXI_Protocol_Converter_2__ds_axi_awaddr ;
    assign w_port__axi_lite_pwm_0__s_axi_awaddr = w_net__AXI_Protocol_Converter_2__ds_axi_awaddr ;

    assign w_net__AXI_Protocol_Converter_2__ds_axi_awvalid = w_port__AXI_Protocol_Converter_2__ds_axi_awvalid ;
    assign w_port__axi_lite_pwm_0__s_axi_awvalid = w_net__AXI_Protocol_Converter_2__ds_axi_awvalid ;

    assign w_net__AXI_Protocol_Converter_2__ds_axi_bready = w_port__AXI_Protocol_Converter_2__ds_axi_bready ;
    assign w_port__axi_lite_pwm_0__s_axi_bready = w_net__AXI_Protocol_Converter_2__ds_axi_bready ;

    assign w_net__AXI_Protocol_Converter_2__ds_axi_rready = w_port__AXI_Protocol_Converter_2__ds_axi_rready ;
    assign w_port__axi_lite_pwm_0__s_axi_rready = w_net__AXI_Protocol_Converter_2__ds_axi_rready ;

    assign w_net__AXI_Protocol_Converter_2__ds_axi_wdata = w_port__AXI_Protocol_Converter_2__ds_axi_wdata ;
    assign w_port__axi_lite_pwm_0__s_axi_wdata = w_net__AXI_Protocol_Converter_2__ds_axi_wdata ;

    assign w_net__AXI_Protocol_Converter_2__ds_axi_wstrb = w_port__AXI_Protocol_Converter_2__ds_axi_wstrb ;
    assign w_port__axi_lite_pwm_0__s_axi_wstrb = w_net__AXI_Protocol_Converter_2__ds_axi_wstrb ;

    assign w_net__AXI_Protocol_Converter_2__ds_axi_wvalid = w_port__AXI_Protocol_Converter_2__ds_axi_wvalid ;
    assign w_port__axi_lite_pwm_0__s_axi_wvalid = w_net__AXI_Protocol_Converter_2__ds_axi_wvalid ;

    assign w_net__AXI_Protocol_Converter_2__us_axi_arready = w_port__AXI_Protocol_Converter_2__us_axi_arready ;
    assign w_port__AXI_Matrix_0__ds2_arready = w_net__AXI_Protocol_Converter_2__us_axi_arready ;

    assign w_net__AXI_Protocol_Converter_2__us_axi_awready = w_port__AXI_Protocol_Converter_2__us_axi_awready ;
    assign w_port__AXI_Matrix_0__ds2_awready = w_net__AXI_Protocol_Converter_2__us_axi_awready ;

    assign w_net__AXI_Protocol_Converter_2__us_axi_bid = w_port__AXI_Protocol_Converter_2__us_axi_bid ;
    assign w_port__AXI_Matrix_0__ds2_bid = w_net__AXI_Protocol_Converter_2__us_axi_bid ;

    assign w_net__AXI_Protocol_Converter_2__us_axi_bresp = w_port__AXI_Protocol_Converter_2__us_axi_bresp ;
    assign w_port__AXI_Matrix_0__ds2_bresp = w_net__AXI_Protocol_Converter_2__us_axi_bresp ;

    assign w_net__AXI_Protocol_Converter_2__us_axi_bvalid = w_port__AXI_Protocol_Converter_2__us_axi_bvalid ;
    assign w_port__AXI_Matrix_0__ds2_bvalid = w_net__AXI_Protocol_Converter_2__us_axi_bvalid ;

    assign w_net__AXI_Protocol_Converter_2__us_axi_rdata = w_port__AXI_Protocol_Converter_2__us_axi_rdata ;
    assign w_port__AXI_Matrix_0__ds2_rdata = w_net__AXI_Protocol_Converter_2__us_axi_rdata ;

    assign w_net__AXI_Protocol_Converter_2__us_axi_rid = w_port__AXI_Protocol_Converter_2__us_axi_rid ;
    assign w_port__AXI_Matrix_0__ds2_rid = w_net__AXI_Protocol_Converter_2__us_axi_rid ;

    assign w_net__AXI_Protocol_Converter_2__us_axi_rlast = w_port__AXI_Protocol_Converter_2__us_axi_rlast ;
    assign w_port__AXI_Matrix_0__ds2_rlast = w_net__AXI_Protocol_Converter_2__us_axi_rlast ;

    assign w_net__AXI_Protocol_Converter_2__us_axi_rresp = w_port__AXI_Protocol_Converter_2__us_axi_rresp ;
    assign w_port__AXI_Matrix_0__ds2_rresp = w_net__AXI_Protocol_Converter_2__us_axi_rresp ;

    assign w_net__AXI_Protocol_Converter_2__us_axi_rvalid = w_port__AXI_Protocol_Converter_2__us_axi_rvalid ;
    assign w_port__AXI_Matrix_0__ds2_rvalid = w_net__AXI_Protocol_Converter_2__us_axi_rvalid ;

    assign w_net__AXI_Protocol_Converter_2__us_axi_wready = w_port__AXI_Protocol_Converter_2__us_axi_wready ;
    assign w_port__AXI_Matrix_0__ds2_wready = w_net__AXI_Protocol_Converter_2__us_axi_wready ;

    assign w_net__Constant_0__dout = w_port__Constant_0__dout ;
    assign w_port__Processor_System_Reset_0__pll_locked = w_net__Constant_0__dout ;

    assign w_net__I_fdma_raddr = I_fdma_raddr ;
    assign w_port__uiFDMA_0__I_fdma_raddr = w_net__I_fdma_raddr ;

    assign w_net__I_fdma_rareq = I_fdma_rareq ;
    assign w_port__uiFDMA_0__I_fdma_rareq = w_net__I_fdma_rareq ;

    assign w_net__I_fdma_rready = I_fdma_rready ;
    assign w_port__uiFDMA_0__I_fdma_rready = w_net__I_fdma_rready ;

    assign w_net__I_fdma_rsize = I_fdma_rsize ;
    assign w_port__uiFDMA_0__I_fdma_rsize = w_net__I_fdma_rsize ;

    assign w_net__I_fdma_waddr = I_fdma_waddr ;
    assign w_port__uiFDMA_0__I_fdma_waddr = w_net__I_fdma_waddr ;

    assign w_net__I_fdma_wareq = I_fdma_wareq ;
    assign w_port__uiFDMA_0__I_fdma_wareq = w_net__I_fdma_wareq ;

    assign w_net__I_fdma_wdata = I_fdma_wdata ;
    assign w_port__uiFDMA_0__I_fdma_wdata = w_net__I_fdma_wdata ;

    assign w_net__I_fdma_wready = I_fdma_wready ;
    assign w_port__uiFDMA_0__I_fdma_wready = w_net__I_fdma_wready ;

    assign w_net__I_fdma_wsize = I_fdma_wsize ;
    assign w_port__uiFDMA_0__I_fdma_wsize = w_net__I_fdma_wsize ;

    assign w_net__PWM_0__pwm_out = w_port__PWM_0__pwm_out ;
    assign pwm_out1 = w_net__PWM_0__pwm_out ;

    assign w_net__axi_lite_pwm_0__motor_dir = w_port__axi_lite_pwm_0__motor_dir ;
    assign motor_dir = w_net__axi_lite_pwm_0__motor_dir ;

    assign w_net__axi_lite_pwm_0__motor_enable = w_port__axi_lite_pwm_0__motor_enable ;
    assign motor_enable = w_net__axi_lite_pwm_0__motor_enable ;

    assign w_net__axi_lite_pwm_0__pwm_out = w_port__axi_lite_pwm_0__pwm_out ;
    assign pwm_out = w_net__axi_lite_pwm_0__pwm_out ;

    assign w_net__axi_lite_pwm_0__s_axi_arready = w_port__axi_lite_pwm_0__s_axi_arready ;
    assign w_port__AXI_Protocol_Converter_2__ds_axi_arready = w_net__axi_lite_pwm_0__s_axi_arready ;

    assign w_net__axi_lite_pwm_0__s_axi_awready = w_port__axi_lite_pwm_0__s_axi_awready ;
    assign w_port__AXI_Protocol_Converter_2__ds_axi_awready = w_net__axi_lite_pwm_0__s_axi_awready ;

    assign w_net__axi_lite_pwm_0__s_axi_bresp = w_port__axi_lite_pwm_0__s_axi_bresp ;
    assign w_port__AXI_Protocol_Converter_2__ds_axi_bresp = w_net__axi_lite_pwm_0__s_axi_bresp ;

    assign w_net__axi_lite_pwm_0__s_axi_bvalid = w_port__axi_lite_pwm_0__s_axi_bvalid ;
    assign w_port__AXI_Protocol_Converter_2__ds_axi_bvalid = w_net__axi_lite_pwm_0__s_axi_bvalid ;

    assign w_net__axi_lite_pwm_0__s_axi_rdata = w_port__axi_lite_pwm_0__s_axi_rdata ;
    assign w_port__AXI_Protocol_Converter_2__ds_axi_rdata = w_net__axi_lite_pwm_0__s_axi_rdata ;

    assign w_net__axi_lite_pwm_0__s_axi_rresp = w_port__axi_lite_pwm_0__s_axi_rresp ;
    assign w_port__AXI_Protocol_Converter_2__ds_axi_rresp = w_net__axi_lite_pwm_0__s_axi_rresp ;

    assign w_net__axi_lite_pwm_0__s_axi_rvalid = w_port__axi_lite_pwm_0__s_axi_rvalid ;
    assign w_port__AXI_Protocol_Converter_2__ds_axi_rvalid = w_net__axi_lite_pwm_0__s_axi_rvalid ;

    assign w_net__axi_lite_pwm_0__s_axi_wready = w_port__axi_lite_pwm_0__s_axi_wready ;
    assign w_port__AXI_Protocol_Converter_2__ds_axi_wready = w_net__axi_lite_pwm_0__s_axi_wready ;

    assign w_net__pwm_clk = pwm_clk ;
    assign w_port__PWM_0__clk = w_net__pwm_clk ;

    assign w_net__rst_n = rst_n ;
    assign w_port__PWM_0__rst_n = w_net__rst_n ;

    assign w_net__uiFDMA_0__M_AXI_ARADDR = w_port__uiFDMA_0__M_AXI_ARADDR ;
    assign w_port__ARM_Processor_System_0__slave_hp0_axi_araddr = {1'b0,w_net__uiFDMA_0__M_AXI_ARADDR} ;

    assign w_net__uiFDMA_0__M_AXI_ARBURST = w_port__uiFDMA_0__M_AXI_ARBURST ;
    assign w_port__ARM_Processor_System_0__slave_hp0_axi_arburst = w_net__uiFDMA_0__M_AXI_ARBURST ;

    assign w_net__uiFDMA_0__M_AXI_ARCACHE = w_port__uiFDMA_0__M_AXI_ARCACHE ;
    assign w_port__ARM_Processor_System_0__slave_hp0_axi_arcache = w_net__uiFDMA_0__M_AXI_ARCACHE ;

    assign w_net__uiFDMA_0__M_AXI_ARID = w_port__uiFDMA_0__M_AXI_ARID ;
    assign w_port__ARM_Processor_System_0__slave_hp0_axi_arid = w_net__uiFDMA_0__M_AXI_ARID ;

    assign w_net__uiFDMA_0__M_AXI_ARLEN = w_port__uiFDMA_0__M_AXI_ARLEN ;
    assign w_port__ARM_Processor_System_0__slave_hp0_axi_arlen = w_net__uiFDMA_0__M_AXI_ARLEN ;

    assign w_net__uiFDMA_0__M_AXI_ARLOCK = w_port__uiFDMA_0__M_AXI_ARLOCK ;
    assign w_port__ARM_Processor_System_0__slave_hp0_axi_arlock = w_net__uiFDMA_0__M_AXI_ARLOCK ;

    assign w_net__uiFDMA_0__M_AXI_ARPROT = w_port__uiFDMA_0__M_AXI_ARPROT ;
    assign w_port__ARM_Processor_System_0__slave_hp0_axi_arprot = w_net__uiFDMA_0__M_AXI_ARPROT ;

    assign w_net__uiFDMA_0__M_AXI_ARQOS = w_port__uiFDMA_0__M_AXI_ARQOS ;
    assign w_port__ARM_Processor_System_0__slave_hp0_axi_arqos = w_net__uiFDMA_0__M_AXI_ARQOS ;

    assign w_net__uiFDMA_0__M_AXI_ARSIZE = w_port__uiFDMA_0__M_AXI_ARSIZE ;
    assign w_port__ARM_Processor_System_0__slave_hp0_axi_arsize = w_net__uiFDMA_0__M_AXI_ARSIZE ;

    assign w_net__uiFDMA_0__M_AXI_ARVALID = w_port__uiFDMA_0__M_AXI_ARVALID ;
    assign w_port__ARM_Processor_System_0__slave_hp0_axi_arvalid = w_net__uiFDMA_0__M_AXI_ARVALID ;

    assign w_net__uiFDMA_0__M_AXI_AWADDR = w_port__uiFDMA_0__M_AXI_AWADDR ;
    assign w_port__ARM_Processor_System_0__slave_hp0_axi_awaddr = {1'b0,w_net__uiFDMA_0__M_AXI_AWADDR} ;

    assign w_net__uiFDMA_0__M_AXI_AWBURST = w_port__uiFDMA_0__M_AXI_AWBURST ;
    assign w_port__ARM_Processor_System_0__slave_hp0_axi_awburst = w_net__uiFDMA_0__M_AXI_AWBURST ;

    assign w_net__uiFDMA_0__M_AXI_AWCACHE = w_port__uiFDMA_0__M_AXI_AWCACHE ;
    assign w_port__ARM_Processor_System_0__slave_hp0_axi_awcache = w_net__uiFDMA_0__M_AXI_AWCACHE ;

    assign w_net__uiFDMA_0__M_AXI_AWID = w_port__uiFDMA_0__M_AXI_AWID ;
    assign w_port__ARM_Processor_System_0__slave_hp0_axi_awid = w_net__uiFDMA_0__M_AXI_AWID ;

    assign w_net__uiFDMA_0__M_AXI_AWLEN = w_port__uiFDMA_0__M_AXI_AWLEN ;
    assign w_port__ARM_Processor_System_0__slave_hp0_axi_awlen = w_net__uiFDMA_0__M_AXI_AWLEN ;

    assign w_net__uiFDMA_0__M_AXI_AWLOCK = w_port__uiFDMA_0__M_AXI_AWLOCK ;
    assign w_port__ARM_Processor_System_0__slave_hp0_axi_awlock = w_net__uiFDMA_0__M_AXI_AWLOCK ;

    assign w_net__uiFDMA_0__M_AXI_AWPROT = w_port__uiFDMA_0__M_AXI_AWPROT ;
    assign w_port__ARM_Processor_System_0__slave_hp0_axi_awprot = w_net__uiFDMA_0__M_AXI_AWPROT ;

    assign w_net__uiFDMA_0__M_AXI_AWQOS = w_port__uiFDMA_0__M_AXI_AWQOS ;
    assign w_port__ARM_Processor_System_0__slave_hp0_axi_awqos = w_net__uiFDMA_0__M_AXI_AWQOS ;

    assign w_net__uiFDMA_0__M_AXI_AWSIZE = w_port__uiFDMA_0__M_AXI_AWSIZE ;
    assign w_port__ARM_Processor_System_0__slave_hp0_axi_awsize = w_net__uiFDMA_0__M_AXI_AWSIZE ;

    assign w_net__uiFDMA_0__M_AXI_AWVALID = w_port__uiFDMA_0__M_AXI_AWVALID ;
    assign w_port__ARM_Processor_System_0__slave_hp0_axi_awvalid = w_net__uiFDMA_0__M_AXI_AWVALID ;

    assign w_net__uiFDMA_0__M_AXI_BREADY = w_port__uiFDMA_0__M_AXI_BREADY ;
    assign w_port__ARM_Processor_System_0__slave_hp0_axi_bready = w_net__uiFDMA_0__M_AXI_BREADY ;

    assign w_net__uiFDMA_0__M_AXI_RREADY = w_port__uiFDMA_0__M_AXI_RREADY ;
    assign w_port__ARM_Processor_System_0__slave_hp0_axi_rready = w_net__uiFDMA_0__M_AXI_RREADY ;

    assign w_net__uiFDMA_0__M_AXI_WDATA = w_port__uiFDMA_0__M_AXI_WDATA ;
    assign w_port__ARM_Processor_System_0__slave_hp0_axi_wdata = w_net__uiFDMA_0__M_AXI_WDATA ;

    assign w_net__uiFDMA_0__M_AXI_WLAST = w_port__uiFDMA_0__M_AXI_WLAST ;
    assign w_port__ARM_Processor_System_0__slave_hp0_axi_wlast = w_net__uiFDMA_0__M_AXI_WLAST ;

    assign w_net__uiFDMA_0__M_AXI_WSTRB = w_port__uiFDMA_0__M_AXI_WSTRB ;
    assign w_port__ARM_Processor_System_0__slave_hp0_axi_wstrb = w_net__uiFDMA_0__M_AXI_WSTRB ;

    assign w_net__uiFDMA_0__M_AXI_WVALID = w_port__uiFDMA_0__M_AXI_WVALID ;
    assign w_port__ARM_Processor_System_0__slave_hp0_axi_wvalid = w_net__uiFDMA_0__M_AXI_WVALID ;

    assign w_net__uiFDMA_0__O_fdma_rbusy = w_port__uiFDMA_0__O_fdma_rbusy ;
    assign O_fdma_rbusy = w_net__uiFDMA_0__O_fdma_rbusy ;

    assign w_net__uiFDMA_0__O_fdma_rdata = w_port__uiFDMA_0__O_fdma_rdata ;
    assign O_fdma_rdata = w_net__uiFDMA_0__O_fdma_rdata ;

    assign w_net__uiFDMA_0__O_fdma_rvalid = w_port__uiFDMA_0__O_fdma_rvalid ;
    assign O_fdma_rvalid = w_net__uiFDMA_0__O_fdma_rvalid ;

    assign w_net__uiFDMA_0__O_fdma_wbusy = w_port__uiFDMA_0__O_fdma_wbusy ;
    assign O_fdma_wbusy = w_net__uiFDMA_0__O_fdma_wbusy ;

    assign w_net__uiFDMA_0__O_fdma_wvalid = w_port__uiFDMA_0__O_fdma_wvalid ;
    assign O_fdma_wvalid = w_net__uiFDMA_0__O_fdma_wvalid ;








    system_ARM_Processor_System_0 ARM_Processor_System_0 ( 
                                                            .slave_hp0_axi_araddr(w_port__ARM_Processor_System_0__slave_hp0_axi_araddr)
                                                          , .slave_hp0_axi_arburst(w_port__ARM_Processor_System_0__slave_hp0_axi_arburst)
                                                          , .slave_hp0_axi_arcache(w_port__ARM_Processor_System_0__slave_hp0_axi_arcache)
                                                          , .slave_hp0_axi_arid(w_port__ARM_Processor_System_0__slave_hp0_axi_arid)
                                                          , .slave_hp0_axi_arlen(w_port__ARM_Processor_System_0__slave_hp0_axi_arlen)
                                                          , .slave_hp0_axi_arlock(w_port__ARM_Processor_System_0__slave_hp0_axi_arlock)
                                                          , .slave_hp0_axi_arprot(w_port__ARM_Processor_System_0__slave_hp0_axi_arprot)
                                                          , .slave_hp0_axi_arqos(w_port__ARM_Processor_System_0__slave_hp0_axi_arqos)
                                                          , .slave_hp0_axi_arready(w_port__ARM_Processor_System_0__slave_hp0_axi_arready)
                                                          , .slave_hp0_axi_arsize(w_port__ARM_Processor_System_0__slave_hp0_axi_arsize)
                                                          , .slave_hp0_axi_arvalid(w_port__ARM_Processor_System_0__slave_hp0_axi_arvalid)
                                                          , .slave_hp0_axi_awaddr(w_port__ARM_Processor_System_0__slave_hp0_axi_awaddr)
                                                          , .slave_hp0_axi_awburst(w_port__ARM_Processor_System_0__slave_hp0_axi_awburst)
                                                          , .slave_hp0_axi_awcache(w_port__ARM_Processor_System_0__slave_hp0_axi_awcache)
                                                          , .slave_hp0_axi_awid(w_port__ARM_Processor_System_0__slave_hp0_axi_awid)
                                                          , .slave_hp0_axi_awlen(w_port__ARM_Processor_System_0__slave_hp0_axi_awlen)
                                                          , .slave_hp0_axi_awlock(w_port__ARM_Processor_System_0__slave_hp0_axi_awlock)
                                                          , .slave_hp0_axi_awprot(w_port__ARM_Processor_System_0__slave_hp0_axi_awprot)
                                                          , .slave_hp0_axi_awqos(w_port__ARM_Processor_System_0__slave_hp0_axi_awqos)
                                                          , .slave_hp0_axi_awready(w_port__ARM_Processor_System_0__slave_hp0_axi_awready)
                                                          , .slave_hp0_axi_awsize(w_port__ARM_Processor_System_0__slave_hp0_axi_awsize)
                                                          , .slave_hp0_axi_awvalid(w_port__ARM_Processor_System_0__slave_hp0_axi_awvalid)
                                                          , .slave_hp0_axi_bid(w_port__ARM_Processor_System_0__slave_hp0_axi_bid)
                                                          , .slave_hp0_axi_bready(w_port__ARM_Processor_System_0__slave_hp0_axi_bready)
                                                          , .slave_hp0_axi_bresp(w_port__ARM_Processor_System_0__slave_hp0_axi_bresp)
                                                          , .slave_hp0_axi_bvalid(w_port__ARM_Processor_System_0__slave_hp0_axi_bvalid)
                                                          , .slave_hp0_axi_rdata(w_port__ARM_Processor_System_0__slave_hp0_axi_rdata)
                                                          , .slave_hp0_axi_rid(w_port__ARM_Processor_System_0__slave_hp0_axi_rid)
                                                          , .slave_hp0_axi_rlast(w_port__ARM_Processor_System_0__slave_hp0_axi_rlast)
                                                          , .slave_hp0_axi_rready(w_port__ARM_Processor_System_0__slave_hp0_axi_rready)
                                                          , .slave_hp0_axi_rresp(w_port__ARM_Processor_System_0__slave_hp0_axi_rresp)
                                                          , .slave_hp0_axi_rvalid(w_port__ARM_Processor_System_0__slave_hp0_axi_rvalid)
                                                          , .slave_hp0_axi_wdata(w_port__ARM_Processor_System_0__slave_hp0_axi_wdata)
                                                          , .slave_hp0_axi_wlast(w_port__ARM_Processor_System_0__slave_hp0_axi_wlast)
                                                          , .slave_hp0_axi_wready(w_port__ARM_Processor_System_0__slave_hp0_axi_wready)
                                                          , .slave_hp0_axi_wstrb(w_port__ARM_Processor_System_0__slave_hp0_axi_wstrb)
                                                          , .slave_hp0_axi_wvalid(w_port__ARM_Processor_System_0__slave_hp0_axi_wvalid)
                                                          , .slave_hp0_axi_aclk(w_port__ARM_Processor_System_0__slave_hp0_axi_aclk)
                                                          , .master_gp0_axi_aclk(w_port__ARM_Processor_System_0__master_gp0_axi_aclk)
                                                          , .master_gp0_axi_araddr(w_port__ARM_Processor_System_0__master_gp0_axi_araddr)
                                                          , .master_gp0_axi_arburst(w_port__ARM_Processor_System_0__master_gp0_axi_arburst)
                                                          , .master_gp0_axi_arcache(w_port__ARM_Processor_System_0__master_gp0_axi_arcache)
                                                          , .master_gp0_axi_arid(w_port__ARM_Processor_System_0__master_gp0_axi_arid)
                                                          , .master_gp0_axi_arlen(w_port__ARM_Processor_System_0__master_gp0_axi_arlen)
                                                          , .master_gp0_axi_arlock(w_port__ARM_Processor_System_0__master_gp0_axi_arlock)
                                                          , .master_gp0_axi_arprot(w_port__ARM_Processor_System_0__master_gp0_axi_arprot)
                                                          , .master_gp0_axi_arready(w_port__ARM_Processor_System_0__master_gp0_axi_arready)
                                                          , .master_gp0_axi_arsize(w_port__ARM_Processor_System_0__master_gp0_axi_arsize)
                                                          , .master_gp0_axi_arvalid(w_port__ARM_Processor_System_0__master_gp0_axi_arvalid)
                                                          , .master_gp0_axi_awaddr(w_port__ARM_Processor_System_0__master_gp0_axi_awaddr)
                                                          , .master_gp0_axi_awburst(w_port__ARM_Processor_System_0__master_gp0_axi_awburst)
                                                          , .master_gp0_axi_awcache(w_port__ARM_Processor_System_0__master_gp0_axi_awcache)
                                                          , .master_gp0_axi_awid(w_port__ARM_Processor_System_0__master_gp0_axi_awid)
                                                          , .master_gp0_axi_awlen(w_port__ARM_Processor_System_0__master_gp0_axi_awlen)
                                                          , .master_gp0_axi_awlock(w_port__ARM_Processor_System_0__master_gp0_axi_awlock)
                                                          , .master_gp0_axi_awprot(w_port__ARM_Processor_System_0__master_gp0_axi_awprot)
                                                          , .master_gp0_axi_awready(w_port__ARM_Processor_System_0__master_gp0_axi_awready)
                                                          , .master_gp0_axi_awsize(w_port__ARM_Processor_System_0__master_gp0_axi_awsize)
                                                          , .master_gp0_axi_awvalid(w_port__ARM_Processor_System_0__master_gp0_axi_awvalid)
                                                          , .master_gp0_axi_bid(w_port__ARM_Processor_System_0__master_gp0_axi_bid)
                                                          , .master_gp0_axi_bready(w_port__ARM_Processor_System_0__master_gp0_axi_bready)
                                                          , .master_gp0_axi_bresp(w_port__ARM_Processor_System_0__master_gp0_axi_bresp)
                                                          , .master_gp0_axi_bvalid(w_port__ARM_Processor_System_0__master_gp0_axi_bvalid)
                                                          , .master_gp0_axi_rdata(w_port__ARM_Processor_System_0__master_gp0_axi_rdata)
                                                          , .master_gp0_axi_rid(w_port__ARM_Processor_System_0__master_gp0_axi_rid)
                                                          , .master_gp0_axi_rlast(w_port__ARM_Processor_System_0__master_gp0_axi_rlast)
                                                          , .master_gp0_axi_rready(w_port__ARM_Processor_System_0__master_gp0_axi_rready)
                                                          , .master_gp0_axi_rresp(w_port__ARM_Processor_System_0__master_gp0_axi_rresp)
                                                          , .master_gp0_axi_rvalid(w_port__ARM_Processor_System_0__master_gp0_axi_rvalid)
                                                          , .master_gp0_axi_wdata(w_port__ARM_Processor_System_0__master_gp0_axi_wdata)
                                                          , .master_gp0_axi_wlast(w_port__ARM_Processor_System_0__master_gp0_axi_wlast)
                                                          , .master_gp0_axi_wready(w_port__ARM_Processor_System_0__master_gp0_axi_wready)
                                                          , .master_gp0_axi_wstrb(w_port__ARM_Processor_System_0__master_gp0_axi_wstrb)
                                                          , .master_gp0_axi_wvalid(w_port__ARM_Processor_System_0__master_gp0_axi_wvalid)
                                                          , .pl_gpio_in(1'b0)
                                                          , .pl_gpio_oe()
                                                          , .pl_gpio_out()
                                                          , .uart0_rx_in(1'b0)
                                                          , .uart0_tx_out()
                                                          , .p2f_rst0_n(w_port__ARM_Processor_System_0__p2f_rst0_n)
                                                          , .p2f_clk1(w_port__ARM_Processor_System_0__p2f_clk1)
                                                          , .p2f_clk0(w_port__ARM_Processor_System_0__p2f_clk0) );

    system_uiFDMA_0 uiFDMA_0 ( 
                                .I_fdma_waddr(w_port__uiFDMA_0__I_fdma_waddr)
                              , .I_fdma_wareq(w_port__uiFDMA_0__I_fdma_wareq)
                              , .I_fdma_wsize(w_port__uiFDMA_0__I_fdma_wsize)
                              , .I_fdma_wdata(w_port__uiFDMA_0__I_fdma_wdata)
                              , .I_fdma_wready(w_port__uiFDMA_0__I_fdma_wready)
                              , .I_fdma_raddr(w_port__uiFDMA_0__I_fdma_raddr)
                              , .I_fdma_rareq(w_port__uiFDMA_0__I_fdma_rareq)
                              , .I_fdma_rsize(w_port__uiFDMA_0__I_fdma_rsize)
                              , .I_fdma_rready(w_port__uiFDMA_0__I_fdma_rready)
                              , .M_AXI_ACLK(w_port__uiFDMA_0__M_AXI_ACLK)
                              , .M_AXI_ARESETN(w_port__uiFDMA_0__M_AXI_ARESETN)
                              , .M_AXI_AWREADY(w_port__uiFDMA_0__M_AXI_AWREADY)
                              , .M_AXI_WREADY(w_port__uiFDMA_0__M_AXI_WREADY)
                              , .M_AXI_BID(w_port__uiFDMA_0__M_AXI_BID)
                              , .M_AXI_BRESP(w_port__uiFDMA_0__M_AXI_BRESP)
                              , .M_AXI_BVALID(w_port__uiFDMA_0__M_AXI_BVALID)
                              , .M_AXI_ARREADY(w_port__uiFDMA_0__M_AXI_ARREADY)
                              , .M_AXI_RID(w_port__uiFDMA_0__M_AXI_RID)
                              , .M_AXI_RDATA(w_port__uiFDMA_0__M_AXI_RDATA)
                              , .M_AXI_RRESP(w_port__uiFDMA_0__M_AXI_RRESP)
                              , .M_AXI_RLAST(w_port__uiFDMA_0__M_AXI_RLAST)
                              , .M_AXI_RVALID(w_port__uiFDMA_0__M_AXI_RVALID)
                              , .O_fdma_wbusy(w_port__uiFDMA_0__O_fdma_wbusy)
                              , .O_fdma_wvalid(w_port__uiFDMA_0__O_fdma_wvalid)
                              , .O_fdma_rbusy(w_port__uiFDMA_0__O_fdma_rbusy)
                              , .O_fdma_rdata(w_port__uiFDMA_0__O_fdma_rdata)
                              , .O_fdma_rvalid(w_port__uiFDMA_0__O_fdma_rvalid)
                              , .M_AXI_AWID(w_port__uiFDMA_0__M_AXI_AWID)
                              , .M_AXI_AWADDR(w_port__uiFDMA_0__M_AXI_AWADDR)
                              , .M_AXI_AWLEN(w_port__uiFDMA_0__M_AXI_AWLEN)
                              , .M_AXI_AWSIZE(w_port__uiFDMA_0__M_AXI_AWSIZE)
                              , .M_AXI_AWBURST(w_port__uiFDMA_0__M_AXI_AWBURST)
                              , .M_AXI_AWLOCK(w_port__uiFDMA_0__M_AXI_AWLOCK)
                              , .M_AXI_AWCACHE(w_port__uiFDMA_0__M_AXI_AWCACHE)
                              , .M_AXI_AWPROT(w_port__uiFDMA_0__M_AXI_AWPROT)
                              , .M_AXI_AWQOS(w_port__uiFDMA_0__M_AXI_AWQOS)
                              , .M_AXI_AWVALID(w_port__uiFDMA_0__M_AXI_AWVALID)
                              , .M_AXI_WID()
                              , .M_AXI_WDATA(w_port__uiFDMA_0__M_AXI_WDATA)
                              , .M_AXI_WSTRB(w_port__uiFDMA_0__M_AXI_WSTRB)
                              , .M_AXI_WLAST(w_port__uiFDMA_0__M_AXI_WLAST)
                              , .M_AXI_WVALID(w_port__uiFDMA_0__M_AXI_WVALID)
                              , .M_AXI_BREADY(w_port__uiFDMA_0__M_AXI_BREADY)
                              , .M_AXI_ARID(w_port__uiFDMA_0__M_AXI_ARID)
                              , .M_AXI_ARADDR(w_port__uiFDMA_0__M_AXI_ARADDR)
                              , .M_AXI_ARLEN(w_port__uiFDMA_0__M_AXI_ARLEN)
                              , .M_AXI_ARSIZE(w_port__uiFDMA_0__M_AXI_ARSIZE)
                              , .M_AXI_ARBURST(w_port__uiFDMA_0__M_AXI_ARBURST)
                              , .M_AXI_ARLOCK(w_port__uiFDMA_0__M_AXI_ARLOCK)
                              , .M_AXI_ARCACHE(w_port__uiFDMA_0__M_AXI_ARCACHE)
                              , .M_AXI_ARPROT(w_port__uiFDMA_0__M_AXI_ARPROT)
                              , .M_AXI_ARQOS(w_port__uiFDMA_0__M_AXI_ARQOS)
                              , .M_AXI_ARVALID(w_port__uiFDMA_0__M_AXI_ARVALID)
                              , .M_AXI_RREADY(w_port__uiFDMA_0__M_AXI_RREADY) );

    system_AXI_GPIO_0 AXI_GPIO_0 ( 
                                    .s_axi_awaddr(w_port__AXI_GPIO_0__s_axi_awaddr)
                                  , .s_axi_awvalid(w_port__AXI_GPIO_0__s_axi_awvalid)
                                  , .s_axi_awready(w_port__AXI_GPIO_0__s_axi_awready)
                                  , .s_axi_wdata(w_port__AXI_GPIO_0__s_axi_wdata)
                                  , .s_axi_wstrb(w_port__AXI_GPIO_0__s_axi_wstrb)
                                  , .s_axi_wvalid(w_port__AXI_GPIO_0__s_axi_wvalid)
                                  , .s_axi_wready(w_port__AXI_GPIO_0__s_axi_wready)
                                  , .s_axi_bresp(w_port__AXI_GPIO_0__s_axi_bresp)
                                  , .s_axi_bvalid(w_port__AXI_GPIO_0__s_axi_bvalid)
                                  , .s_axi_bready(w_port__AXI_GPIO_0__s_axi_bready)
                                  , .s_axi_araddr(w_port__AXI_GPIO_0__s_axi_araddr)
                                  , .s_axi_arvalid(w_port__AXI_GPIO_0__s_axi_arvalid)
                                  , .s_axi_arready(w_port__AXI_GPIO_0__s_axi_arready)
                                  , .s_axi_rdata(w_port__AXI_GPIO_0__s_axi_rdata)
                                  , .s_axi_rresp(w_port__AXI_GPIO_0__s_axi_rresp)
                                  , .s_axi_rvalid(w_port__AXI_GPIO_0__s_axi_rvalid)
                                  , .s_axi_rready(w_port__AXI_GPIO_0__s_axi_rready)
                                  , .s_axi_aclk(w_port__AXI_GPIO_0__s_axi_aclk)
                                  , .s_axi_aresetn(w_port__AXI_GPIO_0__s_axi_aresetn)
                                  , .gpio_io_o(w_port__AXI_GPIO_0__gpio_io_o) );

    system_AXI_Protocol_Converter_0 AXI_Protocol_Converter_0 ( 
                                                                .us_axi_awid(w_port__AXI_Protocol_Converter_0__us_axi_awid)
                                                              , .us_axi_awaddr(w_port__AXI_Protocol_Converter_0__us_axi_awaddr)
                                                              , .us_axi_awlen(w_port__AXI_Protocol_Converter_0__us_axi_awlen)
                                                              , .us_axi_awsize(w_port__AXI_Protocol_Converter_0__us_axi_awsize)
                                                              , .us_axi_awburst(w_port__AXI_Protocol_Converter_0__us_axi_awburst)
                                                              , .us_axi_awlock(w_port__AXI_Protocol_Converter_0__us_axi_awlock)
                                                              , .us_axi_awcache(w_port__AXI_Protocol_Converter_0__us_axi_awcache)
                                                              , .us_axi_awprot(w_port__AXI_Protocol_Converter_0__us_axi_awprot)
                                                              , .us_axi_awqos(w_port__AXI_Protocol_Converter_0__us_axi_awqos)
                                                              , .us_axi_awvalid(w_port__AXI_Protocol_Converter_0__us_axi_awvalid)
                                                              , .us_axi_awready(w_port__AXI_Protocol_Converter_0__us_axi_awready)
                                                              , .us_axi_wdata(w_port__AXI_Protocol_Converter_0__us_axi_wdata)
                                                              , .us_axi_wstrb(w_port__AXI_Protocol_Converter_0__us_axi_wstrb)
                                                              , .us_axi_wlast(w_port__AXI_Protocol_Converter_0__us_axi_wlast)
                                                              , .us_axi_wvalid(w_port__AXI_Protocol_Converter_0__us_axi_wvalid)
                                                              , .us_axi_wready(w_port__AXI_Protocol_Converter_0__us_axi_wready)
                                                              , .us_axi_bid(w_port__AXI_Protocol_Converter_0__us_axi_bid)
                                                              , .us_axi_bresp(w_port__AXI_Protocol_Converter_0__us_axi_bresp)
                                                              , .us_axi_bvalid(w_port__AXI_Protocol_Converter_0__us_axi_bvalid)
                                                              , .us_axi_bready(w_port__AXI_Protocol_Converter_0__us_axi_bready)
                                                              , .us_axi_arid(w_port__AXI_Protocol_Converter_0__us_axi_arid)
                                                              , .us_axi_araddr(w_port__AXI_Protocol_Converter_0__us_axi_araddr)
                                                              , .us_axi_arlen(w_port__AXI_Protocol_Converter_0__us_axi_arlen)
                                                              , .us_axi_arsize(w_port__AXI_Protocol_Converter_0__us_axi_arsize)
                                                              , .us_axi_arburst(w_port__AXI_Protocol_Converter_0__us_axi_arburst)
                                                              , .us_axi_arlock(w_port__AXI_Protocol_Converter_0__us_axi_arlock)
                                                              , .us_axi_arcache(w_port__AXI_Protocol_Converter_0__us_axi_arcache)
                                                              , .us_axi_arprot(w_port__AXI_Protocol_Converter_0__us_axi_arprot)
                                                              , .us_axi_arqos(w_port__AXI_Protocol_Converter_0__us_axi_arqos)
                                                              , .us_axi_arvalid(w_port__AXI_Protocol_Converter_0__us_axi_arvalid)
                                                              , .us_axi_arready(w_port__AXI_Protocol_Converter_0__us_axi_arready)
                                                              , .us_axi_rid(w_port__AXI_Protocol_Converter_0__us_axi_rid)
                                                              , .us_axi_rdata(w_port__AXI_Protocol_Converter_0__us_axi_rdata)
                                                              , .us_axi_rresp(w_port__AXI_Protocol_Converter_0__us_axi_rresp)
                                                              , .us_axi_rlast(w_port__AXI_Protocol_Converter_0__us_axi_rlast)
                                                              , .us_axi_rvalid(w_port__AXI_Protocol_Converter_0__us_axi_rvalid)
                                                              , .us_axi_rready(w_port__AXI_Protocol_Converter_0__us_axi_rready)
                                                              , .aclk(w_port__AXI_Protocol_Converter_0__aclk)
                                                              , .aresetn(w_port__AXI_Protocol_Converter_0__aresetn)
                                                              , .ds_axi_awaddr(w_port__AXI_Protocol_Converter_0__ds_axi_awaddr)
                                                              , .ds_axi_awprot()
                                                              , .ds_axi_awvalid(w_port__AXI_Protocol_Converter_0__ds_axi_awvalid)
                                                              , .ds_axi_awready(w_port__AXI_Protocol_Converter_0__ds_axi_awready)
                                                              , .ds_axi_wdata(w_port__AXI_Protocol_Converter_0__ds_axi_wdata)
                                                              , .ds_axi_wstrb(w_port__AXI_Protocol_Converter_0__ds_axi_wstrb)
                                                              , .ds_axi_wvalid(w_port__AXI_Protocol_Converter_0__ds_axi_wvalid)
                                                              , .ds_axi_wready(w_port__AXI_Protocol_Converter_0__ds_axi_wready)
                                                              , .ds_axi_bresp(w_port__AXI_Protocol_Converter_0__ds_axi_bresp)
                                                              , .ds_axi_bvalid(w_port__AXI_Protocol_Converter_0__ds_axi_bvalid)
                                                              , .ds_axi_bready(w_port__AXI_Protocol_Converter_0__ds_axi_bready)
                                                              , .ds_axi_araddr(w_port__AXI_Protocol_Converter_0__ds_axi_araddr)
                                                              , .ds_axi_arprot()
                                                              , .ds_axi_arvalid(w_port__AXI_Protocol_Converter_0__ds_axi_arvalid)
                                                              , .ds_axi_arready(w_port__AXI_Protocol_Converter_0__ds_axi_arready)
                                                              , .ds_axi_rdata(w_port__AXI_Protocol_Converter_0__ds_axi_rdata)
                                                              , .ds_axi_rresp(w_port__AXI_Protocol_Converter_0__ds_axi_rresp)
                                                              , .ds_axi_rvalid(w_port__AXI_Protocol_Converter_0__ds_axi_rvalid)
                                                              , .ds_axi_rready(w_port__AXI_Protocol_Converter_0__ds_axi_rready) );

    system_AXI_GPIO_1 AXI_GPIO_1 ( 
                                    .s_axi_awaddr(w_port__AXI_GPIO_1__s_axi_awaddr)
                                  , .s_axi_awvalid(w_port__AXI_GPIO_1__s_axi_awvalid)
                                  , .s_axi_awready(w_port__AXI_GPIO_1__s_axi_awready)
                                  , .s_axi_wdata(w_port__AXI_GPIO_1__s_axi_wdata)
                                  , .s_axi_wstrb(w_port__AXI_GPIO_1__s_axi_wstrb)
                                  , .s_axi_wvalid(w_port__AXI_GPIO_1__s_axi_wvalid)
                                  , .s_axi_wready(w_port__AXI_GPIO_1__s_axi_wready)
                                  , .s_axi_bresp(w_port__AXI_GPIO_1__s_axi_bresp)
                                  , .s_axi_bvalid(w_port__AXI_GPIO_1__s_axi_bvalid)
                                  , .s_axi_bready(w_port__AXI_GPIO_1__s_axi_bready)
                                  , .s_axi_araddr(w_port__AXI_GPIO_1__s_axi_araddr)
                                  , .s_axi_arvalid(w_port__AXI_GPIO_1__s_axi_arvalid)
                                  , .s_axi_arready(w_port__AXI_GPIO_1__s_axi_arready)
                                  , .s_axi_rdata(w_port__AXI_GPIO_1__s_axi_rdata)
                                  , .s_axi_rresp(w_port__AXI_GPIO_1__s_axi_rresp)
                                  , .s_axi_rvalid(w_port__AXI_GPIO_1__s_axi_rvalid)
                                  , .s_axi_rready(w_port__AXI_GPIO_1__s_axi_rready)
                                  , .s_axi_aclk(w_port__AXI_GPIO_1__s_axi_aclk)
                                  , .s_axi_aresetn(w_port__AXI_GPIO_1__s_axi_aresetn)
                                  , .gpio_io_o(w_port__AXI_GPIO_1__gpio_io_o)
                                  , .gpio2_io_o(w_port__AXI_GPIO_1__gpio2_io_o) );

    system_AXI_Protocol_Converter_1 AXI_Protocol_Converter_1 ( 
                                                                .us_axi_awid(w_port__AXI_Protocol_Converter_1__us_axi_awid)
                                                              , .us_axi_awaddr(w_port__AXI_Protocol_Converter_1__us_axi_awaddr)
                                                              , .us_axi_awlen(w_port__AXI_Protocol_Converter_1__us_axi_awlen)
                                                              , .us_axi_awsize(w_port__AXI_Protocol_Converter_1__us_axi_awsize)
                                                              , .us_axi_awburst(w_port__AXI_Protocol_Converter_1__us_axi_awburst)
                                                              , .us_axi_awlock(w_port__AXI_Protocol_Converter_1__us_axi_awlock)
                                                              , .us_axi_awcache(w_port__AXI_Protocol_Converter_1__us_axi_awcache)
                                                              , .us_axi_awprot(w_port__AXI_Protocol_Converter_1__us_axi_awprot)
                                                              , .us_axi_awqos(w_port__AXI_Protocol_Converter_1__us_axi_awqos)
                                                              , .us_axi_awvalid(w_port__AXI_Protocol_Converter_1__us_axi_awvalid)
                                                              , .us_axi_awready(w_port__AXI_Protocol_Converter_1__us_axi_awready)
                                                              , .us_axi_wdata(w_port__AXI_Protocol_Converter_1__us_axi_wdata)
                                                              , .us_axi_wstrb(w_port__AXI_Protocol_Converter_1__us_axi_wstrb)
                                                              , .us_axi_wlast(w_port__AXI_Protocol_Converter_1__us_axi_wlast)
                                                              , .us_axi_wvalid(w_port__AXI_Protocol_Converter_1__us_axi_wvalid)
                                                              , .us_axi_wready(w_port__AXI_Protocol_Converter_1__us_axi_wready)
                                                              , .us_axi_bid(w_port__AXI_Protocol_Converter_1__us_axi_bid)
                                                              , .us_axi_bresp(w_port__AXI_Protocol_Converter_1__us_axi_bresp)
                                                              , .us_axi_bvalid(w_port__AXI_Protocol_Converter_1__us_axi_bvalid)
                                                              , .us_axi_bready(w_port__AXI_Protocol_Converter_1__us_axi_bready)
                                                              , .us_axi_arid(w_port__AXI_Protocol_Converter_1__us_axi_arid)
                                                              , .us_axi_araddr(w_port__AXI_Protocol_Converter_1__us_axi_araddr)
                                                              , .us_axi_arlen(w_port__AXI_Protocol_Converter_1__us_axi_arlen)
                                                              , .us_axi_arsize(w_port__AXI_Protocol_Converter_1__us_axi_arsize)
                                                              , .us_axi_arburst(w_port__AXI_Protocol_Converter_1__us_axi_arburst)
                                                              , .us_axi_arlock(w_port__AXI_Protocol_Converter_1__us_axi_arlock)
                                                              , .us_axi_arcache(w_port__AXI_Protocol_Converter_1__us_axi_arcache)
                                                              , .us_axi_arprot(w_port__AXI_Protocol_Converter_1__us_axi_arprot)
                                                              , .us_axi_arqos(w_port__AXI_Protocol_Converter_1__us_axi_arqos)
                                                              , .us_axi_arvalid(w_port__AXI_Protocol_Converter_1__us_axi_arvalid)
                                                              , .us_axi_arready(w_port__AXI_Protocol_Converter_1__us_axi_arready)
                                                              , .us_axi_rid(w_port__AXI_Protocol_Converter_1__us_axi_rid)
                                                              , .us_axi_rdata(w_port__AXI_Protocol_Converter_1__us_axi_rdata)
                                                              , .us_axi_rresp(w_port__AXI_Protocol_Converter_1__us_axi_rresp)
                                                              , .us_axi_rlast(w_port__AXI_Protocol_Converter_1__us_axi_rlast)
                                                              , .us_axi_rvalid(w_port__AXI_Protocol_Converter_1__us_axi_rvalid)
                                                              , .us_axi_rready(w_port__AXI_Protocol_Converter_1__us_axi_rready)
                                                              , .aclk(w_port__AXI_Protocol_Converter_1__aclk)
                                                              , .aresetn(w_port__AXI_Protocol_Converter_1__aresetn)
                                                              , .ds_axi_awaddr(w_port__AXI_Protocol_Converter_1__ds_axi_awaddr)
                                                              , .ds_axi_awprot()
                                                              , .ds_axi_awvalid(w_port__AXI_Protocol_Converter_1__ds_axi_awvalid)
                                                              , .ds_axi_awready(w_port__AXI_Protocol_Converter_1__ds_axi_awready)
                                                              , .ds_axi_wdata(w_port__AXI_Protocol_Converter_1__ds_axi_wdata)
                                                              , .ds_axi_wstrb(w_port__AXI_Protocol_Converter_1__ds_axi_wstrb)
                                                              , .ds_axi_wvalid(w_port__AXI_Protocol_Converter_1__ds_axi_wvalid)
                                                              , .ds_axi_wready(w_port__AXI_Protocol_Converter_1__ds_axi_wready)
                                                              , .ds_axi_bresp(w_port__AXI_Protocol_Converter_1__ds_axi_bresp)
                                                              , .ds_axi_bvalid(w_port__AXI_Protocol_Converter_1__ds_axi_bvalid)
                                                              , .ds_axi_bready(w_port__AXI_Protocol_Converter_1__ds_axi_bready)
                                                              , .ds_axi_araddr(w_port__AXI_Protocol_Converter_1__ds_axi_araddr)
                                                              , .ds_axi_arprot()
                                                              , .ds_axi_arvalid(w_port__AXI_Protocol_Converter_1__ds_axi_arvalid)
                                                              , .ds_axi_arready(w_port__AXI_Protocol_Converter_1__ds_axi_arready)
                                                              , .ds_axi_rdata(w_port__AXI_Protocol_Converter_1__ds_axi_rdata)
                                                              , .ds_axi_rresp(w_port__AXI_Protocol_Converter_1__ds_axi_rresp)
                                                              , .ds_axi_rvalid(w_port__AXI_Protocol_Converter_1__ds_axi_rvalid)
                                                              , .ds_axi_rready(w_port__AXI_Protocol_Converter_1__ds_axi_rready) );

    system_AXI_Matrix_0 AXI_Matrix_0 ( 
                                        .us0_araddr(w_port__AXI_Matrix_0__us0_araddr)
                                      , .us0_arburst(w_port__AXI_Matrix_0__us0_arburst)
                                      , .us0_arcache(w_port__AXI_Matrix_0__us0_arcache)
                                      , .us0_arid(w_port__AXI_Matrix_0__us0_arid)
                                      , .us0_arlen(w_port__AXI_Matrix_0__us0_arlen)
                                      , .us0_arlock(w_port__AXI_Matrix_0__us0_arlock)
                                      , .us0_arprot(w_port__AXI_Matrix_0__us0_arprot)
                                      , .us0_arqos(4'b0)
                                      , .us0_arready(w_port__AXI_Matrix_0__us0_arready)
                                      , .us0_arsize(w_port__AXI_Matrix_0__us0_arsize)
                                      , .us0_arvalid(w_port__AXI_Matrix_0__us0_arvalid)
                                      , .us0_awaddr(w_port__AXI_Matrix_0__us0_awaddr)
                                      , .us0_awburst(w_port__AXI_Matrix_0__us0_awburst)
                                      , .us0_awcache(w_port__AXI_Matrix_0__us0_awcache)
                                      , .us0_awid(w_port__AXI_Matrix_0__us0_awid)
                                      , .us0_awlen(w_port__AXI_Matrix_0__us0_awlen)
                                      , .us0_awlock(w_port__AXI_Matrix_0__us0_awlock)
                                      , .us0_awprot(w_port__AXI_Matrix_0__us0_awprot)
                                      , .us0_awqos(4'b0)
                                      , .us0_awready(w_port__AXI_Matrix_0__us0_awready)
                                      , .us0_awsize(w_port__AXI_Matrix_0__us0_awsize)
                                      , .us0_awvalid(w_port__AXI_Matrix_0__us0_awvalid)
                                      , .us0_bid(w_port__AXI_Matrix_0__us0_bid)
                                      , .us0_bready(w_port__AXI_Matrix_0__us0_bready)
                                      , .us0_bresp(w_port__AXI_Matrix_0__us0_bresp)
                                      , .us0_bvalid(w_port__AXI_Matrix_0__us0_bvalid)
                                      , .us0_rdata(w_port__AXI_Matrix_0__us0_rdata)
                                      , .us0_rid(w_port__AXI_Matrix_0__us0_rid)
                                      , .us0_rlast(w_port__AXI_Matrix_0__us0_rlast)
                                      , .us0_rready(w_port__AXI_Matrix_0__us0_rready)
                                      , .us0_rresp(w_port__AXI_Matrix_0__us0_rresp)
                                      , .us0_rvalid(w_port__AXI_Matrix_0__us0_rvalid)
                                      , .us0_wdata(w_port__AXI_Matrix_0__us0_wdata)
                                      , .us0_wlast(w_port__AXI_Matrix_0__us0_wlast)
                                      , .us0_wready(w_port__AXI_Matrix_0__us0_wready)
                                      , .us0_wstrb(w_port__AXI_Matrix_0__us0_wstrb)
                                      , .us0_wvalid(w_port__AXI_Matrix_0__us0_wvalid)
                                      , .aclk(w_port__AXI_Matrix_0__aclk)
                                      , .aresetn(w_port__AXI_Matrix_0__aresetn)
                                      , .ds0_araddr(w_port__AXI_Matrix_0__ds0_araddr)
                                      , .ds0_arburst(w_port__AXI_Matrix_0__ds0_arburst)
                                      , .ds0_arcache(w_port__AXI_Matrix_0__ds0_arcache)
                                      , .ds0_arid(w_port__AXI_Matrix_0__ds0_arid)
                                      , .ds0_arlen(w_port__AXI_Matrix_0__ds0_arlen)
                                      , .ds0_arlock(w_port__AXI_Matrix_0__ds0_arlock)
                                      , .ds0_arprot(w_port__AXI_Matrix_0__ds0_arprot)
                                      , .ds0_arqos(w_port__AXI_Matrix_0__ds0_arqos)
                                      , .ds0_arregion()
                                      , .ds0_arready(w_port__AXI_Matrix_0__ds0_arready)
                                      , .ds0_arsize(w_port__AXI_Matrix_0__ds0_arsize)
                                      , .ds0_arvalid(w_port__AXI_Matrix_0__ds0_arvalid)
                                      , .ds0_awaddr(w_port__AXI_Matrix_0__ds0_awaddr)
                                      , .ds0_awburst(w_port__AXI_Matrix_0__ds0_awburst)
                                      , .ds0_awcache(w_port__AXI_Matrix_0__ds0_awcache)
                                      , .ds0_awid(w_port__AXI_Matrix_0__ds0_awid)
                                      , .ds0_awlen(w_port__AXI_Matrix_0__ds0_awlen)
                                      , .ds0_awlock(w_port__AXI_Matrix_0__ds0_awlock)
                                      , .ds0_awprot(w_port__AXI_Matrix_0__ds0_awprot)
                                      , .ds0_awqos(w_port__AXI_Matrix_0__ds0_awqos)
                                      , .ds0_awregion()
                                      , .ds0_awready(w_port__AXI_Matrix_0__ds0_awready)
                                      , .ds0_awsize(w_port__AXI_Matrix_0__ds0_awsize)
                                      , .ds0_awvalid(w_port__AXI_Matrix_0__ds0_awvalid)
                                      , .ds0_bid(w_port__AXI_Matrix_0__ds0_bid)
                                      , .ds0_bready(w_port__AXI_Matrix_0__ds0_bready)
                                      , .ds0_bresp(w_port__AXI_Matrix_0__ds0_bresp)
                                      , .ds0_bvalid(w_port__AXI_Matrix_0__ds0_bvalid)
                                      , .ds0_rdata(w_port__AXI_Matrix_0__ds0_rdata)
                                      , .ds0_rid(w_port__AXI_Matrix_0__ds0_rid)
                                      , .ds0_rlast(w_port__AXI_Matrix_0__ds0_rlast)
                                      , .ds0_rready(w_port__AXI_Matrix_0__ds0_rready)
                                      , .ds0_rresp(w_port__AXI_Matrix_0__ds0_rresp)
                                      , .ds0_rvalid(w_port__AXI_Matrix_0__ds0_rvalid)
                                      , .ds0_wdata(w_port__AXI_Matrix_0__ds0_wdata)
                                      , .ds0_wlast(w_port__AXI_Matrix_0__ds0_wlast)
                                      , .ds0_wready(w_port__AXI_Matrix_0__ds0_wready)
                                      , .ds0_wstrb(w_port__AXI_Matrix_0__ds0_wstrb)
                                      , .ds0_wvalid(w_port__AXI_Matrix_0__ds0_wvalid)
                                      , .ds1_araddr(w_port__AXI_Matrix_0__ds1_araddr)
                                      , .ds1_arburst(w_port__AXI_Matrix_0__ds1_arburst)
                                      , .ds1_arcache(w_port__AXI_Matrix_0__ds1_arcache)
                                      , .ds1_arid(w_port__AXI_Matrix_0__ds1_arid)
                                      , .ds1_arlen(w_port__AXI_Matrix_0__ds1_arlen)
                                      , .ds1_arlock(w_port__AXI_Matrix_0__ds1_arlock)
                                      , .ds1_arprot(w_port__AXI_Matrix_0__ds1_arprot)
                                      , .ds1_arqos(w_port__AXI_Matrix_0__ds1_arqos)
                                      , .ds1_arregion()
                                      , .ds1_arready(w_port__AXI_Matrix_0__ds1_arready)
                                      , .ds1_arsize(w_port__AXI_Matrix_0__ds1_arsize)
                                      , .ds1_arvalid(w_port__AXI_Matrix_0__ds1_arvalid)
                                      , .ds1_awaddr(w_port__AXI_Matrix_0__ds1_awaddr)
                                      , .ds1_awburst(w_port__AXI_Matrix_0__ds1_awburst)
                                      , .ds1_awcache(w_port__AXI_Matrix_0__ds1_awcache)
                                      , .ds1_awid(w_port__AXI_Matrix_0__ds1_awid)
                                      , .ds1_awlen(w_port__AXI_Matrix_0__ds1_awlen)
                                      , .ds1_awlock(w_port__AXI_Matrix_0__ds1_awlock)
                                      , .ds1_awprot(w_port__AXI_Matrix_0__ds1_awprot)
                                      , .ds1_awqos(w_port__AXI_Matrix_0__ds1_awqos)
                                      , .ds1_awregion()
                                      , .ds1_awready(w_port__AXI_Matrix_0__ds1_awready)
                                      , .ds1_awsize(w_port__AXI_Matrix_0__ds1_awsize)
                                      , .ds1_awvalid(w_port__AXI_Matrix_0__ds1_awvalid)
                                      , .ds1_bid(w_port__AXI_Matrix_0__ds1_bid)
                                      , .ds1_bready(w_port__AXI_Matrix_0__ds1_bready)
                                      , .ds1_bresp(w_port__AXI_Matrix_0__ds1_bresp)
                                      , .ds1_bvalid(w_port__AXI_Matrix_0__ds1_bvalid)
                                      , .ds1_rdata(w_port__AXI_Matrix_0__ds1_rdata)
                                      , .ds1_rid(w_port__AXI_Matrix_0__ds1_rid)
                                      , .ds1_rlast(w_port__AXI_Matrix_0__ds1_rlast)
                                      , .ds1_rready(w_port__AXI_Matrix_0__ds1_rready)
                                      , .ds1_rresp(w_port__AXI_Matrix_0__ds1_rresp)
                                      , .ds1_rvalid(w_port__AXI_Matrix_0__ds1_rvalid)
                                      , .ds1_wdata(w_port__AXI_Matrix_0__ds1_wdata)
                                      , .ds1_wlast(w_port__AXI_Matrix_0__ds1_wlast)
                                      , .ds1_wready(w_port__AXI_Matrix_0__ds1_wready)
                                      , .ds1_wstrb(w_port__AXI_Matrix_0__ds1_wstrb)
                                      , .ds1_wvalid(w_port__AXI_Matrix_0__ds1_wvalid)
                                      , .ds2_araddr(w_port__AXI_Matrix_0__ds2_araddr)
                                      , .ds2_arburst(w_port__AXI_Matrix_0__ds2_arburst)
                                      , .ds2_arcache(w_port__AXI_Matrix_0__ds2_arcache)
                                      , .ds2_arid(w_port__AXI_Matrix_0__ds2_arid)
                                      , .ds2_arlen(w_port__AXI_Matrix_0__ds2_arlen)
                                      , .ds2_arlock(w_port__AXI_Matrix_0__ds2_arlock)
                                      , .ds2_arprot(w_port__AXI_Matrix_0__ds2_arprot)
                                      , .ds2_arqos(w_port__AXI_Matrix_0__ds2_arqos)
                                      , .ds2_arregion()
                                      , .ds2_arready(w_port__AXI_Matrix_0__ds2_arready)
                                      , .ds2_arsize(w_port__AXI_Matrix_0__ds2_arsize)
                                      , .ds2_arvalid(w_port__AXI_Matrix_0__ds2_arvalid)
                                      , .ds2_awaddr(w_port__AXI_Matrix_0__ds2_awaddr)
                                      , .ds2_awburst(w_port__AXI_Matrix_0__ds2_awburst)
                                      , .ds2_awcache(w_port__AXI_Matrix_0__ds2_awcache)
                                      , .ds2_awid(w_port__AXI_Matrix_0__ds2_awid)
                                      , .ds2_awlen(w_port__AXI_Matrix_0__ds2_awlen)
                                      , .ds2_awlock(w_port__AXI_Matrix_0__ds2_awlock)
                                      , .ds2_awprot(w_port__AXI_Matrix_0__ds2_awprot)
                                      , .ds2_awqos(w_port__AXI_Matrix_0__ds2_awqos)
                                      , .ds2_awregion()
                                      , .ds2_awready(w_port__AXI_Matrix_0__ds2_awready)
                                      , .ds2_awsize(w_port__AXI_Matrix_0__ds2_awsize)
                                      , .ds2_awvalid(w_port__AXI_Matrix_0__ds2_awvalid)
                                      , .ds2_bid(w_port__AXI_Matrix_0__ds2_bid)
                                      , .ds2_bready(w_port__AXI_Matrix_0__ds2_bready)
                                      , .ds2_bresp(w_port__AXI_Matrix_0__ds2_bresp)
                                      , .ds2_bvalid(w_port__AXI_Matrix_0__ds2_bvalid)
                                      , .ds2_rdata(w_port__AXI_Matrix_0__ds2_rdata)
                                      , .ds2_rid(w_port__AXI_Matrix_0__ds2_rid)
                                      , .ds2_rlast(w_port__AXI_Matrix_0__ds2_rlast)
                                      , .ds2_rready(w_port__AXI_Matrix_0__ds2_rready)
                                      , .ds2_rresp(w_port__AXI_Matrix_0__ds2_rresp)
                                      , .ds2_rvalid(w_port__AXI_Matrix_0__ds2_rvalid)
                                      , .ds2_wdata(w_port__AXI_Matrix_0__ds2_wdata)
                                      , .ds2_wlast(w_port__AXI_Matrix_0__ds2_wlast)
                                      , .ds2_wready(w_port__AXI_Matrix_0__ds2_wready)
                                      , .ds2_wstrb(w_port__AXI_Matrix_0__ds2_wstrb)
                                      , .ds2_wvalid(w_port__AXI_Matrix_0__ds2_wvalid) );

    system_PWM_0 PWM_0 ( 
                          .clk(w_port__PWM_0__clk)
                        , .rst_n(w_port__PWM_0__rst_n)
                        , .DUTY_VALUE(w_port__PWM_0__DUTY_VALUE)
                        , .RELOAD_VALUE(w_port__PWM_0__RELOAD_VALUE)
                        , .pwm_out(w_port__PWM_0__pwm_out) );

    system_Processor_System_Reset_0 Processor_System_Reset_0 ( 
                                                                .clk(w_port__Processor_System_Reset_0__clk)
                                                              , .external_reset(w_port__Processor_System_Reset_0__external_reset)
                                                              , .aux_rst(1'b0)
                                                              , .system_rst(1'b0)
                                                              , .pll_locked(w_port__Processor_System_Reset_0__pll_locked)
                                                              , .soc_reset()
                                                              , .bus_reset()
                                                              , .peripheral_reset()
                                                              , .interconnect_aresetn()
                                                              , .peripheral_aresetn() );

    system_Constant_0 Constant_0 ( 
                                    .dout(w_port__Constant_0__dout) );

    system_axi_lite_pwm_0 axi_lite_pwm_0 ( 
                                            .s_axi_awaddr(w_port__axi_lite_pwm_0__s_axi_awaddr)
                                          , .s_axi_awvalid(w_port__axi_lite_pwm_0__s_axi_awvalid)
                                          , .s_axi_awready(w_port__axi_lite_pwm_0__s_axi_awready)
                                          , .s_axi_wdata(w_port__axi_lite_pwm_0__s_axi_wdata)
                                          , .s_axi_wstrb(w_port__axi_lite_pwm_0__s_axi_wstrb)
                                          , .s_axi_wvalid(w_port__axi_lite_pwm_0__s_axi_wvalid)
                                          , .s_axi_wready(w_port__axi_lite_pwm_0__s_axi_wready)
                                          , .s_axi_bresp(w_port__axi_lite_pwm_0__s_axi_bresp)
                                          , .s_axi_bvalid(w_port__axi_lite_pwm_0__s_axi_bvalid)
                                          , .s_axi_bready(w_port__axi_lite_pwm_0__s_axi_bready)
                                          , .s_axi_araddr(w_port__axi_lite_pwm_0__s_axi_araddr)
                                          , .s_axi_arvalid(w_port__axi_lite_pwm_0__s_axi_arvalid)
                                          , .s_axi_arready(w_port__axi_lite_pwm_0__s_axi_arready)
                                          , .s_axi_rdata(w_port__axi_lite_pwm_0__s_axi_rdata)
                                          , .s_axi_rresp(w_port__axi_lite_pwm_0__s_axi_rresp)
                                          , .s_axi_rvalid(w_port__axi_lite_pwm_0__s_axi_rvalid)
                                          , .s_axi_rready(w_port__axi_lite_pwm_0__s_axi_rready)
                                          , .s_axi_aclk(w_port__axi_lite_pwm_0__s_axi_aclk)
                                          , .s_axi_aresetn(w_port__axi_lite_pwm_0__s_axi_aresetn)
                                          , .pwm_out(w_port__axi_lite_pwm_0__pwm_out)
                                          , .motor_dir(w_port__axi_lite_pwm_0__motor_dir)
                                          , .motor_enable(w_port__axi_lite_pwm_0__motor_enable) );

    system_AXI_Protocol_Converter_2 AXI_Protocol_Converter_2 ( 
                                                                .us_axi_awid(w_port__AXI_Protocol_Converter_2__us_axi_awid)
                                                              , .us_axi_awaddr(w_port__AXI_Protocol_Converter_2__us_axi_awaddr)
                                                              , .us_axi_awlen(w_port__AXI_Protocol_Converter_2__us_axi_awlen)
                                                              , .us_axi_awsize(w_port__AXI_Protocol_Converter_2__us_axi_awsize)
                                                              , .us_axi_awburst(w_port__AXI_Protocol_Converter_2__us_axi_awburst)
                                                              , .us_axi_awlock(w_port__AXI_Protocol_Converter_2__us_axi_awlock)
                                                              , .us_axi_awcache(w_port__AXI_Protocol_Converter_2__us_axi_awcache)
                                                              , .us_axi_awprot(w_port__AXI_Protocol_Converter_2__us_axi_awprot)
                                                              , .us_axi_awqos(w_port__AXI_Protocol_Converter_2__us_axi_awqos)
                                                              , .us_axi_awvalid(w_port__AXI_Protocol_Converter_2__us_axi_awvalid)
                                                              , .us_axi_awready(w_port__AXI_Protocol_Converter_2__us_axi_awready)
                                                              , .us_axi_wdata(w_port__AXI_Protocol_Converter_2__us_axi_wdata)
                                                              , .us_axi_wstrb(w_port__AXI_Protocol_Converter_2__us_axi_wstrb)
                                                              , .us_axi_wlast(w_port__AXI_Protocol_Converter_2__us_axi_wlast)
                                                              , .us_axi_wvalid(w_port__AXI_Protocol_Converter_2__us_axi_wvalid)
                                                              , .us_axi_wready(w_port__AXI_Protocol_Converter_2__us_axi_wready)
                                                              , .us_axi_bid(w_port__AXI_Protocol_Converter_2__us_axi_bid)
                                                              , .us_axi_bresp(w_port__AXI_Protocol_Converter_2__us_axi_bresp)
                                                              , .us_axi_bvalid(w_port__AXI_Protocol_Converter_2__us_axi_bvalid)
                                                              , .us_axi_bready(w_port__AXI_Protocol_Converter_2__us_axi_bready)
                                                              , .us_axi_arid(w_port__AXI_Protocol_Converter_2__us_axi_arid)
                                                              , .us_axi_araddr(w_port__AXI_Protocol_Converter_2__us_axi_araddr)
                                                              , .us_axi_arlen(w_port__AXI_Protocol_Converter_2__us_axi_arlen)
                                                              , .us_axi_arsize(w_port__AXI_Protocol_Converter_2__us_axi_arsize)
                                                              , .us_axi_arburst(w_port__AXI_Protocol_Converter_2__us_axi_arburst)
                                                              , .us_axi_arlock(w_port__AXI_Protocol_Converter_2__us_axi_arlock)
                                                              , .us_axi_arcache(w_port__AXI_Protocol_Converter_2__us_axi_arcache)
                                                              , .us_axi_arprot(w_port__AXI_Protocol_Converter_2__us_axi_arprot)
                                                              , .us_axi_arqos(w_port__AXI_Protocol_Converter_2__us_axi_arqos)
                                                              , .us_axi_arvalid(w_port__AXI_Protocol_Converter_2__us_axi_arvalid)
                                                              , .us_axi_arready(w_port__AXI_Protocol_Converter_2__us_axi_arready)
                                                              , .us_axi_rid(w_port__AXI_Protocol_Converter_2__us_axi_rid)
                                                              , .us_axi_rdata(w_port__AXI_Protocol_Converter_2__us_axi_rdata)
                                                              , .us_axi_rresp(w_port__AXI_Protocol_Converter_2__us_axi_rresp)
                                                              , .us_axi_rlast(w_port__AXI_Protocol_Converter_2__us_axi_rlast)
                                                              , .us_axi_rvalid(w_port__AXI_Protocol_Converter_2__us_axi_rvalid)
                                                              , .us_axi_rready(w_port__AXI_Protocol_Converter_2__us_axi_rready)
                                                              , .aclk(w_port__AXI_Protocol_Converter_2__aclk)
                                                              , .aresetn(w_port__AXI_Protocol_Converter_2__aresetn)
                                                              , .ds_axi_awaddr(w_port__AXI_Protocol_Converter_2__ds_axi_awaddr)
                                                              , .ds_axi_awprot()
                                                              , .ds_axi_awvalid(w_port__AXI_Protocol_Converter_2__ds_axi_awvalid)
                                                              , .ds_axi_awready(w_port__AXI_Protocol_Converter_2__ds_axi_awready)
                                                              , .ds_axi_wdata(w_port__AXI_Protocol_Converter_2__ds_axi_wdata)
                                                              , .ds_axi_wstrb(w_port__AXI_Protocol_Converter_2__ds_axi_wstrb)
                                                              , .ds_axi_wvalid(w_port__AXI_Protocol_Converter_2__ds_axi_wvalid)
                                                              , .ds_axi_wready(w_port__AXI_Protocol_Converter_2__ds_axi_wready)
                                                              , .ds_axi_bresp(w_port__AXI_Protocol_Converter_2__ds_axi_bresp)
                                                              , .ds_axi_bvalid(w_port__AXI_Protocol_Converter_2__ds_axi_bvalid)
                                                              , .ds_axi_bready(w_port__AXI_Protocol_Converter_2__ds_axi_bready)
                                                              , .ds_axi_araddr(w_port__AXI_Protocol_Converter_2__ds_axi_araddr)
                                                              , .ds_axi_arprot()
                                                              , .ds_axi_arvalid(w_port__AXI_Protocol_Converter_2__ds_axi_arvalid)
                                                              , .ds_axi_arready(w_port__AXI_Protocol_Converter_2__ds_axi_arready)
                                                              , .ds_axi_rdata(w_port__AXI_Protocol_Converter_2__ds_axi_rdata)
                                                              , .ds_axi_rresp(w_port__AXI_Protocol_Converter_2__ds_axi_rresp)
                                                              , .ds_axi_rvalid(w_port__AXI_Protocol_Converter_2__ds_axi_rvalid)
                                                              , .ds_axi_rready(w_port__AXI_Protocol_Converter_2__ds_axi_rready) );

endmodule
