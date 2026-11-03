/*
 * TIM_BT.c - PL 软 UART 上的蓝牙模块驱动
 *
 * 全部操作都是对 axi_lite_pwm 的 0x60 / 0x64 / 0x68 三个寄存器读写，
 * 没有任何中断、没有 FIFO 管理 —— PL 侧已经把 UART 时序做完了。
 *
 * 时序参考（便于算余量）：
 *   115200 8N1 = 每字节 10 bit = 86.8 µs
 *   printf 一行 80 字符 = 6.9 ms
 *   Bt_SendStr("OK\r\n") = 4 × 87 µs = 0.35 ms
 */

#include <stdio.h>

#include "al_core.h"
#include "al_systimer.h"
#include "ui_io.h"
#include "ui_type.h"
#include "TIM_PWM.h"
#include "TIM_BT.h"

#define BT_WR(off, val)  UI_Out32((void *)(AXI_PWM_BASE + (u32)(off)), (u32)(val))
#define BT_RD(off)       UI_In32((void *)(AXI_PWM_BASE + (u32)(off)))

/* 等一字节发完的时长由 AlSys_MDelay(1) 直接给，见 Bt_SendByte()。
 * 这里不再保存分频值 —— 之前用它算超时，现在改成无条件等 1 ms 了。 */

void Bt_Init(void)
{
    BT_WR(BT_REG_CFG, BT_CFG_EN | BT_DIV_115200);

    /* 清掉可能残留的 fresh：读一次就清。上电时 BL 可能收到过杂波。 */
    (void)BT_RD(BT_REG_RX);

    printf("[BT] soft UART @115200 (div=%u), TX=T9/PIN5 RX=T5/PIN7\r\n",
           (unsigned)BT_DIV_115200);

    /* 握手串：手机端能收到就说明 PL 的 TX 通路 + 接线都对。
     * 收不到不代表 RX 坏了 —— 两者是独立的通路，要分开验。 */
    Bt_SendStr("FPGA ready\r\n");
}

u32 Bt_PollByte(u8 *b)
{
    u32 v = BT_RD(BT_REG_RX);

    if ((v & BT_RX_FRESH) == 0U) {
        return 0U;
    }
    *b = (u8)(v & 0xFFU);
    return 1U;      /* 读这个动作本身已经把 fresh 清掉了 */
}

void Bt_SendByte(u8 b)
{
    BT_WR(BT_REG_TX, (u32)b);

    /* ★ 无条件等 1 ms，**不去判 busy**。
     *
     *   为什么不能靠"读 BT_CFG[17] 等它清零"：
     *     PS 写完 BT_TX 到 PL 把 tx_active 置 1 之间有一拍（20 ns）的窗口。
     *     如果 PS 在这个窗口里读 BT_CFG，会读到 busy=0 而立刻返回，
     *     接着写下一字节 —— 此时 PL 还没进入发送态，新字节直接覆盖旧的。
     *
     *     单次命中概率很低，但 Bt_SendStr("FPGA ready\r\n") 是连续 12 字节，
     *     只要撞上一次，手机收到的字符串就缺字，而且现象随机、极难复现。
     *
     *   1 ms 对 115200 的 87 µs 是 11 倍余量。而且这个等待本来就在
     *   "等手机发下一字节"的空档里，不额外拖慢回环。 */
    AlSys_MDelay(1U);
}

void Bt_SendStr(const char *s)
{
    if (s == 0) {
        return;
    }
    while (*s != '\0') {
        Bt_SendByte((u8)(*s));
        s++;
    }
}

void Bt_SetBaud(u32 div)
{
    if (div < 2U) {
        div = 2U;
    }
    if (div > 0xFFFFU) {
        div = 0xFFFFU;
    }
    BT_WR(BT_REG_CFG, BT_CFG_EN | div);
    /* 不用 %.1f：嵌入式 printf 的浮点支持要额外链接，不值得为一个日志开 */
    printf("[BT] baud div = %u (%u kbps)\r\n",
           (unsigned)div, (unsigned)(50000U / div));
}

u32 Bt_ReadCfg(void)
{
    return BT_RD(BT_REG_CFG);
}

/* ⚠️ 读 0x60 会清 fresh —— 调用方必须保证此刻没有待读字节，
 *    绝不能放进主循环/心跳（详见 TIM_BT.h 里的告警）。 */
u32 Bt_ReadRxCount(void)
{
    /* ★ 移位是 9，不是 16。
     *   RTL 的读多路是 32 位拼接：
     *     {8'd0, bt_rx_count[7:0], bt_rx_fresh, bt_rx_data}   （共 25 位）
     *   ⇒ data=[7:0]、fresh=[8]、count=[16:9]。
     *   早先这里写 >>16，只能读到 count 的最高位（0/1），看起来永远"不涨"，
     *   会把人骗去查接线。别再改回去。 */
    return (BT_RD(BT_REG_RX) >> 9) & 0xFFU;
}
