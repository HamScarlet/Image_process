/*
 * TIM_PWM.c
 *
 *  Created on: 2026年10月13日
 *      Author: zhuji
 */
#include "TIM_PWM.h"
#include "al_core.h"
#include "al_hal.h"
#include "ui_io.h"

void TIM_PWM_test(void)
{
    for(int i = 0;i <= 100;i++)
    {
        TIM_SetCompare(PWM0,(float)i/100);
        TIM_SetCompare(PWM1,(float)i/100);
        TIM_SetCompare(PWM2,(float)i/100);
        PWM_Output(PWM0,1);
        PWM_Output(PWM1,1);
        PWM_Output(PWM2,1);
        AlSys_MDelay(10);
    }

    for(int i = 100;i;i--)
    {
        TIM_SetCompare(PWM0,(float)i/100);
        TIM_SetCompare(PWM1,(float)i/100);
        TIM_SetCompare(PWM2,(float)i/100);
        PWM_Output(PWM0,1);
        PWM_Output(PWM1,1);
        PWM_Output(PWM2,1);
        AlSys_MDelay(10);
    }
}

void TIM_PWM_Init(void)
{
    //int v = UI_In32(REG_VERSION);
    //al_printf(v);
    UI_Out32(AXI_PWM_REG_BASE,0);
    UI_Out32(REG_CTRL,0);
    UI_Out32(REG_DIR,0);
    UI_Out32(REG_PWM0_ARR,9999);
    UI_Out32(REG_PWM0_CCR,4999);
    UI_Out32(REG_PWM0_PSC,0);
    UI_Out32(REG_PWM1_ARR,9999);
    UI_Out32(REG_PWM1_CCR,4999);
    UI_Out32(REG_PWM1_PSC,0);
    UI_Out32(REG_PWM2_ARR,9999);
    UI_Out32(REG_PWM2_CCR,2999);
    UI_Out32(REG_PWM2_PSC,0);
    UI_Out32(REG_UPDATE,0b111);
}

int TIM_SetCompare(PWM_ID id, float duty)
{
    int new_ccr;
    int arr = 9999;
    new_ccr = (arr + 1) * duty - 1;
    switch (id)
    {
    case PWM0:
        /* code */
        UI_Out32(REG_PWM0_CCR,new_ccr);
        UI_Out32(REG_UPDATE,1 << (int)id);
        break;

    case PWM1:
        /* code */
        UI_Out32(REG_PWM1_CCR,new_ccr);
        UI_Out32(REG_UPDATE,1 << (int)id);
        break;

    case PWM2:
        /* code */
        UI_Out32(REG_PWM2_CCR,new_ccr);
        UI_Out32(REG_UPDATE,1 << (int)id);
        break;

    default:
        al_printf("PWM set error");
        return 0;
        break;
    }
    return 1;
}

int PWM_Output(PWM_ID id, int cmd)
{
    static int pwm_status;

    pwm_status |= cmd << id;
    
    UI_Out32(REG_CTRL,pwm_status);
    return 1;
}


