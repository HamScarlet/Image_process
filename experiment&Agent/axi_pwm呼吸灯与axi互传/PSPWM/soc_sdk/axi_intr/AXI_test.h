/*
 * AXI_test.h - PS 侧驱动：AXI4-Lite 通路验证从端（PL 侧 AXI_test）
 *
 * 基址 0x80300000 / 4 KB，由 DI Address Editor 分配（接 Master_AXI_GP0）。
 * 寄存器语义见 soc_prj/uisrc/03_ip/AXI_test/AXI_test.v 头部注释。
 *
 * 这个模块不做任何外设功能，只用来回答一个问题：
 *   PS 写进 PL 的数、以及 PL 自己产生的数，PS 能不能读回来？
 *
 * 四组寄存器分别验一条通路，读错哪一组就知道断在哪一环：
 *   ① ID / VER / PAT0..3   只读常量  -> 地址映射、读握手
 *   ② SCR0 / SCR1          读写      -> 写通路、字节选通、"两个地址落到同一寄存器"
 *   ③ LIVE_LO / LIVE_HI    自由计数器 -> PL 真的有时钟、数据是 PL 给的
 *   ④ CMD / STATUS / COUNT 握手      -> PS 触发 -> PL 执行 -> PS 轮询
 *
 * 用法（放在 TIM_PWM 的测试之前，先验地基再验业务）：
 *   if (AXI_Test_Bringup() == 0U) { ... AXI 通路可用 ... }
 */

#ifndef AXI_TEST_H
#define AXI_TEST_H

#include "ui_type.h"

/* ---------------- 基址 ---------------- */
#define AXI_TEST_BASE           0x80300000U

/* ---------------- 寄存器偏移 ---------------- */
#define AT_REG_ID               0x00U   /* 只读，固定 0x41584954（"AXIT"）*/
#define AT_REG_VER              0x04U   /* 只读，固定 0x00010000 */
#define AT_REG_SCR0             0x08U   /* 读写，写读回第 1 组 */
#define AT_REG_SCR1             0x0CU   /* 读写，写读回第 2 组 */
#define AT_REG_LIVE_LO          0x10U   /* 只读，64 位自由计数器低 32 位 */
#define AT_REG_LIVE_HI          0x14U   /* 只读，高 32 位 */
#define AT_REG_PAT0             0x18U   /* 只读，0xA5A50000 */
#define AT_REG_PAT1             0x1CU   /* 只读，0xA5A50001 */
#define AT_REG_PAT2             0x20U   /* 只读，0x5A5A0002 */
#define AT_REG_PAT3             0x24U   /* 只读，0x5A5A0003 */
#define AT_REG_CMD              0x28U   /* 只写：[0] START，[1] CLR（CLR 优先）*/
#define AT_REG_STATUS           0x2CU   /* 只读：[0] BUSY，[1] DONE */
#define AT_REG_COUNT            0x30U   /* 只读，受控计数值 */

/* ---------------- 期望值 ---------------- */
#define AT_ID_EXPECT            0x41584954U     /* 'A' 'X' 'I' 'T' */
#define AT_VER_EXPECT           0x00010000U

#define AT_PAT0_EXPECT          0xA5A50000U
#define AT_PAT1_EXPECT          0xA5A50001U
#define AT_PAT2_EXPECT          0x5A5A0002U
#define AT_PAT3_EXPECT          0x5A5A0003U

/* 写读回用的两个不同图样：两组写不同的值，才能发现"两个地址落到同一个寄存器" */
#define AT_SCR0_PATTERN         0xDEADBEEFU
#define AT_SCR1_PATTERN         0x12345678U

/* ---------------- CMD / STATUS 位定义 ---------------- */
#define AT_CMD_START            (1U << 0)
#define AT_CMD_CLR              (1U << 1)

#define AT_STATUS_BUSY          (1U << 0)
#define AT_STATUS_DONE          (1U << 1)

/* ---------------- ④ 组的计数值 ----------------
 * 必须与 RTL 里的 parameter RUN_TARGET 保持一致（默认 0x00100000）。
 * @200 MHz 约 5.24 ms：够长，轮询一定能看到 BUSY=1 -> DONE=1；
 * 够短，不会让一次手测卡住。 */
#define AT_RUN_TARGET           0x00100000U

/* 轮询 DONE 的最大次数。按每读一次约几百 ns 估算，2e6 次约 0.4~0.6 s 后放弃，
 * 防止 AXI 完全不通时死等。 */
#define AT_POLL_LIMIT           2000000U

/* ---------------- API ---------------- */

/* 读 ID，用来最快判断 AXI 通路通不通（读到 0x41584954 就基本通了） */
u32 AXI_Test_ReadId(void);

/* 读任意寄存器偏移，调试用（偏移见上面的宏） */
u32 AXI_Test_ReadReg(u32 offset);

/* 完整验收：按 ①②③④ 顺序跑一遍，返回失败项数（0 = 全部通过）。
 * 任一失败项会在串口打出来，具体定位见上面四组寄存器说明。 */
u32 AXI_Test_Bringup(void);

#endif /* AXI_TEST_H */
