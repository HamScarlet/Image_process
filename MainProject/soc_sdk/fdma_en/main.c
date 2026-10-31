/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */


#include <stdio.h>
#include <math.h>
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
#include "AXI_GPIO_test.h"
#include "TIM_PWM.h"
#include "motor.h"
#include "USART.h"
#include "Servo.h"
#include "Car_control.h"

void Fclk_Init()
{
	//复位PL的时钟FCLK（将p2f_rst_n全部置低）
	uint32_t val = UI_In32((void *)(uintptr_t)0xF8806330U);
    UI_Out32((void *)(uintptr_t)0xF8806330U, val & (~0xF0));

    //使能GP和FAHB端口
	val = UI_In32((void *)(uintptr_t)0xF8800080U);
    val &= ~0x2;
	UI_Out32((void *)(uintptr_t)0xF8800080U, val);

	//复位了GP0M/GP1M/HP0/HP1
	val = UI_In32((void *)(uintptr_t)0xF8801078U);
	UI_Out32((void *)(uintptr_t)0xF8801078U, val & (~0x33));
    AlSys_MDelay(1);
    UI_Out32((void *)(uintptr_t)0xF8801078U, val | 0x33);

    //释放PL端FCLK的复位（将p2f_rst_n全部置高）
    val = UI_In32(0XF8806330);
    UI_Out32((void *)(uintptr_t)0xF8806330U, val | 0xF0);
}


AL_S32 main()
{
	al_printf("system start\r\n");
    Fclk_Init();
    AlSys_MDelay(250U);
    al_printf("Fclk Init successfully\r\n");

//    AXI_GPIO_Init();
//    al_printf("AXI GPIO Init successfully\r\n");
//    TIM_PWM_Init();
//    al_printf("TIM Init successfully\r\n");


//    AL_REG32_WRITE(0X80200000,0X01);
//    uint32_t r = AL_REG32_READ(0X80200000);
//    al_printf("addr: %d\r\n", r);


    while(1)
    {
//    	AXI_GPIO_Test();
//    	al_printf("AXI GPIO Testing\r\n");
//        TIM_PWM_test();
//        al_printf("TIM Testing\r\n");

        UART_Test();   
    }


    return 0;
}
