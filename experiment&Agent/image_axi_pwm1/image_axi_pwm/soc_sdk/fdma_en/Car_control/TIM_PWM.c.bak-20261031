/*
 * TIM_PWM.c - PS 侧驱动：AXI4-Lite 三通道 PWM（PL 侧 axi_lite_pwm）
 *
 * 硬件行为要点（依 axi_lite_pwm.v 实测逻辑）：
 *   1. pwm = enable && (period_count < active_ccr)，高有效，占空比 = CCR/(ARR+1)
 *   2. f_pwm = 49.995 MHz / ((PSC+1) * (ARR+1))
 *   3. CCR/PSC/ARR 是影子寄存器，写 UPDATE 置位后要等下一个周期回绕点
 *      才整体切换（避免把脉冲截断），因此"写完立刻读回"读到的是影子值。
 *   4. CTRL[3] 只驱动 motor_enable 引脚，不门控 PWM 输出。
 */

#include "al_core.h"
#include "ui_io.h"
#include "TIM_PWM.h"

#define PWM_WR(off, val)    UI_Out32((void *)(AXI_PWM_BASE + (u32)(off)), (u32)(val))
#define PWM_RD(off)         UI_In32((void *)(AXI_PWM_BASE + (u32)(off)))

u32 PWM_ReadVersion(void)
{
    return PWM_RD(PWM_REG_VERSION);
}

u32 PWM_ReadStatus(void)
{
    return PWM_RD(PWM_REG_STATUS);
}

u32 PWM_ReadReg(u32 offset)
{
    return PWM_RD(offset);
}

u32 PWM_SelfTest(void)
{
    u32 ver;
    u32 pattern = 0x00001234U;

    ver = PWM_ReadVersion();
    if (ver != PWM_VERSION_EXPECT) {
        return 1U;
    }

    /* CCR 影子寄存器可读写，且不受 commit 影响，适合做回读测试 */
    PWM_WR(PWM_REG_CH_CCR(PWM_CH0), pattern);
    if (PWM_RD(PWM_REG_CH_CCR(PWM_CH0)) != pattern) {
        return 2U;
    }
    PWM_WR(PWM_REG_CH_CCR(PWM_CH0), 0U);

    return 0U;
}

void PWM_SetTiming(u32 ch, u32 psc, u32 arr, u32 ccr)
{
    PWM_WR(PWM_REG_CH_PSC(ch), psc);
    PWM_WR(PWM_REG_CH_ARR(ch), arr);
    PWM_WR(PWM_REG_CH_CCR(ch), ccr);
}

void PWM_SetDuty(u32 ch, u32 ccr)
{
    PWM_WR(PWM_REG_CH_CCR(ch), ccr);
}

void PWM_Commit(u32 ch_mask)
{
    PWM_WR(PWM_REG_UPDATE, ch_mask & 0x7U);
}

void PWM_Enable(u32 ch_mask)
{
    u32 ctrl = PWM_RD(PWM_REG_CTRL);

    ctrl = (ctrl | (ch_mask & 0x7U)) & 0x0FU;
    PWM_WR(PWM_REG_CTRL, ctrl);
}

void PWM_DisableAll(void)
{
    PWM_WR(PWM_REG_CTRL, 0U);
}

void PWM_SetMotor(u32 dir, u32 en)
{
    u32 ctrl = PWM_RD(PWM_REG_CTRL);

    PWM_WR(PWM_REG_DIR, dir & 0x3U);

    if (en) {
        ctrl |= PWM_CTRL_MOTOR_EN;
    } else {
        ctrl &= ~PWM_CTRL_MOTOR_EN;
    }
    PWM_WR(PWM_REG_CTRL, ctrl & 0x0FU);
}

void PWM_Init(void)
{
    /* 先整体清使能，避免配置过程中出毛刺 */
    PWM_DisableAll();

    /* CH0 / CH1：电机通道，4.9995 kHz（PSC=0, ARR=9999），初始占空比 0 */
    PWM_SetTiming(PWM_CH0, PWM_DEFAULT_PSC, PWM_DEFAULT_ARR, 0U);
    PWM_SetTiming(PWM_CH1, PWM_DEFAULT_PSC, PWM_DEFAULT_ARR, 0U);

    /* CH2：舵机通道，12.5 Hz，先不使能 */
    PWM_SetTiming(PWM_CH2, PWM_DEFAULT_PSC, PWM_SERVO_ARR, 0U);

    PWM_Commit(PWM_UPDATE_CH(PWM_CH0) | PWM_UPDATE_CH(PWM_CH1) | PWM_UPDATE_CH(PWM_CH2));

    /* 等一个周期让影子值切入（ARR+1 = 10000 拍 @49.995 MHz ≈ 0.2 ms） */
    AlSys_MDelay(1);

    PWM_Enable(PWM_CTRL_CH_EN(PWM_CH0) | PWM_CTRL_CH_EN(PWM_CH1));
}

void PWM_Breath(u32 ch, u32 arr, u32 step, u32 step_ms)
{
    int d;

    if (step == 0U) {
        step = 1U;
    }

    for (;;) {
        for (d = 0; d <= (int)arr; d += (int)step) {
            PWM_SetDuty(ch, (u32)d);
            PWM_Commit(PWM_UPDATE_CH(ch));
            AlSys_MDelay((AL_U64)step_ms);
        }
        for (d = (int)arr; d >= 0; d -= (int)step) {
            PWM_SetDuty(ch, (u32)d);
            PWM_Commit(PWM_UPDATE_CH(ch));
            AlSys_MDelay((AL_U64)step_ms);
        }
    }
}
