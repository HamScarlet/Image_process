/*
 * Servo.c
 *
 *  Created on: 2026年10月13日
 *      Author: zhuji
 */
#include <stdint.h>
#include "Servo.h"
#include "TIM_PWM.h"

void Servo_init(void)
{

}

// 脉宽对应值（ARR=1999, PSC=719 时，对应 20ms 周期）
// 0° 对应 0.5ms -> CCR = 50
// 180° 对应 2.5ms -> CCR = 250
#define SERVO_MIN_PULSE 50
#define SERVO_MAX_PULSE 250

void Servo_SetAngle(uint8_t angle)
{
    if (angle > 180) {
        angle = 180;
    }
    // 线性映射角度到 CCR 值
    uint16_t pulse = SERVO_MIN_PULSE +
                     (uint32_t)(angle) * (SERVO_MAX_PULSE - SERVO_MIN_PULSE) / 180;
    // 设置比较寄存器
    TIM_SetCompare(PWM2, pulse);
    // 给舵机一些时间动作
    AlSys_MDelay(250U);
}
