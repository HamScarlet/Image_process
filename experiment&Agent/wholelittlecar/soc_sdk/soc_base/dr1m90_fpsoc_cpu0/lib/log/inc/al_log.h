/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#ifndef __AL_LOG_H_
#define __AL_LOG_H_

#ifdef __cplusplus
extern "C" {
#endif

#include "al_hal.h"
#include <stddef.h>


#define AL_LOG_UART0 0
#define AL_LOG_UART1 1
#define AL_LOG_NONE -1

#ifdef HAVE_UARTPS_DRIVER
extern AL_UART_HalStruct *AlLog;
#endif

AL_S32 AlLog_Init();

AL_U32 AlLog_Write(const void* Data, AL_U32 Len);

AL_VOID AlLog_WriteByte(AL_S8 Data);

/* 2026-10-31 补：newlib 的 read.c 无条件调用 AlLog_Recv（stdin 读）。
 * 本工程的 al_log 为极简 UART 直连版，原先缺此函数，导致链接期
 * "undefined reference to AlLog_Recv"。此处按其原有架构补齐，不改动其他接口。 */
AL_U32 AlLog_Recv(AL_U8 *Data, size_t Len);

#ifdef __cplusplus
}
#endif

#endif
