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

#define REG_P2F_RST     0XF8806330    /* bit[7:4] = p2f_rst_n[3:0]，必须被置 1 */
#define REG_GP_FAHB     0xF8800080    /* bit1 清零 */
#define REG_HP0HP1      0xF8801078    /* bit[5:0] = 0x33 */

void Fclk_Init()
{
	//复位PL的时钟FCLK（将p2f_rst_n全部置低）
	uint32_t val = UI_In32(0XF8806330);
    UI_Out32(0XF8806330, val & (~0xF0));

    //使能GP和FAHB端口
	val = UI_In32(0xF8800080);
    val &= ~0x2;
    UI_Out32(0xF8800080, val);

	//复位了GP0M/GP1M/HP0/HP1
	val = UI_In32(0xF8801078);
	UI_Out32(0xF8801078, val & (~0x33));
    AlSys_MDelay(1);
    UI_Out32(0xF8801078, val | 0x33);

    //释放PL端FCLK的复位（将p2f_rst_n全部置高）
    val = UI_In32(0XF8806330);
    UI_Out32(0XF8806330, val | 0xF0);
}

/* 把 3 个寄存器一起打出来，前后各调一次 */
static void dump_regs(const char *tag)
{
    uint32_t v6330 = UI_In32(REG_P2F_RST);
    uint32_t v0080 = UI_In32(REG_GP_FAHB);
    uint32_t v1078 = UI_In32(REG_HP0HP1);

    printf("[%s] 0xF8806330=%08X  -> p2f_rst_n[3:0]=%X\r\n",
           tag, (unsigned int)v6330, (unsigned int)((v6330 >> 4) & 0xF));
    printf("[%s] 0xF8800080=%08X   0xF8801078=%08X\r\n",
           tag, (unsigned int)v0080, (unsigned int)v1078);
}

AL_S32 main()
{
    const AL_CHAR *str = "axi fdma test!";
    uint32_t v6330;

    AlSys_MDelay(2000);     /* 留 2s，方便串口终端抓开头几行 */

    printf("\r\n\r\n");
    printf("==============================================\r\n");
    printf(" fdma_en DIAG BUILD  2026-10-06\r\n");
    printf(" PS IS RUNNING.  str=%s\r\n", str);
    printf(" log uart = UART1 (0xF8401000)\r\n");
    printf("==============================================\r\n");

    dump_regs("before");

    Fclk_Init();

    dump_regs("after ");

    v6330 = UI_In32(REG_P2F_RST);
    if (((v6330 >> 4) & 0xF) == 0xF) {
        printf("[RESULT] p2f_rst_n[3:0] = F  已全部释放\r\n");
        printf("         => PLL 已脱离复位。若屏上仍无 TMDS 时钟，\r\n");
        printf("            下一步查 PLL 是否 locked（ChipWatcher / 示波器量 K17）。\r\n");
    } else {
        printf("[RESULT] p2f_rst_n[3:0] != F  未完全释放  <== 全黑根因在这里\r\n");
        printf("         => PL 被锁在复位态，整条链不出 TMDS 时钟。\r\n");
    }

    printf("[keep-alive] 进入保活循环，PS 保持运行（防止 return 引起外设复位）\r\n");

    /* 死循环保活 + 每秒复查一次 p2f_rst_n，观察它会不会掉 */
    while (1) {
        AlSys_MDelay(1000);
        v6330 = UI_In32(REG_P2F_RST);
        printf("[loop] 0xF8806330=%08X  p2f_rst_n[3:0]=%X\r\n",
               (unsigned int)v6330, (unsigned int)((v6330 >> 4) & 0xF));
    }

    return 0;
}
