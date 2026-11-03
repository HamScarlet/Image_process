

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
//
// 2026-10-31 V3 改造（方向位 + STBY 引出到 J12）：
//   GPIO_1_gpio_io_o  1 位 -> 4 位，作为 TB6612 的 AIN1/AIN2/BIN1/BIN2
//                DI 里 AXI_GPIO_1 的两个参数一起改了：
//                  AL_GPIO_WD       1 -> 4
//                  AL_ALL_OUT_PORTS 0 -> 1  （All Outputs）
//                所以 IP 端口是 output [3:0] gpio_io_o，顶层这里是 output 而不是 inout。
//                连带好处：AL_RESET_TRI = 0，复位即全输出，不存在"上电高阻写不出去"的坑。
//                ⚠ 端口名沿用 DI 自动生成的 GPIO_1_gpio_io_o（不是 GPIO_1）。
//                  好处是名字自带实例号，不会再和 AXI_GPIO_0 搞混
//                  —— 之前那版 system.v 里 GPIO/GPIO_1 与实例号是交叉的，已在本版理顺：
//                     AXI_GPIO_1 -> GPIO_1_gpio_io_o   (system.v:1908)
//                     AXI_GPIO_0 -> GPIO               (system.v:1904)
//   stby         新增端口，与 motor_enable 同源：LED4 留作判据，STBY 走 J12 PIN 17
//
// 2026-11-02 V8 改造（控制层最小闭环）：加蓝牙 + 超声，STBY 与使能解耦
//   motor_enable -> M20 (LED4) : 门控后的电机使能（15 cm 内且前进时被拉低）
//   motor_stby   -> Y7         : 原始 CTRL[3]，**不参与门控**
//   sonar_trig   -> Y6         : HC-SR04 TRIG
//   sonar_echo   <- Y8         : HC-SR04 ECHO
//   bt_tx        -> T9 (PIN 5) : 蓝牙模块 RX（本端发送）
//   bt_rx        <- T5 (PIN 7) : 蓝牙模块 TX（本端接收）
//
//   ⚠️ stby 不再等于 motor_enable。V8 起 motor_enable 会被超声门控拉低，
//      而 STBY 若跟着掉，整片 TB6612（含 B 通道）都会失能 ——
//      从 0x5 切 0xA 的瞬间会多出一段"整片不响应"的窗口，换向手感会断。
//      所以这里拆成两根：一根给 LED4 看现象，一根给 TB6612 保供电。
module system_top
(
output wire [3:0]   GPIO_1_gpio_io_o,
inout  wire         GPIO,
output wire [2:0]   pwm_out,
output wire         motor_enable,
output wire         motor_stby,
output wire         sonar_trig,
input  wire         sonar_echo,
output wire         bt_tx,
input  wire         bt_rx
);

// motor_dir 不引出：方向由 GPIO_1_gpio_io_o 四位直驱 TB6612（V8 定案），
// axi_lite_pwm 的 motor_dir 输出只保留寄存器回读语义，没有引脚落地。
// 也不能直接写 .motor_dir(2'b00)，Verilog 不允许输出端口接常量表达式。
wire [1:0] motor_dir_nc;

system I_system
(
.GPIO               (GPIO),
.GPIO_1_gpio_io_o   (GPIO_1_gpio_io_o),
.pwm_out            (pwm_out),
.motor_dir          (motor_dir_nc),
.motor_enable       (motor_enable),
.motor_stby         (motor_stby),
.sonar_trig         (sonar_trig),
.sonar_echo         (sonar_echo),
.bt_tx              (bt_tx),
.bt_rx              (bt_rx)
) ;

endmodule
