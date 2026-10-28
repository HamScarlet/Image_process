/*
 * USART.h
 *
 *  Created on: 2026年10月13日
 *      Author: zhuji
 */

#ifndef USART_H_
#define USART_H_

#define FRAME_HEAD      0x55
#define FRAME_TAIL      0x56

void UART_init(void);
void UART_ReceiveData(void);
void UART_SendData(void);
void UART_Test(void);

#endif /* USART_H_ */
