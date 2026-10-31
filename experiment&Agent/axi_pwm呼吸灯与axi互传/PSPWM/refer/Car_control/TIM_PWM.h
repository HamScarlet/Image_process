/*
 * TIM_PWM.h
 *
 *  Created on: 2026年10月13日
 *      Author: zhuji
 */

#ifndef TIM_PWM_H_
#define TIM_PWM_H_



#define AXI_PWM_REG_BASE		 (void *)(uintptr_t) 0x80200000
#define REG_CTRL                 (void *)(uintptr_t) AXI_PWM_REG_BASE + 0x00
#define REG_DIR                  (void *)(uintptr_t) AXI_PWM_REG_BASE + 0x04
#define REG_STATUS               (void *)(uintptr_t) AXI_PWM_REG_BASE + 0x08
#define REG_VERSION              (void *)(uintptr_t) AXI_PWM_REG_BASE + 0x0C
#define REG_PWM0_PSC             (void *)(uintptr_t) AXI_PWM_REG_BASE + 0x10
#define REG_PWM0_ARR             (void *)(uintptr_t) AXI_PWM_REG_BASE + 0x14
#define REG_PWM0_CCR             (void *)(uintptr_t) AXI_PWM_REG_BASE + 0x18
#define REG_PWM1_PSC             (void *)(uintptr_t) AXI_PWM_REG_BASE + 0x20
#define REG_PWM1_ARR             (void *)(uintptr_t) AXI_PWM_REG_BASE + 0x24
#define REG_PWM1_CCR             (void *)(uintptr_t) AXI_PWM_REG_BASE + 0x28
#define REG_PWM2_PSC             (void *)(uintptr_t) AXI_PWM_REG_BASE + 0x30
#define REG_PWM2_ARR             (void *)(uintptr_t) AXI_PWM_REG_BASE + 0x34
#define REG_PWM2_CCR             (void *)(uintptr_t) AXI_PWM_REG_BASE + 0x38
#define REG_UPDATE               (void *)(uintptr_t) AXI_PWM_REG_BASE + 0x40


typedef enum{
    PWM0 = 0,
    PWM1,
    PWM2,
    PWM3
}PWM_ID;

void TIM_PWM_Init(void);
void TIM_PWM_test(void);
int PWM_Output(PWM_ID id, int cmd);
int TIM_SetCompare(PWM_ID id, float duty);


#endif /* TIM_PWM_H_ */
