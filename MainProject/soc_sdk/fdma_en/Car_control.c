/*
 * Car_control.c
 *
 *  Created on: 2026年10月13日
 *      Author: zhuji
 */

#include <stdio.h>
#include <time.h>
#include "al_core.h"
#include <stdlib.h>
#include "ui_io.h"
#include "ui_type.h"
#include "al_cache.h"
#include "al_systimer.h"
#include "al_gpio_hal.h"
#include "Definitions.h"
#include <stdint.h>

#include "TIM_PWM.h"
#include "motor.h"
#include "USART.h"
#include "Servo.h"

void car_init(void)
{
	motor_init();
	Servo_init();
	USART_init();
}

void car_loop(void)
{

}
