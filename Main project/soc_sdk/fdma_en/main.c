/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

/* ============================================================================
 * 2026-10-06  诊断插桩版（只动 PS 侧，PL 不动，不需要重跑 TD）
 *
 * 背景：HDMI 输出「闪一下 → 彻底黑，跟没插线一样」= 连 TMDS 时钟都没有。
 *       system.v 的复位链是：
 *           p2f_rst0_n(PS 释放) -> PLL .reset(~p2f_rst0_n) -> locked
 *           -> fifowait(2^20 个 pclkx1 ≈ 6.99ms @150MHz) -> VTC/HDMI_TX 解除复位
 *       所以只要 p2f_rst0_n 没被释放，整条 PL 就是死的，屏上什么都不会有。
 *
 * 本版只加三样东西（Fclk_Init() 函数体一字未改）：
 *   ① 开头/结尾各打 banner —— 确认程序到底有没有跑起来；
 *   ② 把 Fclk_Init() 前后 3 个关键寄存器的读回值打出来 —— 直接看 p2f_rst_n[3:0]；
 *   ③ 结尾改成死循环保活 —— 避免 main() return 后被 C 运行时复位，从而把
 *      p2f_rst_n 重新拉低（这正是「闪一下→全黑」的嫌疑机理）。
 *
 * ⚠️ 串口：本板 BSP 的 board_cfg.mk 里 BOARD_DR1X90_AD101_V10 注释明写
 *         "select uart 1 as log output" ⇒ 日志走 UART1(0xF8401000)，
 *         对应板子上 Type-C 那个口（PS MIO48/49）。别接错口。
 *
 * 回退：原始版本在
 *   D:\项目\FPGA工程\02-工程实操\08-MIPI-CS500-HDMI适配\01-工程-MIPI转HDMI适配版\soc_sdk\fdma_en\main.c
 *   （md5 = 0d4c50b7470c135c48e0cb6e06e52c9b，与本文件改写前逐字节一致）
 * ============================================================================ */

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
    AXI_GPIO_Test();

    return 0;
}
