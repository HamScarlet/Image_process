/*
 * USART.c - 串口收发与命令帧解析
 *
 * 【原实现的问题】
 *   1. Cmd_Receive 里 index 未初始化就参与 while(index < BUF_SIZE) —— 未定义行为
 *   2. 同一次循环里 index++ 两次（if 条件里一次、else 分支里又一次），会跳字节
 *   3. Rx_data[index] 在 index 已自增后取值，末尾会越界读
 *   4. 要求连续 4 个 0x55 才算帧头、连续 4 个 0x56 才算帧尾，与注释里的单字节语义不符
 *   5. memcpy(Tx_data, Rx_data, BUF_SIZE) 无视实际收到多少字节，回环永远是 32 字节
 *
 * 【2026-10-31 重写：按 SDK 的真实接收模型改】
 *   参考官方成功工程 D:\FPGAproject\AnLuRun\PSPWM\soc_sdk\axi_intr，
 *   并逐行核对 FD SDK 源码（soc_base/dr1m90_fpsoc_cpu0/driver/ps_driver/uart/src/）：
 *
 *   AlUart_Dev_RecvData(Uart, ReceiveBuf, ReceiveSize) 的真实行为：
 *     1) 先把 RX FIFO 里现成的字节搬进 ReceiveBuf；
 *     2) 若 ReceivedCount < ReceiveSize：
 *          记下 RecvBuffer.{RequestedCnt, HandledCnt, BufferPtr}，
 *          **使能 RX 线中断**，由中断继续往 ReceiveBuf 搬，
 *          搬满 ReceiveSize 字节才触发 AL_UART_EVENT_RECEIVE_DONE；
 *     3) 若一次就搬满了（ReceivedCount >= ReceiveSize）：
 *          直接触发 RECEIVE_DONE，并且**不更新 RecvBuffer.HandledCnt**。
 *
 *   ⇒ 由此得出三条硬约束（上一版就踩了前两条）：
 *     ❌ 不能在主循环里反复轮询调用 AlUart_Hal_RecvData：
 *        第二次调用会撞上 AL_ASSERT(!AlUart_Dev_IsRxBusy(Uart))；
 *        而且 HandledCnt 只在"没搬满"的分支才更新，读出来是陈旧值。
 *     ❌ 不能改用 AlUart_Hal_RecvDataPolling：它是 `while (HandledCnt < Size)`
 *        **阻塞读满**，会把呼吸灯的主循环节拍卡住。
 *     ✅ 正解：**中断回调 + 分段接收**：
 *        回调（中断上下文）里只做"把数据搬进环形缓冲 + 置标志"；
 *        续订下一段（再次调用 AlUart_Hal_RecvData）放回主循环上下文，
 *        避免在中断上下文里调 SDK API。
 *
 *   本版改为：环形缓冲 + 单字节状态机解析帧，边界全部显式判断。
 */

#include <string.h>
#include "al_uart_hal.h"
#include "al_core.h"
#include "USART.h"

#define AL_UART_DEVID       1

static AL_UART_InitStruct UART_InitStruct = {
    .BaudRate = 115200,
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

/* ---- 解析结果 ---- */
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

/* 帧状态机：等待头 -> 收 3 字节载荷 -> 等尾 */
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

#if (USART_RX_ENABLE != 0)
/* ---------------------------------------------------------------------------
 * UART 事件回调（中断上下文）
 *
 *   只做两件事：把 SDK 收到的那一段搬进环形缓冲、置标志。
 *   **不调用任何 SDK API** —— 续订下一段要回到主循环上下文做。
 *
 *   数据来源：AlUart_Dev_RecvData 走中断路径收满一段后，
 *   RecvBuffer.HandledCnt 是本段实际字节数，RecvBuffer.BufferPtr 指向 s_rxseg。
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
        al_printf("[UART] init ok\r\n");
    } else {
        UartHandle = AL_NULL;
        al_printf("[UART] init failed, ret=%d\r\n", (int)ret);
    }
}

void USART_Poll(void)
{
#if (USART_RX_ENABLE != 0)
    if ((s_seg_ready == 0) || (UartHandle == AL_NULL)) {
        return;
    }
    s_seg_ready = 0;

    /* 续订下一段。主循环上下文，可以安全调 SDK。
     * 返回值非 AL_OK 说明上一段还没被驱动收尾（RxLock 拿不到），下一轮再来。 */
    if (AlUart_Hal_RecvData(UartHandle, s_rxseg, USART_RX_SEG_SIZE) == AL_OK) {
        frame_parse();
    }
#endif
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
