/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#include "al_log.h"

#if !defined(HAVE_UARTPS_DRIVER) && defined(LOG_DEV) && (LOG_DEV != AL_LOG_NONE)
    #error "ERROR: LOG_DEV is defined but HAVE_UARTPS_DRIVER is not defined!"
#endif


#if ((LOG_DEV == AL_LOG_UART0) || (LOG_DEV == AL_LOG_UART1))
AL_UART_HalStruct *AlLog;
#endif

AL_S32 AlLog_Init()
{
#if (LOG_DEV == AL_LOG_NONE)
    return AL_OK;
#elif ((LOG_DEV == AL_LOG_UART0) || (LOG_DEV == AL_LOG_UART1))
    AL_UART_InitStruct UART_InitStruct = {
        .BaudRate           = 115200,
        .Parity             = AL_UART_NO_PARITY,
        .WordLength         = AL_UART_CHAR_8BITS,
        .StopBits           = AL_UART_STOP_1BIT,
        .HwFlowCtl          = AL_FALSE,
        .CharTimeoutEnable  = AL_TRUE
    };

    #if (LOG_DEV == AL_LOG_UART0)
        #ifdef UART0_BAUDRATE
            UART_InitStruct.BaudRate = UART0_BAUDRATE;
        #endif
    #endif
    #if (LOG_DEV == AL_LOG_UART1)
        #ifdef UART1_BAUDRATE
            UART_InitStruct.BaudRate = UART1_BAUDRATE;
        #endif
    #endif

    return AlUart_Hal_Init(&AlLog, LOG_DEV, &UART_InitStruct, AL_NULL);

#endif

    return AL_OK;
}

AL_U32 AlLog_Write(const void* Data, AL_U32 Len)
{
#if (LOG_DEV == AL_LOG_UART0) || (LOG_DEV == AL_LOG_UART1)
    AL_U32 i;
    for (i = 0; i < Len; i++) {
        AlUart_Dev_SendByte(&(AlLog->Dev), ((const AL_S8*)Data)[i]);
    }

    return Len;

#else
    (AL_VOID)Data;
    (AL_VOID)Len;
    return Len;
#endif
}

AL_VOID AlLog_WriteByte(AL_S8 Data)
{
#if (LOG_DEV == AL_LOG_UART0) || (LOG_DEV == AL_LOG_UART1)
    AlUart_Dev_SendByte(&(AlLog->Dev), Data);
#else
    (AL_VOID)Data;
#endif
}

/* 2026-10-31 补：对应 al_log.h 的新增声明。
 * 新版 newlib 的 read.c 中 _read() 无条件调用 AlLog_Recv()，而本工程的
 * al_log 是"极简 UART 直连版"（无 AlLog_Ops 算子表），原先没有这个函数，
 * 导致链接期 undefined reference to `AlLog_Recv`。
 * 这里沿用本文件其余三个函数的风格，直接操作 AlLog 句柄，零新增依赖。 */
AL_U32 AlLog_Recv(AL_U8 *Data, size_t Len)
{
#if (LOG_DEV == AL_LOG_UART0) || (LOG_DEV == AL_LOG_UART1)
    AlUart_Dev_RecvDataPolling(&(AlLog->Dev), Data, (AL_U32)Len);
#else
    (AL_VOID)Data;
    (AL_VOID)Len;
#endif

    return (AL_U32)Len;
}
