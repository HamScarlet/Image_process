module system(
    input I_sysclk,
    inout key,
    inout led
 );

// Instantiate the module 
wire    [1:0]                             GPIO_pl_gpio_io; 
wire                                      p2f_clk0; 
assign p2f_clk0=I_sysclk;

ARMandgpioDesign u_ARMandgpioDesign (  
    .GPIO_pl_gpio_io    ({led,key}    ), 
    .p2f_clk0           (p2f_clk0           )
); 

endmodule
