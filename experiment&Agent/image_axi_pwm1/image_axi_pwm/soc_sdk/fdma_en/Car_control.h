/*
 * Car_control.h - 整车控制层：命令结构与下发接口
 *
 * 原实现的问题：speed 字段缺分号 -> 整个工程编译失败。
 * 本版补齐分号，并把三个字段的取值范围写进注释，供上位机协议对齐。
 */

#ifndef CAR_CONTROL_H_
#define CAR_CONTROL_H_

#include <stdint.h>

typedef struct {
    uint8_t direct;     /* 0: 前进   1: 后退 */
    uint8_t diversion;  /* 0: 左     1: 右   */
    uint8_t speed;      /* 0..100   占空比百分比 */
    uint8_t reserved;   /* 对齐填充，保证结构体 4 字节 */
} COMMAND;

/* 初始化：电机 PWM、舵机、串口 */
void car_Init(void);

/* 周期调用：把当前 COMMAND 下发到执行机构（预留自动模式状态机） */
void car_Loop(void);

/* 下发一条命令；返回 0 表示成功，非 0 为参数非法 */
int Process_Cmd(const COMMAND *cmd);

#endif /* CAR_CONTROL_H_ */
