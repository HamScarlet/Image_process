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
    Fclk_Init();
    printf("Fclk Init successfully");
    AXI_GPIO_Init();
    while(1)
    {
    	AXI_GPIO_Test();
    }


    return 0;
}
