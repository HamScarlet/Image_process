/*
 * USART.h
 *
 *  Created on: 2026年10月13日
 *      Author: zhuji
 */

#ifndef USART_H_
#define USART_H_

#include <stdint.h>
#include "../Car_control.h"

#define FRAME_HEAD      0x55
#define FRAME_TAIL      0x56

void UART_init(void);
void UART_ReceiveData(void);
/* The caller must keep data valid until the asynchronous send completes. */
int32_t UART_SendData(const uint8_t *data, uint32_t length);
void Cmd_Receive(COMMAND *cmd);
void UART_test(void);

#endif /* USART_H_ */
