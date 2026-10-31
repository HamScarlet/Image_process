/*
 * TIM_PWM.h - PS 侧驱动：AXI4-Lite 三通道 PWM（PL 侧 axi_lite_pwm）
 *
 * 基址 0x80200000 / 4 KB，由 DI Address Editor 分配（DS_AXI2 -> Converter_2 -> S_AXI）。
 * 寄存器语义见 soc_prj/uisrc/03_ip/axi_lite_pwm/axi_lite_pwm.v 头部注释。
 *
 * 用法：
 *   PWM_Init();                       // 配 PSC/ARR、提交、使能通道
 *   PWM_SetDuty(0, 5000);             // 占空比 50%
 *   PWM_Commit(PWM_CH_MASK(0));       // 在下一个周期边界生效
 */

#ifndef TIM_PWM_H
#define TIM_PWM_H

#include "ui_type.h"

/* ---------------- 基址 ---------------- */
#define AXI_PWM_BASE            0x80200000U

/* ---------------- 寄存器偏移 ---------------- */
#define PWM_REG_CTRL            0x00U   /* [0..2] 通道使能  [3] 电机使能 */
#define PWM_REG_DIR             0x04U   /* [0..1] 电机方向 */
#define PWM_REG_STATUS          0x08U   /* [2:0] 待更新  [5:3] 使能  [6] 电机使能 */
#define PWM_REG_VERSION         0x0CU   /* 只读，固定 0x00010000 */
#define PWM_REG_UPDATE          0x40U   /* 写 1 到 bit[n] 提交通道 n */
#define PWM_REG_CH_PSC(ch)      (0x10U + (u32)(ch) * 0x10U)
#define PWM_REG_CH_ARR(ch)      (0x14U + (u32)(ch) * 0x10U)
#define PWM_REG_CH_CCR(ch)      (0x18U + (u32)(ch) * 0x10U)

/* ---------------- 位定义 ---------------- */
#define PWM_CTRL_CH_EN(ch)      (1U << (ch))
#define PWM_CTRL_MOTOR_EN       (1U << 3)
#define PWM_UPDATE_CH(ch)       (1U << (ch))

/* ---------------- 通道与默认参数 ---------------- */
#define PWM_CH0                 0U      /* pwm_out[0]，呼吸灯用这一路 */
#define PWM_CH1                 1U
#define PWM_CH2                 2U

#define PWM_VERSION_EXPECT      0x00010000U

#define PWM_DEFAULT_PSC         0U
#define PWM_DEFAULT_ARR         9999U   /* 49.995 MHz / 10000 = 4.9995 kHz */
#define PWM_SERVO_ARR           3999599U /* 49.995 MHz / 4e6 ≈ 12.5 Hz */

/* ---------------- API ---------------- */

/* 读 VERSION 寄存器，用于确认 AXI 通路是否打通 */
u32  PWM_ReadVersion(void);

/* 读 STATUS：[2:0] 待更新标志，[5:3] 通道使能，[6] 电机使能 */
u32  PWM_ReadStatus(void);

/* 写-读回自检，返回 0 表示寄存器可读可写；返回非 0 为出错步骤号 */
u32  PWM_SelfTest(void);

/* 读任意寄存器偏移，调试用（偏移见上面的宏） */
u32  PWM_ReadReg(u32 offset);

/* 配置三通道的 PSC/ARR/CCR 并提交、使能 CH0+CH1（电机用两路） */
void PWM_Init(void);

/* 直接写影子寄存器（下一周期边界才生效，需再调 PWM_Commit） */
void PWM_SetTiming(u32 ch, u32 psc, u32 arr, u32 ccr);
void PWM_SetDuty(u32 ch, u32 ccr);

/* 提交：写 1 到对应 bit，通道在下一个周期回绕点整体切换新参数 */
void PWM_Commit(u32 ch_mask);

/* 通道使能 / 全部关闭 */
void PWM_Enable(u32 ch_mask);
void PWM_DisableAll(void);

/* 电机控制：dir 写 DIR[1:0]，en 写 CTRL[3]（不影响 PWM 输出） */
void PWM_SetMotor(u32 dir, u32 en);

/* 呼吸灯：ch 通道占空比 0 -> arr -> 0 循环，step 为占空比步长，step_ms 为每级停留毫秒 */
void PWM_Breath(u32 ch, u32 arr, u32 step, u32 step_ms);

#endif /* TIM_PWM_H */
