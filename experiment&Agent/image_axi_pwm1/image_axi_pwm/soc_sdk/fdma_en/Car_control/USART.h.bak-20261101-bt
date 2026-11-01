/*
 * USART.h - 串口（PS MIO48/49，115200 8N1）
 *
 * 帧格式（与上位机约定，可改）：
 *   0x55 | direct | diversion | speed | 0x56
 *   direct  0=前进 1=后退
 *   diversion 0=左 1=右
 *   speed   0..100
 *
 * 【接收模型 —— 必须按 SDK 的真实语义写，别想当然】
 *   读 al_uart_dev.c 的 AlUart_Dev_RecvData() 实测确认：
 *     AlUart_Hal_RecvData(Handle, Buf, Size) 是"**启动**接收"，不是"取走已有数据"：
 *       1) 先把 RX FIFO 里现成的字节搬进 Buf；
 *       2) 若没搬满 Size，则记下 RecvBuffer.{BufferPtr,HandledCnt} 并**使能 RX 线中断**，
 *          由中断继续往 Buf 搬，**搬满 Size 字节**才触发 AL_UART_EVENT_RECEIVE_DONE；
 *       3) 若一次就搬满了，直接触发 RECEIVE_DONE。
 *   由此有两条硬约束：
 *     ❌ 不能在主循环里反复轮询调用它 —— 第二次调用会撞上
 *        AL_ASSERT(!AlUart_Dev_IsRxBusy(Uart))，而且 HandledCnt 只在"没搬满"
 *        的分支才更新，读出来是上一次的陈旧值。
 *     ❌ 不能改用 AlUart_Hal_RecvDataPolling —— 它是 `while (HandledCnt < Size)`
 *        **阻塞读满**，会卡住呼吸灯节拍。
 *   ✅ 正解：**中断回调 + 分段接收**。回调里只把数据搬进环形缓冲并置标志，
 *      续订下一段（再次调用 AlUart_Hal_RecvData）放在主循环上下文里做，
 *      避免在中断上下文里调 SDK API。
 *
 * 【本期范围】
 *   USART_RX_ENABLE 默认 0 —— 本期只验证 AXI PWM 呼吸灯，不引入接收链路的变量。
 *   阶段 5（蓝牙 / 串口屏）接上时置 1 即可，代码路径已经就绪。
 *   发送方向随时可用（printf 本身也走 UART1，见 al_log.c 的 AlLog_Write）。
 */

#ifndef USART_H_
#define USART_H_

#include "ui_type.h"
#include "Car_control.h"

#define FRAME_HEAD              0x55U
#define FRAME_TAIL              0x56U
#define CMD_PAYLOAD_LEN         3U      /* direct + diversion + speed */

/* 1 = 启用中断回调接收；0 = 只保留发送（本期默认） */
#define USART_RX_ENABLE         0

/* 分段接收：每次启动接收的字节数。太小则中断频率高，太大则首帧响应慢。
 * 16 字节在 115200 下约 1.4 ms 一段，够用。 */
#define USART_RX_SEG_SIZE       16U

/* 环形缓冲大小（必须是 2 的幂，索引用取模实现） */
#define USART_RX_RING_SIZE      64U

void USART_Init(void);

/* 主循环里调用：若有段数据待处理，则续订下一段接收并解析帧（非阻塞） */
void USART_Poll(void);

/* 取最近一条有效命令：有新命令返回 1，否则 0 */
int  USART_GetCmd(COMMAND *out);

/* 发送原始字节 */
void USART_Send(const u8 *buf, u32 len);

/* 回环自测（收到什么发回什么），调试用；仅在 USART_RX_ENABLE=1 时有效 */
void USART_Test(void);

/* 兼容旧名 */
#define UART_init           USART_Init
#define UART_ReceiveData()  USART_Poll()

#endif /* USART_H_ */
