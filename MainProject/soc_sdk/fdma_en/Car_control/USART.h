#ifndef USART_H_
#define USART_H_

#include "ui_type.h"
#include "Car_control.h"

#define FRAME_HEAD              0x55U
#define FRAME_TAIL              0x56U
#define CMD_PAYLOAD_LEN         3U      


#define USART_RX_ENABLE         1


#define USART_LOOPBACK_ENABLE   1

#if (USART_LOOPBACK_ENABLE != 0)
#define USART_RX_SEG_SIZE       1U
#else
#define USART_RX_SEG_SIZE       16U
#endif


#define USART_RX_RING_SIZE      64U

void USART_Init(void);

void USART_Poll(void);


int  USART_GetCmd(COMMAND *out);


void USART_Send(const u8 *buf, u32 len);


void USART_Test(void);


#define UART_init           USART_Init
#define UART_ReceiveData()  USART_Poll()

#endif 
