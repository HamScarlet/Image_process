/*
 * AXI_test.c - PS 侧驱动：AXI4-Lite 通路验证从端（PL 侧 AXI_test）
 *
 * 硬件行为要点（依 AXI_test.v）：
 *   1. 本模块没有任何对外引脚，所有观测都靠 AXI 读寄存器。
 *   2. LIVE_LO/LIVE_HI 是 PL 侧 64 位自由计数器，只要 p2f_clk0 到了 PL 就在跑。
 *      "PS 从没写过它，连读两次却不一样" 就是 PL 活着、且数据由 PL 产生的最直接证据。
 *   3. CMD 写 START 后 PL 开始计数，跑到 RUN_TARGET 停住并置 DONE，
 *      COUNT 停在 RUN_TARGET 上不再增加；写 CLR 清零（CLR 优先于 START）。
 *   4. 未映射地址访问会返回 SLVERR —— 地址算错时不会静默返回 0。
 *
 * 四组检查的判据见 AXI_test.h 的头注释；任何一组失败都不要往下做，
 * 后面所有 PL 模块都压在这条通路上。
 */

#include <stdio.h>
#include "al_core.h"
#include "ui_io.h"
#include "ui_type.h"
#include "AXI_test.h"

/* MMIO 访问宏。
 * 与 TIM_PWM.c 是同一套写法，只多了一步 (uintptr_t) 过渡：
 * 目标机是 AArch64（64 位指针），直接 (void *) 把 32 位整数转成指针会触发
 * -Wint-to-pointer-cast 警告（值本身没错，是零扩展，但会淹没真正的告警）。
 * 先转 uintptr_t 再转 void * 就没有这个警告，行为完全一致。 */
#define AT_WR(off, val)     UI_Out32((void *)(uintptr_t)(AXI_TEST_BASE + (u32)(off)), (u32)(val))
#define AT_RD(off)          UI_In32((void *)(uintptr_t)(AXI_TEST_BASE + (u32)(off)))

u32 AXI_Test_ReadId(void)
{
    return AT_RD(AT_REG_ID);
}

u32 AXI_Test_ReadReg(u32 offset)
{
    return AT_RD(offset);
}

u32 AXI_Test_Bringup(void)
{
    u32 v;
    u32 v2;
    u32 lo;
    u32 hi;
    u32 target;
    volatile u32 i;
    u32 guard;
    u32 fail = 0U;

    printf("\r\n===== AXI_test bring-up =====\r\n");
    printf("base = 0x%08X  target = %u\r\n",
           (unsigned)AXI_TEST_BASE, (unsigned)AT_RUN_TARGET);

    /* ======================================================================
     * ① 读通路：ID / VER / PAT0..3
     *   这一组只读常量。读对 = 地址映射、AR/R 握手、从端选通都成立。
     *   读错 = 先查 DI 里接口有没有连上、Address Editor 有没有分配地址。
     * ==================================================================== */
    v = AT_RD(AT_REG_ID);
    printf("[1] ID  = 0x%08X (expect 0x%08X) %s\r\n",
           (unsigned)v, (unsigned)AT_ID_EXPECT,
           (v == AT_ID_EXPECT) ? "OK" : "FAIL");
    if (v != AT_ID_EXPECT) {
        fail++;
    }

    v = AT_RD(AT_REG_VER);
    printf("    VER = 0x%08X (expect 0x%08X) %s\r\n",
           (unsigned)v, (unsigned)AT_VER_EXPECT,
           (v == AT_VER_EXPECT) ? "OK" : "FAIL");
    if (v != AT_VER_EXPECT) {
        fail++;
    }

    v  = AT_RD(AT_REG_PAT0);
    v2 = AT_RD(AT_REG_PAT1);
    printf("    PAT = %08X %08X",
           (unsigned)v, (unsigned)v2);
    if ((v != AT_PAT0_EXPECT) || (v2 != AT_PAT1_EXPECT)) {
        fail++;
    }

    v  = AT_RD(AT_REG_PAT2);
    v2 = AT_RD(AT_REG_PAT3);
    printf(" %08X %08X\r\n", (unsigned)v, (unsigned)v2);
    if ((v != AT_PAT2_EXPECT) || (v2 != AT_PAT3_EXPECT)) {
        fail++;
    }

    /* ======================================================================
     * ② 写通路：写进去、读回来
     *   两组故意写不同的值 —— 如果 SCR0 和 SCR1 读回相同，说明两个地址
     *   落到了同一个寄存器（地址译码串了），这是最容易漏的一种错。
     * ==================================================================== */
    AT_WR(AT_REG_SCR0, AT_SCR0_PATTERN);
    AT_WR(AT_REG_SCR1, AT_SCR1_PATTERN);

    v  = AT_RD(AT_REG_SCR0);
    v2 = AT_RD(AT_REG_SCR1);
    printf("[2] SCR0 = 0x%08X (expect 0x%08X) %s\r\n",
           (unsigned)v, (unsigned)AT_SCR0_PATTERN,
           (v == AT_SCR0_PATTERN) ? "OK" : "FAIL");
    printf("    SCR1 = 0x%08X (expect 0x%08X) %s\r\n",
           (unsigned)v2, (unsigned)AT_SCR1_PATTERN,
           (v2 == AT_SCR1_PATTERN) ? "OK" : "FAIL");
    if ((v != AT_SCR0_PATTERN) || (v2 != AT_SCR1_PATTERN)) {
        fail++;
    }

    /* ② 附：字节选通。只写最低字节，另外三个字节必须保持 0。
     * 如果读回 0xAAAAAAAA，说明 PL 侧没有按 wstrb 做字节合并，
     * 而是把整字都覆盖了 —— 以后用 8/16 位访问时会踩到。 */
    AT_WR(AT_REG_SCR0, 0x00000000U);
    *(volatile u8 *)(AXI_TEST_BASE + (u32)AT_REG_SCR0) = (u8)0xAA;
    v = AT_RD(AT_REG_SCR0);
    printf("    byte-strobe: SCR0 = 0x%08X (expect 0x000000AA) %s\r\n",
           (unsigned)v, (v == 0x000000AAU) ? "OK" : "FAIL");
    if (v != 0x000000AAU) {
        fail++;
    }

    /* ======================================================================
     * ③ PL 产数据：LIVE 计数器
     *   PS 从没写过这个寄存器。连读两次必须不同 ——
     *   相同说明 p2f_clk0 没到 PL（时钟没接），或计数器被综合优化掉了。
     * ==================================================================== */
    lo = AT_RD(AT_REG_LIVE_LO);
    for (i = 0U; i < 1000U; i++) {
        /* 空转，拉开两次读之间的间隔；volatile 防止被优化掉 */
    }
    hi = AT_RD(AT_REG_LIVE_LO);
    printf("[3] LIVE_LO: %u -> %u  %s\r\n",
           (unsigned)lo, (unsigned)hi,
           (lo != hi) ? "OK (PL clock is running)" : "FAIL (counter frozen)");
    if (lo == hi) {
        fail++;
    }

    printf("    LIVE_HI = 0x%08X\r\n", (unsigned)AT_RD(AT_REG_LIVE_HI));

    /* ======================================================================
     * ④ 握手：CLR -> 检查清空 -> START -> 轮询 DONE -> 读 COUNT
     *   这一步同时验证：PS 写、PL 反应、PS 轮询、PS 读，四件事都活着。
     * ==================================================================== */
    AT_WR(AT_REG_CMD, AT_CMD_CLR);
    v = AT_RD(AT_REG_STATUS);
    printf("[4] after CLR: STATUS = 0x%08X (expect 0x00000000) %s\r\n",
           (unsigned)v, (v == 0U) ? "OK" : "FAIL");
    if (v != 0U) {
        fail++;
    }

    AT_WR(AT_REG_CMD, AT_CMD_START);
    v = AT_RD(AT_REG_STATUS);
    printf("    just after START: STATUS = 0x%08X\r\n", (unsigned)v);
    if ((v & AT_STATUS_BUSY) == 0U) {
        printf("    -> BUSY not observed"
               " (RUN_TARGET too small, or polling too slow)\r\n");
    }

    guard = 0U;
    do {
        v = AT_RD(AT_REG_STATUS);
    } while (((v & AT_STATUS_DONE) == 0U) && (++guard < AT_POLL_LIMIT));

    if (guard >= AT_POLL_LIMIT) {
        printf("    -> TIMEOUT waiting DONE, STATUS = 0x%08X\r\n", (unsigned)v);
        fail++;
    } else {
        printf("    DONE after %u polls, STATUS = 0x%08X\r\n",
               (unsigned)guard, (unsigned)v);
    }

    target = AT_RD(AT_REG_COUNT);
    printf("    COUNT = %u (expect %u) %s\r\n",
           (unsigned)target, (unsigned)AT_RUN_TARGET,
           (target == AT_RUN_TARGET) ? "OK" : "FAIL");
    if (target != AT_RUN_TARGET) {
        fail++;
    }

    printf("===== AXI_test %s (%u failure) =====\r\n\r\n",
           (fail == 0U) ? "PASSED" : "FAILED", (unsigned)fail);

    return fail;
}
