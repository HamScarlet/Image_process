/*
 * AXI_GPIO_test.h - AXI GPIO 读写自检
 *
 * 寄存器地址统一在 Definitions.h 里定义，本头文件不再重复。
 */

#ifndef AXI_GPIO_TEST_H_
#define AXI_GPIO_TEST_H_

#include "Definitions.h"

void AXI_GPIO_Init(void);
void AXI_GPIO_Test(void);

#endif /* AXI_GPIO_TEST_H_ */
