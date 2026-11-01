/*
 * Car_control.c - 整车控制层
 *
 * 原实现的问题：
 *   1. car_init 调 motor_init()，而 motor.c 里定义的是 motor_Init() —— 大小写不一致，
 *      链接期报 undefined reference
 *   2. Process_Cmd 声明 int 却没有 return，走到函数尾是未定义行为
 *   3. car_loop 全空，命令根本没有下发路径
 * 本版：初始化顺序固定为 PWM(CH0) -> motor(CH1/CH2) -> Servo -> USART，
 *       Process_Cmd 做参数校验后真正下发到电机。
 */

#include "al_core.h"
#include "al_systimer.h"
#include "ui_type.h"

#include "TIM_PWM.h"
#include "motor.h"
#include "USART.h"
#include "Servo.h"
#include "Car_control.h"

/* 当前命令快照，供自动模式状态机使用 */
static COMMAND s_cmd = { 0U, 0U, 0U, 0U };

void car_Init(void)
{
    /* 顺序：motor(CH1/CH2) -> PWM(CH0) -> Servo -> USART
     * CH0 放在最后初始化，这样即使前面某步整体清过 CTRL，CH0 也一定是使能的。 */
    motor_Init();    /* CH1/CH2 定时参数，占空比清零，不使能 */
    PWM_Init();      /* CH0 -> 板载 LED3 (J15) 呼吸灯 */
    Servo_Init();    /* 当前空实现，见 Servo.c */
    USART_Init();
}

void car_Loop(void)
{
    COMMAND c;

    if (USART_GetCmd(&c) != 0) {
        s_cmd = c;
        (void)Process_Cmd(&s_cmd);
    }
}

int Process_Cmd(const COMMAND *cmd)
{
    int speed;

    if (cmd == AL_NULL) {
        return 1;                   /* 空指针 */
    }
    if (cmd->direct > 1U) {
        return 2;                   /* 方向非法 */
    }
    if (cmd->diversion > 1U) {
        return 3;                   /* 转向非法 */
    }
    if (cmd->speed > 100U) {
        return 4;                   /* 速度非法 */
    }

    speed = (int)cmd->speed;
    if (cmd->direct != 0U) {
        speed = -speed;             /* 后退 */
    }

    /* 差速转向：占位策略，阶段 6 拿到电机规格后改成 PID / 编码器闭环 */
    if (cmd->diversion == 0U) {
        motor_SetSpeed(speed, speed / 2);    /* 左转：右轮快 */
    } else {
        motor_SetSpeed(speed / 2, speed);    /* 右转：左轮快 */
    }

    return 0;
}
