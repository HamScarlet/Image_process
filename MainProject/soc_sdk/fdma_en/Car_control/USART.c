#include <string.h>
#include "al_uart_hal.h"
#include "al_core.h"
#include "USART.h"
#include "Car_control.h"  

#define AL_UART_DEVID       0

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


static u8  s_rxseg[USART_RX_SEG_SIZE];


static u8  s_ring[USART_RX_RING_SIZE];
static u32 s_head = 0U;
static u32 s_tail = 0U;


static volatile int s_seg_ready = 0;


static COMMAND s_cmd;
static volatile int s_cmd_ready = 0;

static void rx_push(u8 b)
{
    u32 nxt = (s_head + 1U) % USART_RX_RING_SIZE;

    if (nxt == s_tail) {
        return;             
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
            case 0:                             
                if (b == FRAME_HEAD) {
                    state = 1U;
                    idx = 0U;
                }
                break;

            case 1:                             
                payload[idx++] = b;
                if (idx >= CMD_PAYLOAD_LEN) {
                    state = 2U;
                }
                break;

            case 2:                             
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
                    state = 1U;                 
                    idx = 0U;
                } else {
                    state = 0U;                 
                }
                break;

            default:
                state = 0U;
                break;
        }
    }
}
#endif 

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
#endif 

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
        return;                 
    }
    s_seg_ready = 0;

    /* 先续订下一段。SEG_SIZE=1 且 FIFO 里已有字节时，SDK 会同步搬进来并回调，
     * 也就是本轮就能把刚到的字节回显出去。 */
    if (AlUart_Hal_RecvData(UartHandle, s_rxseg, USART_RX_SEG_SIZE) != AL_OK) {
        s_seg_ready = 1;        
    }

#if (USART_LOOPBACK_ENABLE != 0)
    USART_Test();               
#else
    frame_parse();
#endif
#endif 
}

int USART_GetCmd(COMMAND *out)
{
    if ((s_cmd_ready == 0) || (out == AL_NULL)) {
        return 0;
    }
    uint8_t cmd;
    rx_pop(&cmd);
    switch(cmd)
    {
        case 0x00:
            out->direct = 0;
            break;
        case 0x01:
            out->direct = 1;
            break;
        case 0x02:
            out->direct = 2;
            break;
        case 0x03:
            out->direct = 3;
            break;
        case 0x04:
            out->direct = 4;
            break;
        case 0x10:
            out->speed += 10;
            break;
        case 0x11:
            out->speed -= 10;
            break;
    }
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
