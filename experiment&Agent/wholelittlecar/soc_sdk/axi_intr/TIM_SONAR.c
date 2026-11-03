/*
 * TIM_SONAR.c - HC-SR04 超声 + 15 cm 门控的 PS 侧驱动
 *
 * 本文件只是**观察窗口**，不参与安全逻辑。真正截断 PWM 的是 PL 侧的
 * axi_lite_guard，PS 卡死、printf 阻塞、甚至主循环停了，门控照样生效。
 *
 * 这一点很重要：如果把"小于 15 cm 就停"写在 PS 里，等于把安全交给一个
 * 会 printf 会 delay 会死循环的软件。所以设计上刻意让 PS 只读不写。
 */

#include <stdio.h>

#include "al_core.h"
#include "ui_io.h"
#include "ui_type.h"
#include "TIM_PWM.h"
#include "TIM_SONAR.h"

#define SONAR_WR(off, val)  UI_Out32((void *)(AXI_PWM_BASE + (u32)(off)), (u32)(val))
#define SONAR_RD(off)       UI_In32((void *)(AXI_PWM_BASE + (u32)(off)))

/* 阈值字段上限：16 位能表示的最大拍数换算成 cm（65535 / 2900 = 22） */
#define GUARD_CM_MAX        22U

void Sonar_Init(void)
{
    SONAR_WR(SONAR_REG_GUARD_CFG, GUARD_CFG_RESET);
    SONAR_WR(SONAR_REG_CFG, SONAR_CFG_EN | SONAR_CFG_PERIOD(60U));

    /* 软触发一轮，这样上电 60 ms 内就有第一个读数，
     * 不用等自动周期走满（自动周期从 0 开始数，最长要等一个周期）。 */
    SONAR_WR(SONAR_REG_CFG, SONAR_CFG_EN | SONAR_CFG_PERIOD(60U) | SONAR_CFG_TRIG);
}

u32 Sonar_ReadTicks(void)
{
    return SONAR_RD(SONAR_REG_TICKS);
}

u32 Sonar_ReadCm(void)
{
    return SONAR_RD(SONAR_REG_TICKS) / SONAR_TICKS_PER_CM;
}

u32 Sonar_ReadState(void)
{
    return SONAR_RD(SONAR_REG_GUARD_ST);
}

u32 Sonar_ReadGuardCnt(void)
{
    return SONAR_RD(SONAR_REG_GUARD_CNT);
}

void Sonar_SetGuardCm(u32 enter_cm, u32 exit_cm)
{
    u32 enter;
    u32 exit;

    if (enter_cm > GUARD_CM_MAX) {
        printf("    enter %u cm > %u cm limit -> clamped\r\n",
               (unsigned)enter_cm, (unsigned)GUARD_CM_MAX);
        enter_cm = GUARD_CM_MAX;
    }
    if (exit_cm > GUARD_CM_MAX) {
        printf("    exit  %u cm > %u cm limit -> clamped\r\n",
               (unsigned)exit_cm, (unsigned)GUARD_CM_MAX);
        exit_cm = GUARD_CM_MAX;
    }
    /* 退出阈值必须大于进入阈值，否则迟滞不成立、门控会跟着噪声抖 */
    if (exit_cm <= enter_cm) {
        exit_cm = enter_cm + 1U;
    }

    enter = enter_cm * SONAR_TICKS_PER_CM;
    exit  = exit_cm  * SONAR_TICKS_PER_CM;

    SONAR_WR(SONAR_REG_GUARD_CFG, ((exit & 0xFFFFU) << 16) | (enter & 0xFFFFU));
}

void Sonar_SoftTrigger(void)
{
    u32 cfg = SONAR_RD(SONAR_REG_CFG);

    /* bit17 保留原使能状态，只把 bit16 置 1。硬件写进去后不会存这一位，
     * 所以下次读回来 bit16 恒为 0，不用软件清。 */
    SONAR_WR(SONAR_REG_CFG, (cfg & SONAR_CFG_EN) | SONAR_CFG_PERIOD(cfg) | SONAR_CFG_TRIG);
}

void Sonar_ClearGuard(void)
{
    u32 cfg = SONAR_RD(SONAR_REG_CFG);

    /* 只置 bit18，保留 bit17(enable) 与周期字段。
     * 读回 bit18 恒为 0（硬件不存），所以不用软件清。 */
    SONAR_WR(SONAR_REG_CFG, (cfg & SONAR_CFG_EN) | SONAR_CFG_PERIOD(cfg) | SONAR_CFG_CLR);
}

u32 Sonar_SelfTest(void)
{
    /* ★ 判据：GUARD_CFG 的复位值就是新 RTL 的指纹。
     *
     *   读到 0xC094A9EC -> axi_lite_pwm 是 V8 那份（0x58 已被译码，复位值正确）
     *   读到 0x00000000 -> 0x58 还是未映射地址（V8 之前的位流），
     *                      或者整个 AXI 从端没应答
     *   读到 0xFFFFFFFF -> 总线错误（DECERR）
     *
     *   为什么拿它当指纹而不是"写一个值再读回"：
     *     写回读会临时改掉门控阈值，万一测到一个近处物体就误拦一次。
     *     读复位值是零副作用的，而且同样能证明"0x58 这个地址确实译码了"。 */
    if (SONAR_RD(SONAR_REG_GUARD_CFG) != GUARD_CFG_RESET) {
        return 1U;
    }
    return 0U;
}
