/*
 * AXI_GPIO_test.c - AXI GPIO 读写自检（通道 0 -> O_code_driver[3:0]）
 *
 * 原实现的问题：
 *   1. default 分支把 NULL 赋给 uint32_t，再用 if(reg) 判断 -> 类型与语义都不对
 *   2. 基址宏缺括号，在表达式里展开会算错
 *   3. TRI 寄存器宏里混用 uintptr_t 转换，与 UI_Out32 的 void* 形参重复转换
 * 本版改为：用 0 表示无效通道，地址全部来自 Definitions.h 的带括号宏。
 */

#include "AXI_GPIO_test.h"
#include "al_core.h"
#include "ui_io.h"
#include "ui_type.h"
#include "al_systimer.h"

/* ch: 0 -> AXI_GPIO_0, 1 -> AXI_GPIO_1 */
static int AXI_GPIO_WriteData(u32 ch, u32 value)
{
    u32 reg;

    switch (ch) {
        case 0:  reg = AXI_GPIO0_DAT_REG; break;
        case 1:  reg = AXI_GPIO1_DAT_REG; break;
        default: return 0;                /* 无效通道 */
    }

    UI_Out32((void *)(uintptr_t)reg, value);
    return 1;
}

void AXI_GPIO_Init(void)
{
    /* 先输出 0，再把 4 位全部设为输出 */
    (void)AXI_GPIO_WriteData(0U, 0x00U);
    UI_Out32((void *)(uintptr_t)AXI_GPIO0_TRI_REG, 0x00U);
    al_printf("[GPIO] AXI GPIO0 init done\r\n");
}

void AXI_GPIO_Test(void)
{
    u32 pin;

    for (pin = 0U; pin < 4U; ++pin) {
        (void)AXI_GPIO_WriteData(0U, 1U << pin);
        AlSys_MDelay(250U);
        (void)AXI_GPIO_WriteData(0U, 0x00U);
        AlSys_MDelay(250U);
    }
}
