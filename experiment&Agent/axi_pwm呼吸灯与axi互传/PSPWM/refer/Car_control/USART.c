/*
 * USART.c
 *
 *  Created on: 2026年10月13日
 *      Author: zhuji
 */

#include <string.h> // 字符串操作函数
#include <stdlib.h> // 标准库函数
#include "al_uart_hal.h" // UART 硬件抽象层接口
#include "Car_control.h"
#include "USART.h"

#define BUF_SIZE 32 // 数据缓冲区大小
#define AL_UART_TIME_OUT_MS 10000 // 超时时间（毫秒）
#define AL_UART_DEVID 1 // 使用的 UART 设备 ID

static AL_UART_InitStruct UART_InitStruct = {
    .BaudRate = 115200, // 波特率： 115200
    .Parity = AL_UART_NO_PARITY, // 无奇偶校验
    .WordLength = AL_UART_CHAR_8BITS, // 8 位数据位
    .StopBits = AL_UART_STOP_1BIT, // 1 位停止位
    .HwFlowCtl = AL_FALSE, // 禁用硬件流控
    .CharTimeoutEnable = AL_TRUE // 启用字符超时检测
};

static AL_S32 AlUart_Test_RecvAndSendNonBlock(AL_VOID); // UART 非阻塞收发测试函数


uint8_t Rx_data[BUF_SIZE] = {0};
uint8_t Tx_data[BUF_SIZE] = {0};
AL_S32 Ret;
AL_UART_HalStruct *UartHandle; // UART 控制器句柄指针


void UART_init(void)
{
    Ret = AL_OK; // 返回值变量
    Ret = AlUart_Hal_Init(&UartHandle, AL_UART_DEVID, &UART_InitStruct, AL_NULL);
    AlIntr_SetLocalInterrupt(AL_FUNC_ENABLE);

}

void UART_ReceiveData(void)
{
    Ret = AlUart_Hal_RecvData(UartHandle, Rx_data, BUF_SIZE);
}

void UART_SendData(void)
{
    Ret = AlUart_Hal_SendData(UartHandle, Tx_data, UartHandle->Dev.RecvBuffer.HandledCnt);
}


void UART_Test(void)
{
    UART_ReceiveData();
    memcpy(Tx_data,Rx_data,BUF_SIZE);
    UART_SendData();
}

void Cmd_Receive(COMMAND *cmd)
{
    UART_ReceiveData();
    uint8_t index;
    uint8_t data_valid = 0;
    uint8_t valid_data[BUF_SIZE] = {0};
    uint8_t i = 0;
    uint8_t head_cnt = 0,tail_cnt = 0;
    while(index < BUF_SIZE)
    {
        if(Rx_data[index++] == FRAME_HEAD && data_valid == 0)
        {
            head_cnt += 1;
            if(head_cnt == 4)
            {
                data_valid = 1;
            }
        }
        else if(data_valid == 1)
        {
            if(Rx_data[index] == FRAME_TAIL)
            {
                tail_cnt++;
                if(tail_cnt == 4)
                {
                    data_valid = 0;
                }
            }
            else
            {
                valid_data[i++] = Rx_data[index];
            }
            index++;
        }
    }
}