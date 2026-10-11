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
    output    wire              p2f_clk0 ,
    output    wire              p2f_rst0_n ,
    output    wire              O_fdma_wbusy ,
    output    wire              O_fdma_wvalid ,
    output    wire              O_fdma_rbusy ,
    output    wire              O_fdma_rvalid ,
    output    wire       [63:0] O_fdma_rdata ,
    output    wire              pl_gpio_out
); 
    wire              w_port__ARM_Processor_System_0__p2f_clk0 ;
    wire              w_port__ARM_Processor_System_0__slave_hp0_axi_aclk ;
    wire              w_port__uiFDMA_0__M_AXI_ACLK ;
    wire              w_net__ARM_Processor_System_0__p2f_clk0 ; 

    wire              w_port__ARM_Processor_System_0__p2f_rst0_n ;
    wire              w_port__uiFDMA_0__M_AXI_ARESETN ;
    wire              w_net__ARM_Processor_System_0__p2f_rst0_n ; 

    wire [0:0]        w_port__ARM_Processor_System_0__pl_gpio_out ;
    wire [0:0]        w_net__ARM_Processor_System_0__pl_gpio_out ; 

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

    assign w_net__ARM_Processor_System_0__p2f_clk0 = w_port__ARM_Processor_System_0__p2f_clk0 ;
    assign p2f_clk0 = w_net__ARM_Processor_System_0__p2f_clk0 ;
    assign w_port__ARM_Processor_System_0__slave_hp0_axi_aclk = w_net__ARM_Processor_System_0__p2f_clk0 ;
    assign w_port__uiFDMA_0__M_AXI_ACLK = w_net__ARM_Processor_System_0__p2f_clk0 ;

    assign w_net__ARM_Processor_System_0__p2f_rst0_n = w_port__ARM_Processor_System_0__p2f_rst0_n ;
    assign p2f_rst0_n = w_net__ARM_Processor_System_0__p2f_rst0_n ;
    assign w_port__uiFDMA_0__M_AXI_ARESETN = w_net__ARM_Processor_System_0__p2f_rst0_n ;

    assign w_net__ARM_Processor_System_0__pl_gpio_out = w_port__ARM_Processor_System_0__pl_gpio_out ;
    assign pl_gpio_out = w_net__ARM_Processor_System_0__pl_gpio_out ;

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
                                                            .slave_hp0_axi_awid(w_port__ARM_Processor_System_0__slave_hp0_axi_awid)
                                                          , .slave_hp0_axi_awaddr(w_port__ARM_Processor_System_0__slave_hp0_axi_awaddr)
                                                          , .slave_hp0_axi_awlen(w_port__ARM_Processor_System_0__slave_hp0_axi_awlen)
                                                          , .slave_hp0_axi_awsize(w_port__ARM_Processor_System_0__slave_hp0_axi_awsize)
                                                          , .slave_hp0_axi_awburst(w_port__ARM_Processor_System_0__slave_hp0_axi_awburst)
                                                          , .slave_hp0_axi_awlock(w_port__ARM_Processor_System_0__slave_hp0_axi_awlock)
                                                          , .slave_hp0_axi_awcache(w_port__ARM_Processor_System_0__slave_hp0_axi_awcache)
                                                          , .slave_hp0_axi_awprot(w_port__ARM_Processor_System_0__slave_hp0_axi_awprot)
                                                          , .slave_hp0_axi_awvalid(w_port__ARM_Processor_System_0__slave_hp0_axi_awvalid)
                                                          , .slave_hp0_axi_awready(w_port__ARM_Processor_System_0__slave_hp0_axi_awready)
                                                          , .slave_hp0_axi_wdata(w_port__ARM_Processor_System_0__slave_hp0_axi_wdata)
                                                          , .slave_hp0_axi_wstrb(w_port__ARM_Processor_System_0__slave_hp0_axi_wstrb)
                                                          , .slave_hp0_axi_wlast(w_port__ARM_Processor_System_0__slave_hp0_axi_wlast)
                                                          , .slave_hp0_axi_wvalid(w_port__ARM_Processor_System_0__slave_hp0_axi_wvalid)
                                                          , .slave_hp0_axi_wready(w_port__ARM_Processor_System_0__slave_hp0_axi_wready)
                                                          , .slave_hp0_axi_bid(w_port__ARM_Processor_System_0__slave_hp0_axi_bid)
                                                          , .slave_hp0_axi_bresp(w_port__ARM_Processor_System_0__slave_hp0_axi_bresp)
                                                          , .slave_hp0_axi_bvalid(w_port__ARM_Processor_System_0__slave_hp0_axi_bvalid)
                                                          , .slave_hp0_axi_bready(w_port__ARM_Processor_System_0__slave_hp0_axi_bready)
                                                          , .slave_hp0_axi_arid(w_port__ARM_Processor_System_0__slave_hp0_axi_arid)
                                                          , .slave_hp0_axi_araddr(w_port__ARM_Processor_System_0__slave_hp0_axi_araddr)
                                                          , .slave_hp0_axi_arlen(w_port__ARM_Processor_System_0__slave_hp0_axi_arlen)
                                                          , .slave_hp0_axi_arsize(w_port__ARM_Processor_System_0__slave_hp0_axi_arsize)
                                                          , .slave_hp0_axi_arburst(w_port__ARM_Processor_System_0__slave_hp0_axi_arburst)
                                                          , .slave_hp0_axi_arlock(w_port__ARM_Processor_System_0__slave_hp0_axi_arlock)
                                                          , .slave_hp0_axi_arcache(w_port__ARM_Processor_System_0__slave_hp0_axi_arcache)
                                                          , .slave_hp0_axi_arprot(w_port__ARM_Processor_System_0__slave_hp0_axi_arprot)
                                                          , .slave_hp0_axi_arvalid(w_port__ARM_Processor_System_0__slave_hp0_axi_arvalid)
                                                          , .slave_hp0_axi_arready(w_port__ARM_Processor_System_0__slave_hp0_axi_arready)
                                                          , .slave_hp0_axi_rid(w_port__ARM_Processor_System_0__slave_hp0_axi_rid)
                                                          , .slave_hp0_axi_rdata(w_port__ARM_Processor_System_0__slave_hp0_axi_rdata)
                                                          , .slave_hp0_axi_rresp(w_port__ARM_Processor_System_0__slave_hp0_axi_rresp)
                                                          , .slave_hp0_axi_rlast(w_port__ARM_Processor_System_0__slave_hp0_axi_rlast)
                                                          , .slave_hp0_axi_rvalid(w_port__ARM_Processor_System_0__slave_hp0_axi_rvalid)
                                                          , .slave_hp0_axi_rready(w_port__ARM_Processor_System_0__slave_hp0_axi_rready)
                                                          , .slave_hp0_axi_awqos(w_port__ARM_Processor_System_0__slave_hp0_axi_awqos)
                                                          , .slave_hp0_axi_arqos(w_port__ARM_Processor_System_0__slave_hp0_axi_arqos)
                                                          , .slave_hp0_axi_aclk(w_port__ARM_Processor_System_0__slave_hp0_axi_aclk)
                                                          , .pl_gpio_oe()
                                                          , .pl_gpio_out(w_port__ARM_Processor_System_0__pl_gpio_out)
                                                          , .pl_gpio_in(1'b0)
                                                          , .p2f_clk0(w_port__ARM_Processor_System_0__p2f_clk0)
                                                          , .p2f_rst0_n(w_port__ARM_Processor_System_0__p2f_rst0_n) );

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

endmodule
