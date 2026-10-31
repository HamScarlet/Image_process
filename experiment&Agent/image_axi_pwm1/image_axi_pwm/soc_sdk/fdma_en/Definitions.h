/*
 * Definitions.h - AXI 从端基址与寄存器偏移
 *
 * 基址由 Design Integrator 的 Address Editor 分配，每个从端占 1 MB 槽位：
 *   0x80000000  AXI_GPIO_0    -> O_code_driver[3:0]（图像链路原有，保留）
 *   0x80100000  AXI_GPIO_1    -> 本期不再使用，槽位保留
 *   0x80200000  axi_lite_pwm  -> 三通道 PWM + 电机使能/方向（见 TIM_PWM.h）
 *
 * 注意：宏必须整体加括号，否则在表达式里展开会算错。
 */

#ifndef DEFINITIONS_H_
#define DEFINITIONS_H_

#define AXI_GPIO0_BASE          0x80000000U
#define AXI_GPIO1_BASE          0x80100000U

/* AXI GPIO 通道寄存器：base + 0x0 = DATA，base + 0x4 = TRI（1=输入） */
#define AXI_GPIO_DAT_OFF        0x00U
#define AXI_GPIO_TRI_OFF        0x04U

#define AXI_GPIO0_DAT_REG       (AXI_GPIO0_BASE + AXI_GPIO_DAT_OFF)
#define AXI_GPIO0_TRI_REG       (AXI_GPIO0_BASE + AXI_GPIO_TRI_OFF)
#define AXI_GPIO1_DAT_REG       (AXI_GPIO1_BASE + AXI_GPIO_DAT_OFF)
#define AXI_GPIO1_TRI_REG       (AXI_GPIO1_BASE + AXI_GPIO_TRI_OFF)

#endif /* DEFINITIONS_H_ */
