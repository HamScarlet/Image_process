/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#include <stdio.h>
#include <math.h>
#include <time.h>
#include "al_core.h"
#include "al_systimer.h"
#include "al_gpio_hal.h"

#define PIN_KEY   54u    /* GPIO_PL bit0 → key (K14) */
#define PIN_LED   55u    /* GPIO_PL bit1 → led (M20) */

static AL_GPIO_HalStruct *g_gpio = AL_NULL;

int main(void)
{
    AlGpio_Hal_Init(&g_gpio, 0u, AL_NULL);   /* DevId = 0，与 MIO 方案相同 */

    AlGpio_Hal_WritePin(g_gpio, PIN_LED, 0u);
    printf("PL gpio: key(Pin54) -> led(Pin55)\r\n");

    while (1) {
        AL_U32 pressed = !AlGpio_Hal_ReadPinInput(g_gpio, PIN_KEY);
        AlGpio_Hal_WritePin(g_gpio, PIN_LED, pressed);
        AlSys_MDelay(10);
    }
}
