/* Interrupt-driven UART receive and command frame parsing. */
#include <stdint.h>
#include "al_uart_hal.h"
#include "Car_control.h"
#include "USART.h"
#include <stdlib.h>
#include <string.h>

#define BUF_SIZE 32U
#define AL_UART_DEVID 0U

static AL_UART_InitStruct UART_InitStruct = {
    .BaudRate = 115200U,
    .Parity = AL_UART_NO_PARITY,
    .WordLength = AL_UART_CHAR_8BITS,
    .StopBits = AL_UART_STOP_1BIT,
    .HwFlowCtl = AL_FALSE,
    .CharTimeoutEnable = AL_TRUE
};

static uint8_t Rx_data[BUF_SIZE];
static AL_UART_HalStruct *UartHandle;
static volatile uint32_t RxReceivedLength;
static volatile uint8_t RxDataReady;
static AL_S32 Ret;

/* The callback runs in interrupt context; parsing is deferred to Cmd_Receive. */
static AL_VOID UART_EventCallback(AL_UART_EventStruct event, AL_VOID *callback_ref)
{
    (void)callback_ref;

    if ((event.Events == AL_UART_EVENT_RECEIVE_DONE) ||
        (event.Events == AL_UART_EVENT_CHAR_TIMEOUT)) {
        /* RECEIVE_DONE means the requested buffer is full. Use that known
         * length directly; some HAL versions report a stale EventData when
         * all requested bytes were already in the FIFO at request time. */
        RxReceivedLength = (event.Events == AL_UART_EVENT_RECEIVE_DONE) ?
                           BUF_SIZE : event.EventData;
        RxDataReady = 1U;
    }
}

void UART_init(void)
{
    RxReceivedLength = 0U;
    RxDataReady = 0U;
    Ret = AlUart_Hal_Init(&UartHandle, AL_UART_DEVID, &UART_InitStruct,
                          UART_EventCallback);
    if (Ret != AL_OK) {
        UartHandle = AL_NULL;
        return;
    }

    AlIntr_SetLocalInterrupt(AL_FUNC_ENABLE);
    UART_ReceiveData();
}

/* Arms one interrupt-driven receive. It is safe to call from the main loop. */
void UART_ReceiveData(void)
{
    if ((UartHandle == AL_NULL) || (RxDataReady != 0U) ||
        AlUart_Hal_IsRxBusy(UartHandle)) {
        return;
    }

    Ret = AlUart_Hal_RecvData(UartHandle, Rx_data, BUF_SIZE);
}

int32_t UART_SendData(const uint8_t *data, uint32_t length)
{
    if ((UartHandle == AL_NULL) || (data == AL_NULL) || (length == 0U)) {
        return (int32_t)AL_UART_ERR_ILLEGAL_PARAM;
    }
    uint8_t tx_data[100] = {0};
    tx_data[0] = 0xA5;

    memcpy(tx_data + 1,data, length);
    tx_data[length + 1] = 0x5A;
    /* HAL send is asynchronous; the caller retains data until SEND_DONE. */
    return (int32_t)AlUart_Hal_SendData(UartHandle, (AL_U8 *)tx_data, length + 2);
}

void Cmd_Receive(COMMAND *cmd)
{
    uint8_t index;
    uint8_t data_valid = 0;
    uint8_t valid_data[BUF_SIZE] = {0};
    uint8_t i = 0;
    uint8_t head_cnt = 0,tail_cnt = 0;
    if(!RxDataReady) return;
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
    UART_ReceiveData();
}

void UART_test(void)
{
    UART_ReceiveData();
    if(RxDataReady)
    {
        UART_SendData(Rx_data,RxReceivedLength);
        while(AlUart_Hal_IsRxBusy(UartHandle));
        RxDataReady = 0;
        
        
    }
}
