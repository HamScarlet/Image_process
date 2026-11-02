/*
 * motor.c
 *
 *  Created on: 2026年10月13日
 *      Author: zhuji
 */

#include "motor.h"
#include "TIM_PWM.h"

void motor_Init(void)
{

}

void SetSpeed(int left, int right)
{
    TIM_SetCompare(PWM0,(float)left/100);
    TIM_SetCompare(PWM1,(float)right/100);
}

