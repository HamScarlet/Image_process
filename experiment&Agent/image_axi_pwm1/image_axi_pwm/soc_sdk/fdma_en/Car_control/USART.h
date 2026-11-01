/*
 * USART.h - 串口（PS 硬核 UART0，走 EMIO 到 J12 的 U8/U9，接 JDY-31 蓝牙）
 *
 * 【2026-11-01 本期改动】
 *   1. 归属改为 **UART0**（AL_UART_DEVID 0）。原来用 UART1，而 UART1 是 printf 的
 *      日志口（MIO48/49 走到那个二合一 Type-C 的 PS_UART），两者会互相干扰。
 *      现在：UART0 = 蓝牙回环，UART1 = 日志，彻底分开。
 *   2. 波特率改 **9600**，与 JDY-31 出厂默认对齐（D1 决策：先 9600，通了再 AT 改 115200）。
 *   3. 打开接收（USART_RX_ENABLE 1）并启用**纯字节回环**（USART_LOOPBACK_ENABLE 1）。
 *      本期目标是"通路通不通"，不做协议。
 *
 * 【帧格式（阶段 5 再用，本期不启用）】
 *   0x55 | direct | diversion | speed | 0x56
 *   direct  0=前进 1=后退 ; diversion 0=左 1=右 ; speed 0..100
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
 *      续订下一段（再次调用 AlUart_Hal_RecvData）放在主循环上下文里做。
 *
 *   ⚠️ 还有一条最容易踩的：**DONE 事件只在"搬满一段"时才触发**。
 *      所以回环场景下 USART_RX_SEG_SIZE 必须是 1，否则发不满 16 字节就永远没反应
 *      （会表现为"发几个字节毫无动静"）。逐字节中断在 9600 下约 1 kHz，开销可忽略。
 */

#ifndef USART_H_
#define USART_H_

#include "ui_type.h"
#include "Car_control.h"

#define FRAME_HEAD              0x55U
#define FRAME_TAIL              0x56U
#define CMD_PAYLOAD_LEN         3U      /* direct + diversion + speed */

/* 1 = 启用中断回调接收。本期必须为 1，否则回环收不到任何字节。 */
#define USART_RX_ENABLE         1

/* 1 = 纯字节回环（收到什么发回什么，不解析帧）；0 = 走 FRAME_HEAD/TAIL 帧解析。
 * 本期按 D4 决策取 1：先把通路验通，协议留到通了之后再加。 */
#define USART_LOOPBACK_ENABLE   1

/* 分段接收：每次启动接收的字节数。
 * ⚠️ 回环时必须为 1（原因见文件头）。将来做帧解析可以放宽到 8~16 降低中断频率。 */
#if (USART_LOOPBACK_ENABLE != 0)
#define USART_RX_SEG_SIZE       1U
#else
#define USART_RX_SEG_SIZE       16U
#endif

/* 环形缓冲大小（必须是 2 的幂，索引用取模实现） */
#define USART_RX_RING_SIZE      64U

void USART_Init(void);

/* 主循环里调用：续订下一段接收，并按 USART_LOOPBACK_ENABLE 决定回环还是解析帧（非阻塞）。
 * ⚠️ 必须每轮都调，否则接收段永远续订不上，表现为"只收到最开始那一字节"。 */
void USART_Poll(void);

/* 取最近一条有效命令：有新命令返回 1，否则 0（回环模式下恒返回 0） */
int  USART_GetCmd(COMMAND *out);

/* 发送原始字节 */
void USART_Send(const u8 *buf, u32 len);

/* 回环自测（把环形缓冲里的字节原样发回）；仅在 USART_RX_ENABLE=1 时有效 */
void USART_Test(void);

/* 兼容旧名 */
#define UART_init           USART_Init
#define UART_ReceiveData()  USART_Poll()

#endif /* USART_H_ */
