

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
`timescale 1ns / 1ns

// 2026-10-29 改造：接入 AXI PWM
//   pwm_out[2:0] -> 板载 LED1/LED2/LED3（T19 / R19 / J15）
//   motor_enable -> 板载 LED4（M20），C 里写 CTRL[3] 即点亮，用于确认寄存器可写
//   motor_dir    -> 暂接常量 0；接电机驱动板时再改到 J12/CEP 并补引脚
module system_top
(
inout  wire         GPIO,
inout  wire         GPIO_1,
output wire [2:0]   pwm_out,
output wire         motor_enable
);

// motor_dir 暂不引出：不能直接写 .motor_dir(2'b00)，Verilog 不允许输出端口接常量表达式，
// 必须先给一根真实 net 再闲置不用。接电机驱动板时把这里换成 J12 的引脚。
wire [1:0] motor_dir_nc;

system I_system
(
.GPIO           (GPIO),
.GPIO_1         (GPIO_1),
.pwm_out        (pwm_out),
.motor_dir      (motor_dir_nc),
.motor_enable   (motor_enable)
) ;

endmodule
