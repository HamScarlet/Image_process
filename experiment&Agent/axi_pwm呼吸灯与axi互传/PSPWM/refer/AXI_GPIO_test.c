/*
 * AXI_GPIO_test.c
 *
 *  Created on: 2026年10月13日
 *      Author: zhuji
 */
#include "AXI_GPIO_test.h"
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

static int AXI_GPIO_WriteData(uint8_t ch,uint32_t value)
{
	uint32_t reg;
	switch(ch)
	{
		case 1: reg = AXI_GPIO0_DAT_REG;break;
		case 2: reg = AXI_GPIO1_DAT_REG;break;
		default: reg = NULL;
	}
	if(reg) {
		UI_Out32((void *)(uintptr_t)reg, value);
		return 1;
	}
	else return 0;
}


void AXI_GPIO_Init(void)
{
	/* Load a safe low output value, then set all four channel-1 pins as outputs. */
	AXI_GPIO_WriteData(1,0x00U);
	al_printf("AXI set successfully");
	UI_Out32((void *)(uintptr_t)AXI_GPIO0_TRI_REG, 0x00U);
	al_printf("AXI init successfully");
}

void AXI_GPIO_Test(void)
{
	uint32_t pin;

	for (pin = 0; pin < 4U; ++pin) {
		AXI_GPIO_WriteData(1,1U << pin);
		AlSys_MDelay(250U);

		AXI_GPIO_WriteData(1,0x00U);
		AlSys_MDelay(250U);
	}

}
