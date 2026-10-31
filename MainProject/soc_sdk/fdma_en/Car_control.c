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
#include "Car_control.h"



COMMAND cmd = {0};

void car_init(void)
{
	motor_init();
	Servo_init();
	USART_init();
}

void car_loop(void)
{
	Cmd_Receive(&cmd);
	Process_Cmd(cmd);
}

void Process_Cmd(COMMAND cmd)
{
	static COMMAND cmd_status = {0};
	if(!memcmp(cmd,cmd_status))
	{
		cmd_status.direct = cmd.direct;
		cmd_status.speed = cmd.speed;

		int8_t speed = cmd_status.speed;
		switch (cmd_status.direct)
		{
			case 0:
				SetSpeed(speed,speed);
				/* code */
				break;
			
			case 1:
				SetSpeed(-speed,-speed);
				/* code */
				break;

			case 2:
				SetSpeed(-speed,speed);
				/* code */
				break;

			case 3:
				SetSpeed(speed,-speed);
				/* code */
				break;

			case 4:
				SetSpeed(0,0);
				/* code */
				break;
			
			default:
				break;
		}
	}
}
