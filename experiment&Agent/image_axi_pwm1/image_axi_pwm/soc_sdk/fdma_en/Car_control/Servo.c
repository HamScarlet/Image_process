/*
 * Servo.c - 舵机接口（本期保留接口，不占用 PWM 通道）
 *
 * 原实现的问题：
 *   1. 调用了 TIM_SetCompare(PWM2, pulse) —— 本工程既没有 TIM_SetCompare 函数，
 *      也没有 PWM2 这个符号，编译必然失败
 *   2. CCR 换算按 ARR=1999 / PSC=719 写死（50 / 250），与本工程 ARR=9999 不符
 *   3. 用了 AlSys_MDelay 却没有 include al_systimer.h
 *
 * 通道冲突（关键）：
 *   axi_lite_pwm 只有 3 个通道，本期分配为
 *     CH0 -> 板载 LED3 (J15) 呼吸灯
 *     CH1 -> 左轮电机 PWM (J12 V6)
 *     CH2 -> 右轮电机 PWM (J12 U5)
 *   舵机需要第 4 路 50 Hz PWM。待 G9（电机/编码器/舵机规格）确定后二选一：
 *     a) 把 axi_lite_pwm 扩到 4 通道（改 .v -> mpack -> build_bus_if.py -> DI 重新连线）
 *     b) 舵机交给 STM32 协处理器输出（架构 v2.0 中 STM32 本就承担执行冗余）
 *   因此本文件当前不初始化任何通道，避免与右轮争用 CH2 造成"一给角度车就跑"。
 */

#include "Servo.h"
#include "TIM_PWM.h"

void Servo_Init(void)
{
    /* 有意留空：通道分配未定，见文件头说明 */
}

void Servo_SetAngle(uint8_t angle)
{
    /* 通道分配未定，先不做任何动作 */
    (void)angle;
}
