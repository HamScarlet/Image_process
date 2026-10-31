/*
 * motor.h - 左右轮电机（AXI PWM CH1 / CH2 -> J12 V6 / U5）
 *
 * 通道分配：
 *   CH0 -> 板载 LED3 (J15) 呼吸灯
 *   CH1 -> 左轮 PWM (J12 V6)
 *   CH2 -> 右轮 PWM (J12 U5)
 */

#ifndef MOTOR_H_
#define MOTOR_H_

#include "ui_type.h"

/* 配置 CH1/CH2 定时参数并把占空比清零（不使能通道） */
void motor_Init(void);

/* 使能/关闭电机驱动（CTRL[3] -> O_motor_enable = J12 U10） */
void motor_Enable(u32 en);

/* 速度以百分比给出：-100..100，负值表示反转 */
void motor_SetSpeed(int left, int right);

/* 双轮停转并关闭驱动使能 */
void motor_Stop(void);

#endif /* MOTOR_H_ */
