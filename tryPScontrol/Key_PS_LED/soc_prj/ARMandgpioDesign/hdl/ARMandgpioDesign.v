/************************************************************\
**	Copyright (c) 2012-2026 anlogic Inc.
**	All Right Reserved.
\************************************************************/
/************************************************************\
**	Gen time	:	2026-10-11 18:54:42
**	DI version	:	197563 2026/05/12
**	App version	:	(build number:6.2.2.200067)
\************************************************************/

module ARMandgpioDesign (
    inout     wire        [1:0] GPIO_pl_gpio_io ,
    output    wire              p2f_clk0
); 
    wire              w_port__ARM_Processor_System_0__p2f_clk0 ;
    wire              w_net__ARM_Processor_System_0__p2f_clk0 ; 

    wire [1:0]        w_port__ARM_Processor_System_0__pl_gpio_oe ;
    wire [1:0]        w_net__ARM_Processor_System_0__pl_gpio_oe ; 

    wire [1:0]        w_port__ARM_Processor_System_0__pl_gpio_out ;
    wire [1:0]        w_net__ARM_Processor_System_0__pl_gpio_out ; 

    wire [1:0]        w_port__ARM_Processor_System_0__pl_gpio_in ;
    wire [1:0]        w_net__GPIO_pl_gpio_in ; 


    assign w_net__ARM_Processor_System_0__p2f_clk0 = w_port__ARM_Processor_System_0__p2f_clk0 ;
    assign p2f_clk0 = w_net__ARM_Processor_System_0__p2f_clk0 ;


    DR1_LOGIC_IOTRIBUF GPIO_pl_gpio_DR1_LOGIC_IOTRIBUF_0 (  .o(w_port__ARM_Processor_System_0__pl_gpio_in[0:0])
                                                          , .i(w_port__ARM_Processor_System_0__pl_gpio_out[0:0])
                                                          , .t(~w_port__ARM_Processor_System_0__pl_gpio_oe[0:0])
                                                          , .io(GPIO_pl_gpio_io[0:0]) );

    DR1_LOGIC_IOTRIBUF GPIO_pl_gpio_DR1_LOGIC_IOTRIBUF_1 (  .o(w_port__ARM_Processor_System_0__pl_gpio_in[1:1])
                                                          , .i(w_port__ARM_Processor_System_0__pl_gpio_out[1:1])
                                                          , .t(~w_port__ARM_Processor_System_0__pl_gpio_oe[1:1])
                                                          , .io(GPIO_pl_gpio_io[1:1]) );

    system_ARM_Processor_System_0 ARMandgpioDesign_ARM_Processor_System_0_Inst ( 
                                                                                  .pl_gpio_in(w_port__ARM_Processor_System_0__pl_gpio_in)
                                                                                , .pl_gpio_oe(w_port__ARM_Processor_System_0__pl_gpio_oe)
                                                                                , .pl_gpio_out(w_port__ARM_Processor_System_0__pl_gpio_out)
                                                                                , .p2f_clk0(w_port__ARM_Processor_System_0__p2f_clk0) );

endmodule
