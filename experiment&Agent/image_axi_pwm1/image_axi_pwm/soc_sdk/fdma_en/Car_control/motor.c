/*
 * motor.c - 左右轮电机驱动
 *
 * 原实现的问题：motor_Init 是空壳、SetSpeed 有定义无声明、car_init 里调的是
 * motor_init（小写 i），与这里的 motor_Init 大小写不一致 -> 链接期找不到符号。
 * 本版统一命名，并用 TIM_PWM 的 API 真正下发。
 *
 * 注意：电机/编码器规格（G9）尚未确定，本期只做到"能给占空比、能改方向"，
 * 编码器闭环、电流限幅、死区补偿都留到阶段 6。
 */

#include "motor.h"
#include "TIM_PWM.h"
#include "al_systimer.h"

#define MOTOR_ARR       PWM_DEFAULT_ARR     /* 9999 -> 49.995MHz/10000 = 4.9995 kHz */
#define MOTOR_PSC       PWM_DEFAULT_PSC

static int clamp_pct(int v)
{
    if (v > 100)  return 100;
    if (v < -100) return -100;
    return v;
}

/* 0..100 -> CCR（0..ARR+1） */
static u32 duty_of(int pct)
{
    if (pct <= 0) return 0U;
    return (u32)(((u32)pct * (MOTOR_ARR + 1U)) / 100U);
}

void motor_Init(void)
{
    /* 先关掉 CH1/CH2 的使能，避免配置过程中出毛刺。
     * ⚠️ 这里绝不能用 PWM_DisableAll() —— 它会连 CH0 呼吸灯的使能位一起清零。
     * car_Init 的顺序是 PWM_Init() 在前，CH0 已被使能；一旦被抹掉，
     * 呼吸灯就永远不会输出，而 VERSION / selftest 却全都正常，极易误判方向。 */
    PWM_DisableCh(PWM_CTRL_CH_EN(PWM_CH1) | PWM_CTRL_CH_EN(PWM_CH2));

    PWM_SetTiming(PWM_CH1, MOTOR_PSC, MOTOR_ARR, 0U);
    PWM_SetTiming(PWM_CH2, MOTOR_PSC, MOTOR_ARR, 0U);
    PWM_Commit(PWM_UPDATE_CH(PWM_CH1) | PWM_UPDATE_CH(PWM_CH2));

    /* 等一个 PWM 周期让影子值切入（10000 拍 @49.995MHz ≈ 0.2 ms） */
    AlSys_MDelay(1U);

    PWM_SetMotor(0U, 0U);    /* 方向=正转，驱动不使能 */
}

void motor_Enable(u32 en)
{
    PWM_SetMotor(PWM_ReadReg(PWM_REG_DIR) & 0x3U, en ? 1U : 0U);
}

void motor_SetSpeed(int left, int right)
{
    u32 dir  = 0U;
    u32 ccr_l;
    u32 ccr_r;
    u32 ctrl;

    left  = clamp_pct(left);
    right = clamp_pct(right);

    if (left  < 0) { dir |= 0x1U; left  = -left;  }
    if (right < 0) { dir |= 0x2U; right = -right; }

    ccr_l = duty_of(left);
    ccr_r = duty_of(right);

    PWM_SetDuty(PWM_CH1, ccr_l);
    PWM_SetDuty(PWM_CH2, ccr_r);
    PWM_Commit(PWM_UPDATE_CH(PWM_CH1) | PWM_UPDATE_CH(PWM_CH2));

    /* 方向 + 驱动使能；两轮都为零占空比时自动撤销使能 */
    PWM_SetMotor(dir, (ccr_l | ccr_r) ? 1U : 0U);

    /* 使能两个 PWM 通道（CH0 呼吸灯不受影响） */
    ctrl = PWM_CTRL_CH_EN(PWM_CH1) | PWM_CTRL_CH_EN(PWM_CH2);
    PWM_Enable(ctrl);
}

void motor_Stop(void)
{
    PWM_SetDuty(PWM_CH1, 0U);
    PWM_SetDuty(PWM_CH2, 0U);
    PWM_Commit(PWM_UPDATE_CH(PWM_CH1) | PWM_UPDATE_CH(PWM_CH2));
    PWM_SetMotor(0U, 0U);
}
