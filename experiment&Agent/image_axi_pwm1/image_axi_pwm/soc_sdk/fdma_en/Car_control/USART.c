/*
 * USART.c - 串口收发（本期：UART0 + JDY-31 纯字节回环）
 *
 * 【2026-11-01 本期改动（相对 10-31 版）】
 *   1. AL_UART_DEVID  1 -> 0   —— UART0，走 PS 硬核 EMIO 到 J12 的 U8/U9。
 *      原来用 UART1，而 UART1 是 printf 的日志口；两者其实是同一个静态实例
 *      （AlUart_Hal_Init 内部 *Handle = &AlUartHandle[DevId]），会互相打架。
 *   2. 波特率 115200 -> 9600 —— 与 JDY-31 出厂默认一致（D1：先 9600，通了再改 115200）。
 *   3. 开启接收 + 纯字节回环（USART_LOOPBACK_ENABLE），帧解析保留但本期不启用。
 *   4. **补上 USART_Poll() 的调用**：上一版这个函数全工程没人调，
 *      接收段续订不上，表现就是"只收到最开始那一字节"。现在由 car_Loop() 每轮调用。
 *
 * 【原实现的问题（10-31 修掉的，记录保留）】
 *   1. Cmd_Receive 里 index 未初始化就参与 while(index < BUF_SIZE) —— 未定义行为
 *   2. 同一次循环里 index++ 两次（if 条件里一次、else 分支里又一次），会跳字节
 *   3. Rx_data[index] 在 index 已自增后取值，末尾会越界读
 *   4. 要求连续 4 个 0x55 才算帧头、连续 4 个 0x56 才算帧尾，与注释里的单字节语义不符
 *   5. memcpy(Tx_data, Rx_data, BUF_SIZE) 无视实际收到多少字节，回环永远是 32 字节
 *
 * 【SDK 接收模型的硬约束（详见 USART.h 文件头）】
 *   ❌ 不能在主循环里反复轮询 AlUart_Hal_RecvData（撞 AL_ASSERT，且 HandledCnt 是陈旧值）
 *   ❌ 不能用 AlUart_Hal_RecvDataPolling（阻塞读满，卡死呼吸灯节拍）
 *   ✅ 中断回调 + 分段接收：回调只搬数据置标志，续订放回主循环
 *   ⚠️ RECEIVE_DONE 只在"搬满一段"时触发 ⇒ 回环必须 SEG_SIZE = 1
 */

#include <string.h>
#include "al_uart_hal.h"
#include "al_core.h"
#include "USART.h"

/* UART0 = 蓝牙回环口（PS 硬核 EMIO → J12 U9/U8）
 * ⚠️ 别再改回 1：UART1 是 printf 的日志口（MIO48/49 → 二合一 Type-C 的 PS_UART） */
#define AL_UART_DEVID       0

/* 9600 8N1：与 JDY-31 出厂默认对齐 */
#define AL_UART_BAUDRATE    9600

static AL_UART_InitStruct UART_InitStruct = {
    .BaudRate = AL_UART_BAUDRATE,
    .Parity = AL_UART_NO_PARITY,
    .WordLength = AL_UART_CHAR_8BITS,
    .StopBits = AL_UART_STOP_1BIT,
    .HwFlowCtl = AL_FALSE,
    .CharTimeoutEnable = AL_TRUE
};

static AL_UART_HalStruct *UartHandle = AL_NULL;

/* ---- 分段接收缓冲：SDK 直接往这块内存里搬，生命周期必须稳定 ---- */
static u8  s_rxseg[USART_RX_SEG_SIZE];

/* ---- 环形接收缓冲（承接分段缓冲过来的字节） ---- */
static u8  s_ring[USART_RX_RING_SIZE];
static u32 s_head = 0U;
static u32 s_tail = 0U;

/* 回调置位：有一段数据待主循环处理 */
static volatile int s_seg_ready = 0;

/* ---- 解析结果（回环模式下不产生，仅保留接口） ---- */
static COMMAND s_cmd;
static volatile int s_cmd_ready = 0;

static void rx_push(u8 b)
{
    u32 nxt = (s_head + 1U) % USART_RX_RING_SIZE;

    if (nxt == s_tail) {
        return;             /* 满则丢弃最新字节，保留旧数据 */
    }
    s_ring[s_head] = b;
    s_head = nxt;
}

static int rx_pop(u8 *b)
{
    if (s_head == s_tail) {
        return 0;
    }
    *b = s_ring[s_tail];
    s_tail = (s_tail + 1U) % USART_RX_RING_SIZE;
    return 1;
}

#if (USART_LOOPBACK_ENABLE == 0)
/* 帧状态机：等待头 -> 收 3 字节载荷 -> 等尾
 * 回环模式下不启用，避免与 USART_Test() 抢同一份环形缓冲数据。 */
static void frame_parse(void)
{
    static u8  state = 0U;
    static u8  idx = 0U;
    static u8  payload[CMD_PAYLOAD_LEN];
    u8 b;

    while (rx_pop(&b) != 0) {
        switch (state) {
            case 0:                             /* 等帧头 */
                if (b == FRAME_HEAD) {
                    state = 1U;
                    idx = 0U;
                }
                break;

            case 1:                             /* 收载荷 */
                payload[idx++] = b;
                if (idx >= CMD_PAYLOAD_LEN) {
                    state = 2U;
                }
                break;

            case 2:                             /* 等帧尾 */
                if (b == FRAME_TAIL) {
                    if (payload[2] <= 100U) {
                        s_cmd.direct     = payload[0];
                        s_cmd.diversion  = payload[1];
                        s_cmd.speed      = payload[2];
                        s_cmd.reserved   = 0U;
                        s_cmd_ready      = 1;
                    }
                    state = 0U;
                } else if (b == FRAME_HEAD) {
                    state = 1U;                 /* 尾丢了，把它当新头 */
                    idx = 0U;
                } else {
                    state = 0U;                 /* 帧错，丢弃重来 */
                }
                break;

            default:
                state = 0U;
                break;
        }
    }
}
#endif /* USART_LOOPBACK_ENABLE == 0 */

#if (USART_RX_ENABLE != 0)
/* ---------------------------------------------------------------------------
 * UART 事件回调（中断上下文）
 *
 *   只做两件事：把 SDK 收到的那一段搬进环形缓冲、置标志。
 *   **不调用任何 SDK API** —— 续订下一段要回到主循环上下文做。
 *
 *   ⚠️ RECEIVE_DONE 只在"搬满一段"时才触发。所以 USART_RX_SEG_SIZE=1 时每收
 *      一个字节就进一次这里，这正是回环想要的节拍。
 * ------------------------------------------------------------------------- */
static void uart_evt_cb(AL_UART_EventStruct ev, AL_VOID *ref)
{
    u32 n;
    u32 i;

    (void)ref;

    if ((ev.Events & AL_UART_EVENT_RECEIVE_DONE) == 0U) {
        return;
    }
    if (UartHandle == AL_NULL) {
        return;
    }

    n = UartHandle->Dev.RecvBuffer.HandledCnt;
    if ((n == 0U) || (n > USART_RX_SEG_SIZE)) {
        return;
    }

    for (i = 0U; i < n; i++) {
        rx_push(s_rxseg[i]);
    }

    s_seg_ready = 1;
}
#endif /* USART_RX_ENABLE */

void USART_Init(void)
{
    AL_S32 ret;

    ret = AlUart_Hal_Init(&UartHandle, AL_UART_DEVID, &UART_InitStruct,
#if (USART_RX_ENABLE != 0)
                           uart_evt_cb
#else
                           AL_NULL
#endif
                          );
    if (ret == AL_OK) {
        AlIntr_SetLocalInterrupt(AL_FUNC_ENABLE);

#if (USART_RX_ENABLE != 0)
        /* 启动第一段接收。缓冲区地址交给 SDK 后必须保持稳定，
         * 所以 s_rxseg 必须是静态数组，不能是栈上临时变量。 */
        (void)AlUart_Hal_RecvData(UartHandle, s_rxseg, USART_RX_SEG_SIZE);
#endif
        al_printf("[UART] init ok (UART0, %d 8N1)\r\n", (int)AL_UART_BAUDRATE);
    } else {
        UartHandle = AL_NULL;
        al_printf("[UART] init failed, ret=%d\r\n", (int)ret);
    }
}

void USART_Poll(void)
{
#if (USART_RX_ENABLE != 0)
    if ((s_seg_ready == 0) || (UartHandle == AL_NULL)) {
        return;                 /* 没有新一段，别去碰 SDK */
    }
    s_seg_ready = 0;

    /* 先续订下一段。SEG_SIZE=1 且 FIFO 里已有字节时，SDK 会同步搬进来并回调，
     * 也就是本轮就能把刚到的字节回显出去。 */
    if (AlUart_Hal_RecvData(UartHandle, s_rxseg, USART_RX_SEG_SIZE) != AL_OK) {
        s_seg_ready = 1;        /* 续订失败（上一段还没收尾）：保持待命，下一轮重试 */
    }

#if (USART_LOOPBACK_ENABLE != 0)
    USART_Test();               /* 纯字节回环：把环形缓冲里的字节原样发回 */
#else
    frame_parse();
#endif
#endif /* USART_RX_ENABLE */
}

int USART_GetCmd(COMMAND *out)
{
    if ((s_cmd_ready == 0) || (out == AL_NULL)) {
        return 0;
    }
    *out = s_cmd;
    s_cmd_ready = 0;
    return 1;
}

void USART_Send(const u8 *buf, u32 len)
{
    if ((UartHandle == AL_NULL) || (buf == AL_NULL) || (len == 0U)) {
        return;
    }
    (void)AlUart_Hal_SendData(UartHandle, (u8 *)buf, len);
}

void USART_Test(void)
{
#if (USART_RX_ENABLE != 0)
    /* 回环自测：把环形缓冲里的字节原样发回去。
     * 注意这里读的是**环形缓冲**（回调已经搬进来的），
     * 不再从 UART 硬件 FIFO 里直接取 —— 那正是上一版的错误所在。 */
    u8 b;

    while (rx_pop(&b) != 0) {
        USART_Send(&b, 1U);
    }
#endif
}
